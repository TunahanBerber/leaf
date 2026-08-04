<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useCatalogStore } from '@/stores/catalogStore';
import { useToast } from '@/composables/useToast';
import CatalogEditModal from '@/components/CatalogEditModal.vue';
import type { CatalogBook, CatalogBookUpdate } from '@/types/catalogTypes';

const PAGE_SIZE = 10;

const store = useCatalogStore();
const toast = useToast();

const search = ref('');
const page = ref(1);
const editingBook = ref<CatalogBook | null>(null);
let debounceTimer: ReturnType<typeof setTimeout> | undefined;

watch(search, (value) => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    page.value = 1;
    store.search(value);
  }, 250);
});

const totalPages = computed(() => Math.max(1, Math.ceil(store.books.length / PAGE_SIZE)));

const pageItems = computed(() => {
  const start = (page.value - 1) * PAGE_SIZE;
  return store.books.slice(start, start + PAGE_SIZE);
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
    if (pageItems.value.length === 0 && page.value > 1) page.value -= 1;
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
      <div>
        <h1>Kitap Kataloğu</h1>
        <p class="subtitle">Kullanıcıların eklediği kitapları düzenleyin ve birleştirin</p>
      </div>
      <button class="btn-ghost" @click="store.search(search)">Yenile</button>
    </div>

    <input v-model="search" placeholder="Başlık veya yazar ara..." class="search" />

    <p v-if="store.error" class="error">{{ store.error }}</p>

    <div v-if="store.loading" class="empty">Yükleniyor...</div>
    <div v-else-if="!store.books.length" class="empty">Sonuç bulunamadı.</div>

    <div v-else class="table-wrap card">
      <table>
        <thead>
          <tr>
            <th>Kitap</th>
            <th>Detaylar</th>
            <th>Eklenme</th>
            <th>İşlemler</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="book in pageItems" :key="book.id">
            <td>
              <div class="book-cell">
                <img v-if="book.cover_url" :src="book.cover_url" class="cover" alt="" />
                <div v-else class="cover cover-placeholder">📖</div>
                <div>
                  <div class="title">{{ book.title }}</div>
                  <div class="author">{{ book.author }}</div>
                </div>
              </div>
            </td>
            <td class="muted">{{ metaLine(book) || '—' }}</td>
            <td>
              <span class="pill pill-accent">{{ book.added_count }}×</span>
            </td>
            <td>
              <div class="row-actions">
                <button class="icon-btn" title="Düzenle" @click="editingBook = book">✎</button>
                <button class="icon-btn icon-btn-danger" title="Sil" @click="handleDelete(book)">🗑</button>
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

.search {
  width: 100%;
  margin-bottom: 16px;
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
  padding: 12px 18px;
  border-bottom: 1px solid var(--border);
  font-size: 13px;
  vertical-align: middle;
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

.book-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.cover {
  width: 32px;
  height: 46px;
  border-radius: 4px;
  object-fit: cover;
  flex-shrink: 0;
}

.cover-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg);
  font-size: 14px;
}

.title {
  font-weight: 700;
  font-size: 13px;
}

.author {
  font-size: 12px;
  color: var(--text-2);
  margin-top: 2px;
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
