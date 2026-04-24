import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Replace with your actual Supabase URL and Anon Key
const supabaseUrl = 'https://qowvamowkmysdjrnhkkb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvd3ZhbW93a215c2Rqcm5oa2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4NDE5MzQsImV4cCI6MjA5MDQxNzkzNH0.BsAg0sjHdvJ3WOFv2HaM9J4Z7RkNWfgyXObOYRPfVpI';

console.log("Supabase Client Init - Forced Rebuild");

export const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        storageKey: "leaf-auth-token-v2",
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,
    },
});
