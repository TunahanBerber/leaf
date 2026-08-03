import { ref } from 'vue';
import { defineStore } from 'pinia';
import { authApi } from '@/api/api';
import { supabase } from '@/api/supabase';

export const useAuthStore = defineStore('auth', () => {
  const userId = ref<string | null>(null);
  const email = ref<string | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const hasLoaded = ref(false);

  async function restoreSession(): Promise<void> {
    loading.value = true;
    try {
      const {
        data: { session }
      } = await authApi.getSession();
      userId.value = session?.user.id ?? null;
      email.value = session?.user.email ?? null;
    } finally {
      loading.value = false;
      hasLoaded.value = true;
    }
  }

  async function signIn(emailInput: string, password: string): Promise<boolean> {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: signInError } = await authApi.signIn(emailInput, password);
      if (signInError) {
        error.value = 'Giriş başarısız. Email veya şifre hatalı.';
        return false;
      }
      userId.value = data.user?.id ?? null;
      email.value = data.user?.email ?? null;
      return true;
    } catch (e: unknown) {
      console.error('signIn hatası:', e);
      error.value = 'Bir hata oluştu.';
      return false;
    } finally {
      loading.value = false;
    }
  }

  async function signOut(): Promise<void> {
    await authApi.signOut();
    userId.value = null;
    email.value = null;
  }

  // oturum başka bir yerden (token yenileme, süre dolması) değişirse yakala
  supabase.auth.onAuthStateChange((_event, session) => {
    userId.value = session?.user.id ?? null;
    email.value = session?.user.email ?? null;
  });

  return { userId, email, loading, error, hasLoaded, restoreSession, signIn, signOut };
});
