import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    files: ["src/components/ui/**/*.tsx", "src/components/patterns/**/*.tsx", "src/components/shell/**/*.tsx"],
    rules: {
      "no-restricted-syntax": ["error", {
        selector: "JSXAttribute[name.name='className'] > Literal[value=/\\b(primary-button|secondary-button|danger-button|work-card|record-card|entity-status)\\b/]",
        message: "Use the Concept C UI component in new UI, patterns, and shell files.",
      }],
    },
  },
  {
    // Standalone evidence CLIs intentionally use the CommonJS .cjs convention.
    files: ["docs/07-execution/evidence/**/*.cjs"],
    rules: { "@typescript-eslint/no-require-imports": "off" },
  },
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
]);
