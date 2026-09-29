import pg from "pg";

const { Client } = pg;
const [mode, targetUserId, ...options] = process.argv.slice(2);
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const databaseUrl = process.env.PLATFORM_OPERATOR_MAINTENANCE_DATABASE_URL;

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

if (!databaseUrl) {
  fail("Set PLATFORM_OPERATOR_MAINTENANCE_DATABASE_URL through the maintenance runner's secret environment.");
} else if (!uuidPattern.test(targetUserId ?? "")) {
  fail("Provide the UUID of an existing Auth user.");
} else if (mode !== "bootstrap" && mode !== "recover") {
  fail("Select either bootstrap or recover.");
} else {
  let reason = null;
  let emergency = false;
  let invalidOption = false;
  for (let index = 0; index < options.length; index += 1) {
    if (options[index] === "--reason" && mode === "recover" && reason === null) {
      const value = options[index + 1];
      if (!value || value.startsWith("--")) {
        invalidOption = true;
        break;
      }
      reason = value;
      index += 1;
    } else if (options[index] === "--emergency" && mode === "recover" && !emergency) {
      emergency = true;
    } else {
      invalidOption = true;
      break;
    }
  }

  if (mode === "bootstrap" && options.length > 0) {
    fail("Bootstrap accepts only the target Auth user UUID.");
  } else if (mode === "recover" && (!reason?.trim() || invalidOption)) {
    fail("Recovery requires --reason with a non-empty explanation; add --emergency only for a declared emergency.");
  } else if (mode === "recover" && options.filter((option) => option === "--reason").length !== 1) {
    fail("Recovery requires exactly one --reason.");
  } else {
    const client = new Client({
      connectionString: databaseUrl,
      application_name: "platform-operator-maintenance",
    });

    try {
      await client.connect();
      const { rows } = await client.query("SELECT current_user AS role");
      if (rows[0]?.role !== "postgres") {
        throw Object.assign(new Error("Maintenance database role required"), { code: "42501" });
      }

      if (mode === "bootstrap") {
        await client.query("SELECT platform_private.bootstrap_operator_manager($1::uuid)", [targetUserId]);
      } else {
        await client.query(
          "SELECT platform_private.recover_operator_manager($1::uuid, $2::text, $3::boolean)",
          [targetUserId, reason, emergency],
        );
      }

      console.log(`Platform Operator manager ${mode} completed for target ${targetUserId}.`);
      if (mode === "bootstrap") {
        console.log("Remove the maintenance database secret from the runner and rotate or disable its bootstrap access now.");
      }
    } catch (error) {
      const code = error && typeof error === "object" && "code" in error ? error.code : "unknown";
      const messages = {
        "22023": "The target Auth user or recovery reason is invalid.",
        "23514": "A protected Platform Operator invariant rejected the change.",
        "42501": "This command requires the dedicated postgres maintenance database role.",
        "55000": "Bootstrap is already complete, or recovery requires an explicitly declared emergency.",
        "28P01": "Database authentication failed; check the maintenance secret injection.",
      };
      fail(messages[code] ?? `Maintenance command failed (SQLSTATE ${code}); connection details were suppressed.`);
    } finally {
      await client.end().catch(() => {});
    }
  }
}
