import { createSupabaseServerClient } from '@/lib/supabase/server';
import { projectEmployeePreview, type EmployeePreviewResult } from '../../employee-preview-data';

export const dynamic = 'force-dynamic';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function response(result: EmployeePreviewResult) {
  return Response.json(result, { headers: { 'Cache-Control': 'private, no-store', Vary: 'Cookie' } });
}

export async function GET(_request: Request, { params }: {
  params: Promise<{ tenantId: string; employeeId: string }>;
}) {
  try {
    const { tenantId, employeeId } = await params;
    if (!UUID.test(tenantId) || !UUID.test(employeeId)) return response({ status: 'unavailable' });
    const supabase = await createSupabaseServerClient();
    if (!supabase) return response({ status: 'unavailable' });
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError && authError.name !== 'AuthSessionMissingError') return response({ status: 'unavailable' });
    if (!user) return response({ status: 'signed-out' });
    const result = await supabase.rpc('people_employee_snapshot', {
      p_tenant_id: tenantId, p_employee_id: employeeId,
    });
    const employee = result.error ? null : projectEmployeePreview(result.data, employeeId);
    return response(employee ? { status: 'ready', employee } : { status: 'unavailable' });
  } catch {
    return response({ status: 'unavailable' });
  }
}
