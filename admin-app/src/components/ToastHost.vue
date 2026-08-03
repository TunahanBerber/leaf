<script setup lang="ts">
import { useToast } from '@/composables/useToast';

const { toasts } = useToast();
</script>

<template>
  <div class="toast-host">
    <div v-for="t in toasts" :key="t.id" class="toast" :class="`toast-${t.type}`">
      {{ t.message }}
    </div>
  </div>
</template>

<style scoped>
.toast-host {
  position: fixed;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 100;
}

.toast {
  background: var(--text);
  color: var(--bg);
  padding: 10px 18px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 600;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.toast-error {
  background: var(--danger);
  color: white;
}

.toast-success {
  background: var(--accent);
  color: white;
}
</style>
