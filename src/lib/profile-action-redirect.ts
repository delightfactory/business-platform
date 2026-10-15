import { redirect } from 'next/navigation';
import { profileReturnUrl } from './profile-return';

export function profileActionRedirect(tenantId: string, employeeId: string, returnTo: unknown) {
  return (destination: string): never => redirect(profileReturnUrl(tenantId, employeeId, destination, returnTo));
}
