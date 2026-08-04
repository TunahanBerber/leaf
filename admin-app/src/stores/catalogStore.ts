import { ref } from 'vue';
import { defineStore } from 'pinia';
import { catalogApi } from '@/api/api';
import type { CatalogBook, CatalogBookUpdate, CatalogStatus } from '@/types/catalogTypes';

export const useCatalogStore = defineStore('catalog', () => {
  const books = ref<CatalogBook[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const hasLoaded = ref(false);

  async function search(query = ''): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: searchError } = await catalogApi.search(query);
      if (searchError) throw searchError;
      books.value = data ?? [];
      hasLoaded.value = true;
    } catch (e: unknown) {
      console.error('search hatası:', e);
      error.value = 'Katalog yüklenemedi.';
    } finally {
      loading.value = false;
    }
  }

  async function updateBook(id: string, updates: CatalogBookUpdate): Promise<boolean> {
    try {
      const { data, error: updateError } = await catalogApi.update(id, updates);
      if (updateError) throw updateError;
      const book = books.value.find((b) => b.id === id);
      if (book && data) Object.assign(book, data);
      return true;
    } catch (e: unknown) {
      console.error('updateBook hatası:', e);
      error.value = 'Kitap güncellenemedi.';
      return false;
    }
  }

  async function setStatus(id: string, status: CatalogStatus): Promise<boolean> {
    try {
      const { data, error: statusError } = await catalogApi.setStatus(id, status);
      if (statusError) throw statusError;
      const book = books.value.find((b) => b.id === id);
      if (book && data) Object.assign(book, data);
      return true;
    } catch (e: unknown) {
      console.error('setStatus hatası:', e);
      error.value = 'Durum güncellenemedi.';
      return false;
    }
  }

  async function removeBook(id: string): Promise<boolean> {
    try {
      const { error: removeError } = await catalogApi.remove(id);
      if (removeError) throw removeError;
      books.value = books.value.filter((b) => b.id !== id);
      return true;
    } catch (e: unknown) {
      console.error('removeBook hatası:', e);
      error.value = 'Kitap silinemedi.';
      return false;
    }
  }

  return { books, loading, error, hasLoaded, search, updateBook, setStatus, removeBook };
});
