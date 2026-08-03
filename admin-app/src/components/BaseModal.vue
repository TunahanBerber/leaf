<script setup lang="ts">
defineEmits(['cancel']);
</script>

<template>
  <div class="overlay" @click.self="$emit('cancel')">
    <div class="modal card">
      <div class="modal-header">
        <slot name="header" />
      </div>
      <div class="modal-body">
        <slot />
      </div>
      <div class="modal-footer">
        <slot name="footer">
          <button class="btn-ghost" @click="$emit('cancel')">İptal</button>
        </slot>
      </div>
    </div>
  </div>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
}

.modal {
  width: 420px;
  max-width: calc(100vw - 40px);
  max-height: calc(100vh - 40px);
  overflow-y: auto;
}

.modal-header {
  font-weight: 700;
  font-size: 15px;
  margin-bottom: 14px;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 18px;
}
</style>
