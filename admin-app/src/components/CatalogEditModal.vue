<script setup lang="ts">
import { ref } from 'vue';
import BaseModal from '@/components/BaseModal.vue';
import type { CatalogBook, CatalogBookUpdate } from '@/types/catalogTypes';

const props = defineProps<{
  book: CatalogBook;
}>();

const emit = defineEmits<{
  (e: 'confirm', updates: CatalogBookUpdate): void;
  (e: 'cancel'): void;
}>();

const title = ref(props.book.title);
const author = ref(props.book.author);
const pageCount = ref(props.book.page_count?.toString() ?? '');
const language = ref(props.book.language ?? '');
const publisher = ref(props.book.publisher ?? '');
const publishedYear = ref(props.book.published_year ?? '');
const coverUrl = ref(props.book.cover_url ?? '');

function handleConfirm(): void {
  emit('confirm', {
    title: title.value.trim(),
    author: author.value.trim(),
    page_count: pageCount.value ? Number(pageCount.value) : null,
    language: language.value.trim() || null,
    publisher: publisher.value.trim() || null,
    published_year: publishedYear.value.trim() || null,
    cover_url: coverUrl.value.trim() || null
  });
}
</script>

<template>
  <BaseModal @cancel="$emit('cancel')">
    <template #header>Kitabı Düzenle</template>

    <label>Başlık</label>
    <input v-model="title" />

    <label>Yazar</label>
    <input v-model="author" />

    <div class="row">
      <div>
        <label>Sayfa Sayısı</label>
        <input v-model="pageCount" type="number" />
      </div>
      <div>
        <label>Dil</label>
        <input v-model="language" placeholder="tr, en..." />
      </div>
    </div>

    <label>Yayınevi</label>
    <input v-model="publisher" />

    <label>Yayın Yılı</label>
    <input v-model="publishedYear" />

    <label>Kapak URL</label>
    <input v-model="coverUrl" />

    <template #footer>
      <button class="btn-ghost" @click="$emit('cancel')">İptal</button>
      <button class="btn-primary" @click="handleConfirm">Kaydet</button>
    </template>
  </BaseModal>
</template>

<style scoped>
label {
  display: block;
  font-size: 12px;
  color: var(--text-2);
  margin: 10px 0 4px;
}

input {
  width: 100%;
}

.row {
  display: flex;
  gap: 10px;
}

.row > div {
  flex: 1;
}
</style>
