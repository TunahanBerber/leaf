<script setup lang="ts">
import type { ReportStatus, ReportWithContext } from '@/types/reportTypes';

defineProps<{
  report: ReportWithContext;
}>();

const emit = defineEmits<{
  (e: 'status-change', payload: { id: string; status: ReportStatus }): void;
  (e: 'ban', payload: { userId: string; username: string }): void;
  (e: 'signout', payload: { userId: string; username: string }): void;
}>();

function handleStatusChange(event: Event, id: string): void {
  const status = (event.target as HTMLSelectElement).value as ReportStatus;
  emit('status-change', { id, status });
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('tr-TR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit'
  });
}
</script>

<template>
  <div class="card report-card">
    <div class="top">
      <div>
        <span class="tag tag-danger">{{ report.reason }}</span>
        <div class="who">
          <b>{{ report.reporterUsername }}</b> → <b>{{ report.reportedUsername }}</b>'i şikayet etti
        </div>
      </div>
      <div class="when">{{ formatDate(report.created_at) }}</div>
    </div>

    <p v-if="report.description" class="desc">{{ report.description }}</p>

    <div v-if="report.messageContent" class="msg-preview">
      <div class="lbl">İlgili mesaj</div>
      {{ report.messageContent }}
    </div>

    <div class="actions">
      <select :value="report.status" @change="handleStatusChange($event, report.id)">
        <option value="pending">Bekliyor</option>
        <option value="reviewed">İncelendi</option>
        <option value="resolved">Çözüldü</option>
      </select>
      <button
        class="btn-danger"
        @click="$emit('ban', { userId: report.reported_id, username: report.reportedUsername })"
      >
        Hesabı Askıya Al
      </button>
      <button
        class="btn-warn"
        @click="$emit('signout', { userId: report.reported_id, username: report.reportedUsername })"
      >
        Oturumları Sonlandır
      </button>
    </div>
  </div>
</template>

<style scoped>
.report-card {
  margin-bottom: 12px;
}

.top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: flex-start;
}

.who {
  font-size: 14px;
  margin-top: 6px;
}

.when {
  font-size: 12px;
  color: var(--text-3);
  white-space: nowrap;
}

.desc {
  font-size: 13px;
  color: var(--text-2);
  margin: 10px 0 0;
}

.msg-preview {
  margin-top: 10px;
  padding: 10px 12px;
  background: var(--bg);
  border-radius: 8px;
  font-size: 13px;
  border-left: 3px solid var(--border);
}

.lbl {
  font-size: 11px;
  color: var(--text-3);
  margin-bottom: 4px;
}

.actions {
  display: flex;
  gap: 8px;
  margin-top: 14px;
  flex-wrap: wrap;
}
</style>
