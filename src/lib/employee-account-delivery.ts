type AuthDeliveryError = { code?: string; name?: string; message?: string };

type EmployeeAccountAuthClient = {
  auth: {
    admin: {
      inviteUserByEmail(email: string, options: { redirectTo: string }): Promise<{ error: AuthDeliveryError | null }>;
    };
    signInWithOtp(input: {
      email: string;
      options: { shouldCreateUser: false; emailRedirectTo: string };
    }): Promise<{ error: AuthDeliveryError | null }>;
  };
};

export async function sendEmployeeAccountActivation(
  admin: EmployeeAccountAuthClient,
  email: string,
  redirectTo: string,
): Promise<{ sent: boolean; errorCode: string | null }> {
  const { error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo });
  if (!inviteError) return { sent: true, errorCode: null };
  if (!isExistingAuthUserError(inviteError)) {
    return { sent: false, errorCode: safeCode(inviteError.code ?? inviteError.name) };
  }

  const { error: otpError } = await admin.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: false, emailRedirectTo: redirectTo },
  });
  return {
    sent: !otpError,
    errorCode: otpError ? safeCode(otpError.code ?? otpError.name ?? inviteError.code) : null,
  };
}

function isExistingAuthUserError(error: AuthDeliveryError) {
  return ['email_exists', 'user_already_exists', 'already_registered'].includes(error.code ?? '')
    || /already\s+(registered|exists)/i.test(error.message ?? '');
}

function safeCode(value: unknown) {
  return typeof value === 'string' && /^[a-z0-9_-]{1,80}$/i.test(value) ? value : 'activation_delivery_failed';
}
