import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

// tüm admin-app burada tek bir istemci kullanıyor — publishable/anon key,
// admin kendi hesabıyla giriş yapınca RLS onun auth.uid()'ine göre açılıyor
export const supabase = createClient(url, anonKey);
