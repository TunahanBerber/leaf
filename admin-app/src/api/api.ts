import { supabase } from '@/api/supabase';
import type { Report, ReportStatus } from '@/types/reportTypes';
import type { Profile } from '@/types/userTypes';
import type { CatalogBook, CatalogBookUpdate } from '@/types/catalogTypes';

export const authApi = {
  signIn: async (email: string, password: string) => {
    return supabase.auth.signInWithPassword({ email, password });
  },
  signOut: () => supabase.auth.signOut(),
  getSession: () => supabase.auth.getSession()
};

export const reportsApi = {
  getAll: async () => {
    return supabase
      .from('user_reports')
      .select('*')
      .order('created_at', { ascending: false })
      .returns<Report[]>();
  },
  updateStatus: async (id: string, status: ReportStatus) => {
    return supabase.from('user_reports').update({ status }).eq('id', id);
  }
};

export const usersApi = {
  getProfiles: async () => {
    return supabase
      .from('profiles')
      .select('id,username,bio,age,created_at')
      .order('username', { ascending: true })
      .returns<Profile[]>();
  },
  getProfilesByIds: async (ids: string[]) => {
    return supabase.from('profiles').select('id,username,bio,age,created_at').in('id', ids).returns<Profile[]>();
  },
  getMessagesByIds: async (ids: string[]) => {
    return supabase.from('messages').select('id,content').in('id', ids).returns<{ id: string; content: string }[]>();
  }
};

// GoTrue admin API gerektiren işlemler — Edge Function üzerinden, service_role sadece orada
export const edgeApi = {
  listAuthUsers: async (): Promise<{ id: string; email: string | null; bannedUntil: string | null }[]> => {
    const { data, error } = await supabase.functions.invoke('admin-actions', {
      body: { action: 'list' }
    });
    if (error) throw error;
    return data.users;
  },
  ban: async (userId: string): Promise<void> => {
    const { error } = await supabase.functions.invoke('admin-actions', {
      body: { action: 'ban', userId }
    });
    if (error) throw error;
  },
  unban: async (userId: string): Promise<void> => {
    const { error } = await supabase.functions.invoke('admin-actions', {
      body: { action: 'unban', userId }
    });
    if (error) throw error;
  },
  signOutUser: async (userId: string): Promise<void> => {
    const { error } = await supabase.functions.invoke('admin-actions', {
      body: { action: 'signout', userId }
    });
    if (error) throw error;
  }
};

export const catalogApi = {
  search: async (query: string) => {
    let q = supabase.from('book_catalog').select('*').order('added_count', { ascending: false }).limit(100);
    if (query.trim()) {
      q = q.or(`title.ilike.%${query}%,author.ilike.%${query}%`);
    }
    return q.returns<CatalogBook[]>();
  },
  update: async (id: string, updates: CatalogBookUpdate) => {
    return supabase.from('book_catalog').update(updates).eq('id', id).select().single<CatalogBook>();
  },
  remove: async (id: string) => {
    return supabase.from('book_catalog').delete().eq('id', id);
  }
};
