<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useReportsStore } from '@/stores/reportsStore';
import { useToast } from '@/composables/useToast';
import { edgeApi } from '@/api/api';
import ReportCard from '@/components/ReportCard.vue';
import BaseModal from '@/components/BaseModal.vue';
import type { ReportStatus } from '@/types/reportTypes';

const store = useReportsStore();
const toast = useToast();

const filter = ref<ReportStatus | 'all'>('pending');

const filtered = computed(() => {
  if (filter.value === 'all') return store.reports;
  return store.reports.filter((r) => r.status === filter.value);
});

const counts = computed(() => {
  const c = { pending: 0, reviewed: 0, resolved: 0 };
  for (const r of store.reports) c[r.status]++;
  return c;
});

async function handleStatusChange(payload: { id: string; status: ReportStatus }): Promise<void> {
  await store.updateStatus(payload.id, payload.status);
  toast.success('Durum güncellendi');
}

type PendingAction = { type: 'ban' | 'signout'; userId: string; username: string };
const pendingAction = ref<PendingAction | null>(null);

const confirmCopy = computed(() => {
  if (!pendingAction.value) return null;
  return pendingAction.value.type === 'ban'
    ? {
        title: 'Kullanıcıyı askıya al',
        body: `${pendingAction.value.username} askıya alınacak. Devam edilsin mi?`,
        confirmLabel: 'Askıya Al',
      }
    : {
        title: 'Oturumları sonlandır',
        body: `${pendingAction.value.username} kullanıcısının tüm aktif oturumları sonlandırılacak. Devam edilsin mi?`,
        confirmLabel: 'Sonlandır',
      };
});

function handleBan(payload: { userId: string; username: string }): void {
  pendingAction.value = { type: 'ban', ...payload };
}

function handleSignOut(payload: { userId: string; username: string }): void {
  pendingAction.value = { type: 'signout', ...payload };
}

async function confirmPendingAction(): Promise<void> {
  const action = pendingAction.value;
  if (!action) return;
  pendingAction.value = null;

  if (action.type === 'ban') {
    await store.banReportedUser(action.userId);
    toast.success('Kullanıcı askıya alındı');
  } else {
    try {
      await edgeApi.signOutUser(action.userId);
      toast.success('Oturumlar sonlandırıldı');
    } catch (e: unknown) {
      console.error('signOutUser hatası:', e);
      toast.error('Oturumlar sonlandırılamadı');
    }
  }
}

onMounted(() => {
  store.fetchReports();
});
</script>

<template>
  <div>
    <div class="header">
      <div>
        <h1>Şikayetler</h1>
        <p class="subtitle">Kullanıcı şikayetlerini inceleyin ve aksiyon alın</p>
      </div>
      <button class="btn-ghost" @click="store.fetchReports(true)">Yenile</button>
    </div>

    <div class="stats">
      <div class="card stat">
        <div class="n">{{ counts.pending }}</div>
        <div class="l">Bekleyen</div>
      </div>
      <div class="card stat">
        <div class="n">{{ counts.reviewed }}</div>
        <div class="l">İncelendi</div>
      </div>
      <div class="card stat">
        <div class="n">{{ counts.resolved }}</div>
        <div class="l">Çözüldü</div>
      </div>
      <div class="card stat">
        <div class="n">{{ store.reports.length }}</div>
        <div class="l">Toplam</div>
      </div>
    </div>

    <div class="tabs">
      <button
        v-for="f in (['pending', 'reviewed', 'resolved', 'all'] as const)"
        :key="f"
        class="btn-ghost"
        :class="{ active: filter === f }"
        @click="filter = f"
      >
        {{ { pending: 'Bekleyen', reviewed: 'İncelendi', resolved: 'Çözüldü', all: 'Tümü' }[f] }}
      </button>
    </div>

    <p v-if="store.error" class="error">{{ store.error }}</p>

    <div v-if="store.loading" class="empty">Yükleniyor...</div>
    <div v-else-if="!filtered.length" class="empty">Bu filtrede şikayet yok.</div>
    <ReportCard
      v-for="report in filtered"
      :key="report.id"
      :report="report"
      @status-change="handleStatusChange"
      @ban="handleBan"
      @signout="handleSignOut"
    />

    <BaseModal v-if="confirmCopy" @cancel="pendingAction = null">
      <template #header>{{ confirmCopy.title }}</template>
      <p>{{ confirmCopy.body }}</p>
      <template #footer>
        <button class="btn-ghost" @click="pendingAction = null">İptal</button>
        <button class="btn-danger" @click="confirmPendingAction">{{ confirmCopy.confirmLabel }}</button>
      </template>
    </BaseModal>
  </div>
</template>

<style scoped>
.header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 20px;
}

h1 {
  font-size: 22px;
  margin: 0;
}

.subtitle {
  color: var(--text-2);
  font-size: 13px;
  margin: 4px 0 0;
}

.stats {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.stat {
  flex: 1;
  padding: 12px 16px;
}

.n {
  font-size: 22px;
  font-weight: 700;
}

.l {
  font-size: 12px;
  color: var(--text-2);
}

.tabs {
  display: flex;
  gap: 6px;
  margin-bottom: 16px;
}

.tabs .active {
  background: var(--accent);
  color: white;
  border-color: transparent;
}

.error {
  color: var(--danger);
  font-size: 13px;
}
</style>
