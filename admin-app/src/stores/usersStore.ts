import { ref } from 'vue';
import { defineStore } from 'pinia';
import { usersApi, edgeApi } from '@/api/api';
import type { AdminUser } from '@/types/userTypes';

export const useUsersStore = defineStore('users', () => {
  const users = ref<AdminUser[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const hasLoaded = ref(false);

  async function fetchUsers(force = false): Promise<void> {
    if (!force && hasLoaded.value) return;

    loading.value = true;
    error.value = null;
    try {
      const [{ data: profiles, error: profilesError }, authUsers] = await Promise.all([
        usersApi.getProfiles(),
        edgeApi.listAuthUsers()
      ]);
      if (profilesError) throw profilesError;

      const authMap = new Map(authUsers.map((u) => [u.id, u]));

      users.value = (profiles ?? []).map((p) => {
        const au = authMap.get(p.id);
        const bannedUntil = au?.bannedUntil ? new Date(au.bannedUntil) : null;
        return {
          ...p,
          email: au?.email ?? null,
          isBanned: !!bannedUntil && bannedUntil > new Date()
        };
      });
      hasLoaded.value = true;
    } catch (e: unknown) {
      console.error('fetchUsers hatası:', e);
      error.value = 'Kullanıcılar yüklenemedi.';
    } finally {
      loading.value = false;
    }
  }

  async function ban(userId: string): Promise<void> {
    try {
      await edgeApi.ban(userId);
      const user = users.value.find((u) => u.id === userId);
      if (user) user.isBanned = true;
    } catch (e: unknown) {
      console.error('ban hatası:', e);
      error.value = 'Kullanıcı askıya alınamadı.';
    }
  }

  async function unban(userId: string): Promise<void> {
    try {
      await edgeApi.unban(userId);
      const user = users.value.find((u) => u.id === userId);
      if (user) user.isBanned = false;
    } catch (e: unknown) {
      console.error('unban hatası:', e);
      error.value = 'Askı kaldırılamadı.';
    }
  }

  return { users, loading, error, hasLoaded, fetchUsers, ban, unban };
});
