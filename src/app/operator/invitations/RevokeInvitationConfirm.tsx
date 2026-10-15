import { Disclosure } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import { revokeInvitationAction } from './actions';
export function RevokeInvitationConfirm({ id, company }: { id: string; company: string }) {
  return <Disclosure className="operator-invite-cancel" summary="إلغاء الدعوة"><p>يلغي ذلك قبول هذا الرابط. لن تُنشأ الشركة من هذه الدعوة.</p>
    <OfflineForm action={revokeInvitationAction}><input type="hidden" name="invitationId" value={id} /><OfflineSubmitButton variant="danger" label={`تأكيد إلغاء دعوة ${company}`} /></OfflineForm>
  </Disclosure>;
}
