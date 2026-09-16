<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useUsersStore } from '@/stores/usersStore';
import { useToast } from '@/composables/useToast';
import { edgeApi } from '@/api/api';
import type { AdminUser } from '@/types/userTypes';
import BaseModal from '@/components/BaseModal.vue';

const PAGE_SIZE = 10;

const store = useUsersStore();
const toast = useToast();

const search = ref('');
const sort = ref<'newest' | 'oldest' | 'name'>('newest');
const page = ref(1);

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  let list = store.users;
  if (q) {
    list = list.filter(
      (u) => u.username.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q)
    );
  }

  return [...list].sort((a, b) => {
    if (sort.value === 'name') return a.username.localeCompare(b.username, 'tr');
    const aTime = a.created_at ? new Date(a.created_at).getTime() : 0;
    const bTime = b.created_at ? new Date(b.created_at).getTime() : 0;
    return sort.value === 'newest' ? bTime - aTime : aTime - bTime;
  });
});

const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / PAGE_SIZE)));

const pageItems = computed(() => {
  const start = (page.value - 1) * PAGE_SIZE;
  return filtered.value.slice(start, start + PAGE_SIZE);
});

const pageNumbers = computed(() => {
  const total = totalPages.value;
  const current = page.value;
  const numbers: (number | '...')[] = [];
  for (let i = 1; i <= total; i++) {
    if (i === 1 || i === total || Math.abs(i - current) <= 1) {
      numbers.push(i);
    } else if (numbers[numbers.length - 1] !== '...') {
      numbers.push('...');
    }
  }
  return numbers;
});

function goToPage(n: number): void {
  page.value = Math.min(Math.max(1, n), totalPages.value);
}

function initials(username: string): string {
  return username.slice(0, 2).toUpperCase();
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short', year: 'numeric' });
}

type PendingAction = { type: 'ban' | 'unban' | 'signout'; user: AdminUser };
const pendingAction = ref<PendingAction | null>(null);

const confirmCopy = computed(() => {
  switch (pendingAction.value?.type) {
    case 'ban':
      return {
        title: 'Kullanıcıyı askıya al',
        body: `${pendingAction.value.user.username} askıya alınacak. Devam edilsin mi?`,
        confirmLabel: 'Askıya Al',
      };
    case 'unban':
      return {
        title: 'Askıyı kaldır',
        body: `${pendingAction.value.user.username} kullanıcısının askısı kaldırılacak. Devam edilsin mi?`,
        confirmLabel: 'Askıyı Kaldır',
      };
    case 'signout':
      return {
        title: 'Oturumları sonlandır',
        body: `${pendingAction.value.user.username} kullanıcısının tüm aktif oturumları sonlandırılacak. Devam edilsin mi?`,
        confirmLabel: 'Sonlandır',
      };
    default:
      return null;
  }
});

function requestBan(user: AdminUser): void {
  pendingAction.value = { type: 'ban', user };
}

function requestUnban(user: AdminUser): void {
  pendingAction.value = { type: 'unban', user };
}

function requestSignOut(user: AdminUser): void {
  pendingAction.value = { type: 'signout', user };
}

async function confirmPendingAction(): Promise<void> {
  const action = pendingAction.value;
  if (!action) return;
  pendingAction.value = null;

  if (action.type === 'ban') {
    await store.ban(action.user.id);
    toast.success('Kullanıcı askıya alındı');
  } else if (action.type === 'unban') {
    await store.unban(action.user.id);
    toast.success('Askı kaldırıldı');
  } else {
    try {
      await edgeApi.signOutUser(action.user.id);
      toast.success('Oturumlar sonlandırıldı');
    } catch (e: unknown) {
      console.error('signOutUser hatası:', e);
      toast.error('Oturumlar sonlandırılamadı');
    }
  }
}

onMounted(() => {
  store.fetchUsers();
});
</script>

