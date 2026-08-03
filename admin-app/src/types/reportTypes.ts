export type ReportStatus = 'pending' | 'reviewed' | 'resolved';

export interface Report {
  id: string;
  reporter_id: string;
  reported_id: string;
  message_id: string | null;
  reason: string;
  description: string | null;
  status: ReportStatus;
  created_at: string;
}

// reporter/reported kullanıcı adları ve mesaj içeriği ayrı sorgularla çekilip birleştiriliyor
export interface ReportWithContext extends Report {
  reporterUsername: string;
  reportedUsername: string;
  messageContent: string | null;
}
