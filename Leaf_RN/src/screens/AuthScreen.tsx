import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { GlassCard } from '../components/GlassCard';
import { Theme, getTheme } from '../components/theme';
import { BookOpen, Mail, Lock, User as UserIcon } from 'lucide-react-native';
import { AuthService } from '../services/AuthService';
import { SocialService } from '../services/SocialService';

interface AuthScreenProps {
    isDark?: boolean;
}

export const AuthScreen: React.FC<AuthScreenProps> = ({ isDark = false }) => {
    const theme = getTheme(isDark);
    const [isSignUp, setIsSignUp] = useState(false);
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [username, setUsername] = useState(''); // Added for profile creation on signup
    const [isLoading, setIsLoading] = useState(false);
    const [errorMessage, setErrorMessage] = useState('');

    const handleAuth = async () => {
        setIsLoading(true);
        setErrorMessage('');
        try {
            if (isSignUp) {
                if (!username) throw new Error("Kullanıcı adı gerekli.");
                await AuthService.signUp(email, password);
                // We simulate a profile creation right after sign up
                // In reality, it may require listening to auth state then creating profile.
                await SocialService.createProfile(username, '', 18);
            } else {
                await AuthService.signIn(email, password);
            }
        } catch (e: any) {
            setErrorMessage(e.message);
        } finally {
            setIsLoading(false);
        }
    };

    const resetPassword = async () => {
        if (!email) {
            setErrorMessage("Lütfen önce email adresinizi girin.");
            return;
        }
        try {
            await AuthService.resetPassword(email);
            Alert.alert("E-posta Gönderildi", `${email} adresine sıfırlama bağlantısı gönderildi.`);
        } catch (e: any) {
            setErrorMessage(e.message);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <ScrollView contentContainerStyle={styles.scroll}>
                <View style={styles.header}>
                    <BookOpen size={56} color={theme.primary} />
                    <Text style={[styles.title, { color: theme.textPrimary }]}>Leaf</Text>
                    <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
                        {isSignUp ? 'Hesap Oluştur' : 'Hoş Geldin'}
                    </Text>
                </View>

                <GlassCard isDark={isDark} style={styles.formCard}>
                    <View style={styles.inputs}>
                        {isSignUp && (
                            <View style={[styles.inputBox, { backgroundColor: theme.surfaceSecondary }]}>
                                <UserIcon color={theme.textTertiary} size={20} />
                                <TextInput
                                    style={[styles.input, { color: theme.textPrimary }]}
                                    placeholder="Kullanıcı Adı"
                                    placeholderTextColor={theme.textTertiary}
                                    value={username}
                                    onChangeText={setUsername}
                                    autoCapitalize="none"
                                />
                            </View>
                        )}

                        <View style={[styles.inputBox, { backgroundColor: theme.surfaceSecondary }]}>
                            <Mail color={theme.textTertiary} size={20} />
                            <TextInput
                                style={[styles.input, { color: theme.textPrimary }]}
                                placeholder="Email"
                                placeholderTextColor={theme.textTertiary}
                                value={email}
                                onChangeText={setEmail}
                                keyboardType="email-address"
                                autoCapitalize="none"
                            />
                        </View>

                        <View style={[styles.inputBox, { backgroundColor: theme.surfaceSecondary }]}>
                            <Lock color={theme.textTertiary} size={20} />
                            <TextInput
                                style={[styles.input, { color: theme.textPrimary }]}
                                placeholder="Şifre"
                                placeholderTextColor={theme.textTertiary}
                                value={password}
                                onChangeText={setPassword}
                                secureTextEntry
                            />
                        </View>
                    </View>

                    {errorMessage ? (
                        <Text style={styles.errorText}>{errorMessage}</Text>
                    ) : null}

                    <TouchableOpacity
                        style={[styles.submitButton, { backgroundColor: theme.primary }]}
                        disabled={isLoading || !email || !password || (isSignUp && !username)}
                        onPress={handleAuth}
                    >
                        {isLoading ? <ActivityIndicator color="#fff" /> : <Text style={styles.submitText}>{isSignUp ? 'Kayıt Ol' : 'Giriş Yap'}</Text>}
                    </TouchableOpacity>

                    <View style={styles.dividerWrap}>
                        <View style={[styles.divider, { backgroundColor: theme.borderPrimary }]} />
                        <Text style={[styles.dividerText, { color: theme.textSecondary }]}>VEYA</Text>
                        <View style={[styles.divider, { backgroundColor: theme.borderPrimary }]} />
                    </View>

                    <TouchableOpacity style={[styles.googleButton, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderPrimary }]}>
                        <Text style={[styles.googleText, { color: theme.textPrimary }]}>G</Text>
                        <Text style={[styles.googleTextMain, { color: theme.textPrimary }]}>Google ile Devam Et</Text>
                    </TouchableOpacity>
                </GlassCard>

                <TouchableOpacity onPress={() => { setIsSignUp(!isSignUp); setErrorMessage(''); }} style={styles.toggleWrap}>
                    <Text style={[styles.toggleText, { color: theme.textSecondary }]}>
                        {isSignUp ? 'Zaten hesabın var mı? ' : 'Hesabın yok mu? '}
                        <Text style={{ fontWeight: 'bold' }}>{isSignUp ? 'Giriş Yap' : 'Kayıt Ol'}</Text>
                    </Text>
                </TouchableOpacity>

                {!isSignUp && (
                    <TouchableOpacity onPress={resetPassword}>
                        <Text style={[styles.forgotText, { color: theme.textTertiary }]}>Şifremi Unuttum</Text>
                    </TouchableOpacity>
                )}
            </ScrollView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    scroll: { paddingTop: 60, paddingHorizontal: Theme.spacing.lg, paddingBottom: 40 },
    header: { alignItems: 'center', marginBottom: 32 },
    title: { fontSize: 34, fontWeight: 'bold', marginTop: 8 },
    subtitle: { fontSize: 16, marginTop: 8 },
    formCard: { padding: Theme.spacing.lg },
    inputs: { gap: 16, marginBottom: 16 },
    inputBox: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: 14,
        paddingVertical: 12,
        borderRadius: Theme.radius.small
    },
    input: { flex: 1, marginLeft: 12, fontSize: 16 },
    errorText: { color: 'red', textAlign: 'center', marginBottom: 16, fontSize: 12 },
    submitButton: { height: 50, borderRadius: 12, justifyContent: 'center', alignItems: 'center' },
    submitText: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
    dividerWrap: { flexDirection: 'row', alignItems: 'center', marginVertical: 20 },
    divider: { flex: 1, height: 1 },
    dividerText: { marginHorizontal: 8, fontSize: 12, fontWeight: 'bold' },
    googleButton: { height: 50, borderRadius: 12, borderWidth: 0.5, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: 12 },
    googleText: { fontSize: 18, fontWeight: 'bold' },
    googleTextMain: { fontSize: 14, fontWeight: 'bold' },
    toggleWrap: { marginTop: 32, alignItems: 'center' },
    toggleText: { fontSize: 14 },
    forgotText: { marginTop: 20, textAlign: 'center', fontSize: 14 }
});
