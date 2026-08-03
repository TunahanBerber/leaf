<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/authStore';

const router = useRouter();
const auth = useAuthStore();

const email = ref('');
const password = ref('');

async function handleSubmit(): Promise<void> {
  const ok = await auth.signIn(email.value.trim(), password.value);
  if (ok) router.push({ name: 'reports' });
}
</script>

<template>
  <div class="login-wrap">
    <form class="card login-card" @submit.prevent="handleSubmit">
      <h1>Leaf Admin</h1>
      <p class="hint">Kendi Leaf hesabınla giriş yap.</p>

      <label>Email</label>
      <input v-model="email" type="email" autocomplete="username" required />

      <label>Şifre</label>
      <input v-model="password" type="password" autocomplete="current-password" required />

      <p v-if="auth.error" class="error">{{ auth.error }}</p>

      <button class="btn-primary" type="submit" :disabled="auth.loading">
        {{ auth.loading ? 'Giriş yapılıyor...' : 'Giriş Yap' }}
      </button>
    </form>
  </div>
</template>

<style scoped>
.login-wrap {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}

.login-card {
  width: 340px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

h1 {
  font-size: 18px;
  margin: 0 0 2px;
}

.hint {
  color: var(--text-2);
  font-size: 13px;
  margin-bottom: 14px;
}

label {
  font-size: 12px;
  color: var(--text-2);
  margin-top: 10px;
}

.error {
  color: var(--danger);
  font-size: 13px;
  margin: 8px 0 0;
}

button {
  margin-top: 18px;
}
</style>
