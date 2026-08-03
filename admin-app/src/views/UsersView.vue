<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useUsersStore } from '@/stores/usersStore';
import { useToast } from '@/composables/useToast';
import { edgeApi } from '@/api/api';

const store = useUsersStore();
const toast = useToast();

const search = ref('');

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  if (!q) return store.users;
  return store.users.filter(
    (u) => u.username.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q)
  );
});

async function handleBan(userId: string): Promise<void> {
  await store.ban(userId);
  toast.success('Kullanıcı askıya alındı');
}

async function handleUnban(userId: string): Promise<void> {
  await store.unban(userId);
  toast.success('Askı kaldırıldı');
}

async function handleSignOut(userId: string): Promise<void> {
  try {
    await edgeApi.signOutUser(userId);
    toast.success('Oturumlar sonlandırıldı');
  } catch (e: unknown) {
    console.error('signOutUser hatası:', e);
    toast.error('Oturumlar sonlandırılamadı');
  }
}

onMounted(() => {
  store.fetchUsers();
});
</script>

<template>
  <div>
    <div class="header">
      <h1>Kullanıcılar</h1>
      <button class="btn-ghost" @click="store.fetchUsers(true)">Yenile</button>
    </div>

    <input v-model="search" placeholder="Kullanıcı adı veya email ara..." class="search" />

    <p v-if="store.error" class="error">{{ store.error }}</p>

    <div v-if="store.loading" class="empty">Yükleniyor...</div>
    <div v-else-if="!filtered.length" class="empty">Kullanıcı bulunamadı.</div>

    <div v-for="user in filtered" :key="user.id" class="card user-card">
      <div class="top">
        <div>
          <span class="tag" :class="user.isBanned ? 'tag-danger' : 'tag-accent'">
            {{ user.isBanned ? 'Askıda' : 'Aktif' }}
          </span>
          <div class="who"><b>{{ user.username }}</b></div>
          <div v-if="user.email" class="email">{{ user.email }}</div>
        </div>
      </div>
      <div class="actions">
        <button v-if="user.isBanned" class="btn-warn" @click="handleUnban(user.id)">Askıyı Kaldır</button>
        <button v-else class="btn-danger" @click="handleBan(user.id)">Hesabı Askıya Al</button>
        <button class="btn-warn" @click="handleSignOut(user.id)">Oturumları Sonlandır</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

h1 {
  font-size: 20px;
  margin: 0;
}

.search {
  width: 100%;
  margin-bottom: 16px;
}

.user-card {
  margin-bottom: 12px;
}

.who {
  font-size: 14px;
  margin-top: 6px;
}

.email {
  font-size: 12px;
  color: var(--text-2);
  margin-top: 2px;
}

.actions {
  display: flex;
  gap: 8px;
  margin-top: 14px;
  flex-wrap: wrap;
}

.error {
  color: var(--danger);
  font-size: 13px;
}
</style>
