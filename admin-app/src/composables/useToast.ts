import { ref } from 'vue';
import type { Toast, ToastType } from '@/types/toastTypes';

// global state module seviyesinde — her çağrıda yeniden oluşmaz
const toasts = ref<Toast[]>([]);

export function useToast() {
  function add(message: string, type: ToastType = 'info', duration = 3000) {
    const id = crypto.randomUUID();
    toasts.value.push({ id, message, type });
    setTimeout(() => {
      toasts.value = toasts.value.filter((t) => t.id !== id);
    }, duration);
  }

  return {
    toasts,
    add,
    success: (msg: string, duration?: number) => add(msg, 'success', duration),
    error: (msg: string, duration?: number) => add(msg, 'error', duration),
    warning: (msg: string, duration?: number) => add(msg, 'warning', duration),
    info: (msg: string, duration?: number) => add(msg, 'info', duration)
  };
}
