import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '@/stores/authStore';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue') },
    { path: '/', redirect: '/reports' },
    { path: '/reports', name: 'reports', component: () => import('@/views/ReportsView.vue') },
    { path: '/users', name: 'users', component: () => import('@/views/UsersView.vue') },
    { path: '/catalog', name: 'catalog', component: () => import('@/views/CatalogView.vue') }
  ]
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  if (!auth.hasLoaded) {
    await auth.restoreSession();
  }

  if (to.name !== 'login' && !auth.userId) {
    return { name: 'login' };
  }
  if (to.name === 'login' && auth.userId) {
    return { name: 'reports' };
  }
});

export default router;
