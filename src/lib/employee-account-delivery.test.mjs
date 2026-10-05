import assert from 'node:assert/strict';
import test from 'node:test';
import { sendEmployeeAccountActivation } from './employee-account-delivery.ts';

const targetEmail = 'employee@example.test';
const redirectTo = 'https://example.test/auth/employee-account-activation/callback?intent_id=00000000-0000-4000-8000-000000000001';

test('existing Auth identity receives a non-creating OTP at the same activation callback', async () => {
  const calls = [];
  const admin = {
    auth: {
      admin: { inviteUserByEmail: async (email, options) => {
        calls.push(['invite', email, options]);
        return { error: { code: 'email_exists' } };
      } },
      signInWithOtp: async (input) => {
        calls.push(['otp', input]);
        return { error: null };
      },
    },
  };

  assert.deepEqual(await sendEmployeeAccountActivation(admin, targetEmail, redirectTo), { sent: true, errorCode: null });
  assert.deepEqual(calls, [
    ['invite', targetEmail, { redirectTo }],
    ['otp', { email: targetEmail, options: { shouldCreateUser: false, emailRedirectTo: redirectTo } }],
  ]);
});

test('unrelated invite errors do not send an OTP or request Auth user creation', async () => {
  let otpCalls = 0;
  const admin = {
    auth: {
      admin: { inviteUserByEmail: async () => ({ error: { code: 'invalid_redirect_url' } }) },
      signInWithOtp: async () => { otpCalls += 1; return { error: null }; },
    },
  };

  assert.deepEqual(await sendEmployeeAccountActivation(admin, targetEmail, redirectTo), {
    sent: false,
    errorCode: 'invalid_redirect_url',
  });
  assert.equal(otpCalls, 0);
});