<template>
  <div>
    <div class="header">
      <div>
        <h1>Kullanıcı Yönetimi</h1>
        <p class="subtitle">Sisteme kayıtlı kullanıcıları görüntüleyin ve yönetin</p>
      </div>
      <button class="btn-ghost" @click="store.fetchUsers(true)">Yenile</button>
    </div>

    <div class="toolbar">
      <input v-model="search" placeholder="Kullanıcı ara..." class="search" @input="page = 1" />
      <select v-model="sort">
        <option value="newest">En Yeni</option>
        <option value="oldest">En Eski</option>
        <option value="name">Ada Göre</option>
      </select>
    </div>

    <p v-if="store.error" class="error">{{ store.error }}</p>

    <div v-if="store.loading" class="empty">Yükleniyor...</div>
    <div v-else-if="!filtered.length" class="empty">Kullanıcı bulunamadı.</div>

    <div v-else class="table-wrap card">
      <table>
        <thead>
          <tr>
            <th>Kullanıcı</th>
            <th>Email</th>
            <th>Durum</th>
            <th>Kayıt Tarihi</th>
            <th>İşlemler</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in pageItems" :key="user.id">
            <td>
              <div class="user-cell">
                <span class="avatar">{{ initials(user.username) }}</span>
                <span class="username">{{ user.username }}</span>
              </div>
            </td>
            <td class="muted">{{ user.email ?? '—' }}</td>
            <td>
              <span class="pill" :class="user.isBanned ? 'pill-danger' : 'pill-accent'">
                {{ user.isBanned ? 'Askıda' : 'Aktif' }}
              </span>
            </td>
            <td class="muted">{{ formatDate(user.created_at) }}</td>
            <td>
              <div class="row-actions">
                <button
                  v-if="user.isBanned"
                  class="icon-btn icon-btn-accent"
                  title="Askıyı kaldır"
                  @click="requestUnban(user)"
                >
                  ✓
                </button>
                <button v-else class="icon-btn icon-btn-danger" title="Askıya al" @click="requestBan(user)">
                  ⛔
                </button>
                <button class="icon-btn" title="Oturumları sonlandır" @click="requestSignOut(user)">↩</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <div class="pagination">
        <button class="btn-ghost" :disabled="page === 1" @click="goToPage(page - 1)">Önceki</button>
        <template v-for="(n, i) in pageNumbers" :key="i">
          <span v-if="n === '...'" class="ellipsis">…</span>
          <button v-else class="page-btn" :class="{ active: n === page }" @click="goToPage(n)">{{ n }}</button>
        </template>
        <button class="btn-ghost" :disabled="page === totalPages" @click="goToPage(page + 1)">Sonraki</button>
      </div>
    </div>

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

.toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}

.search {
  flex: 1;
}

.error {
  color: var(--danger);
  font-size: 13px;
}

.table-wrap {
  padding: 0;
  overflow: hidden;
}

table {
  width: 100%;
  border-collapse: collapse;
}

thead th {
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-3);
  padding: 14px 18px;
  border-bottom: 1px solid var(--border);
}

tbody td {
  padding: 14px 18px;
  border-bottom: 1px solid var(--border);
  font-size: 13px;
}

tbody tr:last-child td {
  border-bottom: none;
}

tbody tr:hover {
  background: var(--bg);
}

.muted {
  color: var(--text-2);
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.avatar {
  width: 32px;
  height: 32px;
  border-radius: 999px;
  background: var(--accent-bg);
  color: var(--accent);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  flex-shrink: 0;
}

.username {
  font-weight: 600;
}

.pill {
  display: inline-block;
  padding: 3px 12px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
}

.pill-accent {
  background: var(--accent-bg);
  color: var(--accent);
}

.pill-danger {
  background: var(--danger-bg);
  color: var(--danger);
}

.row-actions {
  display: flex;
  gap: 6px;
}

.icon-btn {
  width: 30px;
  height: 30px;
  padding: 0;
  border-radius: 8px;
  background: var(--bg);
  border: 1px solid var(--border);
  color: var(--text-2);
  font-size: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.icon-btn-danger {
  color: var(--danger);
}

.icon-btn-accent {
  color: var(--accent);
}

.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 16px 18px;
}

.page-btn {
  width: 32px;
  height: 32px;
  padding: 0;
  border-radius: 8px;
  background: transparent;
  color: var(--text-2);
  font-weight: 600;
}

.page-btn.active {
  background: var(--accent);
  color: white;
}

.ellipsis {
  color: var(--text-3);
  padding: 0 4px;
}

button:disabled {
  opacity: 0.4;
  cursor: default;
}
</style>
