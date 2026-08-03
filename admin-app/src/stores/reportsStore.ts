import { ref } from 'vue';
import { defineStore } from 'pinia';
import { reportsApi, usersApi, edgeApi } from '@/api/api';
import type { ReportStatus, ReportWithContext } from '@/types/reportTypes';

export const useReportsStore = defineStore('reports', () => {
  const reports = ref<ReportWithContext[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const hasLoaded = ref(false);

  async function fetchReports(force = false): Promise<void> {
    if (!force && hasLoaded.value) return;

    loading.value = true;
    error.value = null;
    try {
      const { data: rows, error: fetchError } = await reportsApi.getAll();
      if (fetchError) throw fetchError;

      const userIds = [...new Set((rows ?? []).flatMap((r) => [r.reporter_id, r.reported_id]))];
      const messageIds = [...new Set((rows ?? []).map((r) => r.message_id).filter((id): id is string => !!id))];

      const [{ data: profiles }, { data: messages }] = await Promise.all([
        userIds.length ? usersApi.getProfilesByIds(userIds) : Promise.resolve({ data: [] }),
        messageIds.length ? usersApi.getMessagesByIds(messageIds) : Promise.resolve({ data: [] })
      ]);

      const profileMap = new Map((profiles ?? []).map((p) => [p.id, p.username]));
      const messageMap = new Map((messages ?? []).map((m) => [m.id, m.content]));

      reports.value = (rows ?? []).map((r) => ({
        ...r,
        reporterUsername: profileMap.get(r.reporter_id) ?? r.reporter_id.slice(0, 8),
        reportedUsername: profileMap.get(r.reported_id) ?? r.reported_id.slice(0, 8),
        messageContent: r.message_id ? (messageMap.get(r.message_id) ?? null) : null
      }));
      hasLoaded.value = true;
    } catch (e: unknown) {
      console.error('fetchReports hatası:', e);
      error.value = 'Şikayetler yüklenemedi.';
    } finally {
      loading.value = false;
    }
  }

  async function updateStatus(id: string, status: ReportStatus): Promise<void> {
    try {
      const { error: updateError } = await reportsApi.updateStatus(id, status);
      if (updateError) throw updateError;
      const report = reports.value.find((r) => r.id === id);
      if (report) report.status = status;
    } catch (e: unknown) {
      console.error('updateStatus hatası:', e);
      error.value = 'Durum güncellenemedi.';
    }
  }

  async function banReportedUser(userId: string): Promise<void> {
    try {
      await edgeApi.ban(userId);
    } catch (e: unknown) {
      console.error('banReportedUser hatası:', e);
      error.value = 'Kullanıcı askıya alınamadı.';
    }
  }

  return { reports, loading, error, hasLoaded, fetchReports, updateStatus, banReportedUser };
});
