import { supabase } from './supabase';
import { User } from '@supabase/supabase-js';

export class AuthService {
    /**
     * Listen to auth state changes
     * @param callback Function to call when auth state changes
     */
    static onAuthStateChange(callback: (user: User | null) => void) {
        const { data } = supabase.auth.onAuthStateChange((_event, session) => {
            callback(session?.user ?? null);
        });
        return data.subscription.unsubscribe;
    }

    /**
     * Get current auth session
     */
    static async getSession() {
        const { data: { session }, error } = await supabase.auth.getSession();
        if (error) {
            console.error('getSession error', error);
            return null;
        }
        return session;
    }

    /**
     * Sign up with email and password
     */
    static async signUp(email: string, password: string): Promise<User | null> {
        const { data, error } = await supabase.auth.signUp({ email, password });
        if (error) {
            throw new Error(this.mapAuthError(error));
        }
        return data.user;
    }

    /**
     * Sign in with email and password
     */
    static async signIn(email: string, password: string): Promise<User | null> {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) {
            throw new Error(this.mapAuthError(error));
        }
        return data.user;
    }

    /**
     * Sign out
     */
    static async signOut(): Promise<void> {
        const { error } = await supabase.auth.signOut();
        if (error) {
            throw new Error(this.mapAuthError(error));
        }
    }

    /**
     * Reset password for email
     */
    static async resetPassword(email: string): Promise<void> {
        const { error } = await supabase.auth.resetPasswordForEmail(email);
        if (error) {
            throw new Error(this.mapAuthError(error));
        }
    }

    /**
     * Map Supabase errors to Turkish readable messages
     */
    private static mapAuthError(error: any): string {
        const message = (error?.message || '').toLowerCase();
        if (message.includes('invalid login credentials') || message.includes('invalid_credentials')) {
            return 'Email veya şifre hatalı.';
        } else if (message.includes('email already registered') || message.includes('user_already_exists')) {
            return 'Bu email adresi zaten kayıtlı.';
        } else if (message.includes('password should be')) {
            return 'Şifre en az 6 karakter olmalı.';
        } else if (message.includes('network') || message.includes('connection')) {
            return 'İnternet bağlantısı kurulamadı.';
        }
        return `Bir hata oluştu: ${error.message || 'Unknown error'}`;
    }
}
