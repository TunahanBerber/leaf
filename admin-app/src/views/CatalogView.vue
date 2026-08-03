<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useCatalogStore } from '@/stores/catalogStore';
import { useToast } from '@/composables/useToast';
import CatalogEditModal from '@/components/CatalogEditModal.vue';
import type { CatalogBook, CatalogBookUpdate } from '@/types/catalogTypes';

const store = useCatalogStore();
const toast = useToast();

const search = ref('');
const editingBook = ref<CatalogBook | null>(null);
let debounceTimer: ReturnType<typeof setTimeout> | undefined;

watch(search, (value) => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => store.search(value), 250);
});

async function handleSaveEdit(updates: CatalogBookUpdate): Promise<void> {
  if (!editingBook.value) return;
  const ok = await store.updateBook(editingBook.value.id, updates);
  if (ok) {
    toast.success('Kitap güncellendi');
    editingBook.value = null;
  } else {
    toast.error('Güncellenemedi');
  }
}

async function handleDelete(book: CatalogBook): Promise<void> {
  const confirmed = window.confirm(`"${book.title}" kataloğdan silinsin mi?`);
  if (!confirmed) return;

  const ok = await store.removeBook(book.id);
  if (ok) {
    toast.success('Kitap silindi');
  } else {
    toast.error('Silinemedi');
  }
}

function metaLine(book: CatalogBook): string {
  const parts = [book.publisher, book.published_year, book.language, book.page_count ? `${book.page_count} sayfa` : null];
  return parts.filter(Boolean).join(' · ');
}

onMounted(() => {
  store.search('');
});
</script>

<template>
  <div>
    <div class="header">
      <h1>Kitap Kataloğu</h1>
      <button class="btn-ghost" @click="store.search(search)">Yenile</button>
    </div>

    <input v-model="search" placeholder="Başlık veya yazar ara..." class="search" />

    <p v-if="store.error" class="error">{{ store.error }}</p>

    <div v-if="store.loading" class="empty">Yükleniyor...</div>
    <div v-else-if="!store.books.length" class="empty">Sonuç bulunamadı.</div>

    <div v-for="book in store.books" :key="book.id" class="card book-row">
      <img v-if="book.cover_url" :src="book.cover_url" class="cover" alt="" />
      <div v-else class="cover cover-placeholder">📖</div>

      <div class="info">
        <div class="title">{{ book.title }}</div>
        <div class="author">{{ book.author }}</div>
        <div class="meta">{{ metaLine(book) || 'Meta bilgi eksik' }}</div>
      </div>

      <span class="tag tag-accent count">{{ book.added_count }}× eklendi</span>

      <div class="actions">
        <button class="btn-ghost" @click="editingBook = book">Düzenle</button>
        <button class="btn-danger" @click="handleDelete(book)">Sil</button>
      </div>
    </div>

    <CatalogEditModal
      v-if="editingBook"
      :book="editingBook"
      @confirm="handleSaveEdit"
      @cancel="editingBook = null"
    />
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

.book-row {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 10px;
}

.cover {
  width: 40px;
  height: 56px;
  border-radius: 4px;
  object-fit: cover;
  flex-shrink: 0;
}

.cover-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg);
  font-size: 18px;
}

.info {
  flex: 1;
  min-width: 0;
}

.title {
  font-weight: 700;
  font-size: 14px;
}

.author {
  font-size: 13px;
  color: var(--text-2);
}

.meta {
  font-size: 12px;
  color: var(--text-3);
  margin-top: 2px;
}

.count {
  flex-shrink: 0;
}

.actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.error {
  color: var(--danger);
  font-size: 13px;
}
</style>
