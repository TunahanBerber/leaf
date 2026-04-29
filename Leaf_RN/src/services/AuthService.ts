import { supabase } from './supabase';
import { User } from '@supabase/supabase-js';
import { Platform } from 'react-native';
import * as WebBrowser from 'expo-web-browser';
import * as QueryParams from 'expo-auth-session/build/QueryParams';
import { makeRedirectUri } from 'expo-auth-session';

WebBrowser.maybeCompleteAuthSession();
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
     * Sign in with Google OAuth
     */
    static async signInWithGoogle(): Promise<User | null> {
        if (Platform.OS === 'web') {
            const { error } = await supabase.auth.signInWithOAuth({
                provider: 'google',
            });
            if (error) {
                throw new Error(this.mapAuthError(error));
            }
            // For web, it redirects the entire page, so execution stops here.
            return null;
        }

        const redirectTo = makeRedirectUri();
        
        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo,
                skipBrowserRedirect: true,
            },
        });
        
        if (error) {
            throw new Error(this.mapAuthError(error));
        }

        if (!data?.url) {
            throw new Error('Google giriş bağlantısı oluşturulamadı.');
        }

        const res = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);

        if (res.type === 'success') {
            const { url } = res;
            const { params, errorCode } = QueryParams.getQueryParams(url);

            if (errorCode) {
                throw new Error(errorCode);
            }

            const { access_token, refresh_token } = params;

            if (!access_token || !refresh_token) {
                return null;
            }

            const { data: sessionData, error: sessionError } = await supabase.auth.setSession({
                access_token,
                refresh_token,
            });

            if (sessionError) {
                throw new Error(this.mapAuthError(sessionError));
            }

            return sessionData.user;
        }

        return null;
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
