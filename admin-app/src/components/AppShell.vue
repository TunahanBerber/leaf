<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/authStore';

const router = useRouter();
const auth = useAuthStore();

async function handleSignOut(): Promise<void> {
  await auth.signOut();
  router.push({ name: 'login' });
}
</script>

<template>
  <div class="shell">
    <nav class="sidebar">
      <div class="brand">Leaf Admin</div>
      <RouterLink to="/reports" class="nav-link">Şikayetler</RouterLink>
      <RouterLink to="/users" class="nav-link">Kullanıcılar</RouterLink>
      <RouterLink to="/catalog" class="nav-link">Kitap Kataloğu</RouterLink>
      <div class="spacer" />
      <div class="account">{{ auth.email }}</div>
      <button class="btn-ghost" @click="handleSignOut">Çıkış Yap</button>
    </nav>
    <main class="content">
      <div class="content-inner">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<style scoped>
.shell {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  width: 220px;
  flex-shrink: 0;
  background: var(--surface);
  border-right: 1px solid var(--border);
  padding: 20px 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.brand {
  font-weight: 700;
  font-size: 16px;
  margin-bottom: 16px;
  padding: 0 8px;
}

.nav-link {
  padding: 9px 10px;
  border-radius: 8px;
  color: var(--text-2);
  text-decoration: none;
  font-weight: 600;
  font-size: 13px;
}

.nav-link:hover {
  background: var(--bg);
}

.nav-link.router-link-active {
  background: var(--accent-bg);
  color: var(--accent);
}

.spacer {
  flex: 1;
}

.account {
  font-size: 12px;
  color: var(--text-3);
  padding: 0 8px 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.content {
  flex: 1;
  display: flex;
  justify-content: center;
  padding: 32px;
}

.content-inner {
  width: 100%;
  max-width: 960px;
}
</style>
