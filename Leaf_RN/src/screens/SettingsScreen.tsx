import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Switch, Alert, DeviceEventEmitter } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { LeafTextField } from '../components/LeafComponents';
import { Theme, getTheme } from '../components/theme';
import { AuthService } from '../services/AuthService';
import { SocialService } from '../services/SocialService';
import { ArrowRightCircle } from 'lucide-react-native';

interface SettingsScreenProps {
    onClose: () => void;
    isDark?: boolean;
}

export const SettingsScreen: React.FC<SettingsScreenProps> = ({ onClose, isDark = false }) => {
    const theme = getTheme(isDark);

    const [username, setUsername] = useState('');
    const [bio, setBio] = useState('');
    const [email, setEmail] = useState('');
    const [age, setAge] = useState<number | null>(null);
    const [isSaving, setIsSaving] = useState(false);
    const [socialEnabled, setSocialEnabled] = useState(true);
    const [appTheme, setAppTheme] = useState('system');
    const [themeDropdownOpen, setThemeDropdownOpen] = useState(false);

    useEffect(() => {
        loadProfile();
    }, []);

    const loadProfile = async () => {
        try {
            const session = await AuthService.getSession();
            if (session?.user) setEmail(session.user.email || '');

            const profile = await SocialService.loadCurrentProfile();
            if (profile) {
                setUsername(profile.username || '');
                setBio(profile.bio || '');
                setAge(profile.age || null);
            }

            const storedSocial = await AsyncStorage.getItem('socialFeaturesEnabled');
            if (storedSocial !== null) {
                setSocialEnabled(storedSocial === 'true');
            }
            const storedTheme = await AsyncStorage.getItem('appTheme');
            if (storedTheme) {
                setAppTheme(storedTheme);
            }
        } catch (e) {
            console.error(e);
        }
    };

    const handleSave = async () => {
        if (!username.trim()) return;
        setIsSaving(true);
        try {
            await SocialService.updateProfile(username, bio);
            await AsyncStorage.setItem('socialFeaturesEnabled', socialEnabled ? 'true' : 'false');
            await AsyncStorage.setItem('appTheme', appTheme);
            DeviceEventEmitter.emit('socialSettingsChanged', socialEnabled);
            DeviceEventEmitter.emit('appThemeChanged', appTheme);
            Alert.alert("Kaydedildi", "Profil bilgilerin güncellendi.");
        } catch (e) {
            console.error(e);
        } finally {
            setIsSaving(false);
        }
    };

    const handleSocialToggle = async (value: boolean) => {
        setSocialEnabled(value);
        await AsyncStorage.setItem('socialFeaturesEnabled', value ? 'true' : 'false');
        DeviceEventEmitter.emit('socialSettingsChanged', value);
    };

    const handleThemeChange = async (value: string) => {
        setAppTheme(value);
        setThemeDropdownOpen(false);
        await AsyncStorage.setItem('appTheme', value);
        DeviceEventEmitter.emit('appThemeChanged', value);
    };

    const handleSignOut = async () => {
        try {
            await AuthService.signOut();
            onClose(); // Close modal and let AppNavigator handle auth state
        } catch (e) {
            console.error(e);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <TouchableOpacity onPress={onClose}>
                    <Text style={[styles.headerText, { color: theme.primary }]}>Kapat</Text>
                </TouchableOpacity>
                <Text style={[styles.title, { color: theme.textPrimary }]}>Ayarlar</Text>
                <TouchableOpacity onPress={handleSave} disabled={isSaving || !username.trim()}>
                    {isSaving ? (
                        <ActivityIndicator color={theme.primary} />
                    ) : (
                        <Text style={[styles.headerText, { fontWeight: '600', color: theme.primary }]}>Kaydet</Text>
                    )}
                </TouchableOpacity>
            </View>

            <ScrollView contentContainerStyle={styles.scroll}>
                <Text style={[styles.sectionTitle, { color: theme.textSecondary }]}>Profil</Text>
                <View style={[styles.section, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                    <View style={styles.profileHeader}>
                        <View style={[styles.avatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                            <Text style={[styles.avatarText, { color: theme.primary }]}>{username ? username.substring(0, 1).toUpperCase() : '?'}</Text>
                        </View>
                        <View style={styles.profileMeta}>
                            <Text style={[styles.profileName, { color: theme.textPrimary }]}>{username || 'Kullanıcı'}</Text>
                            <Text style={[styles.profileEmail, { color: theme.textTertiary }]}>{email}</Text>
                        </View>
                    </View>
                    <View style={styles.divider} />
                    <LeafTextField title="Kullanıcı Adı" text={username} onChangeText={setUsername} isDark={isDark} />
                    <LeafTextField title="Biyografi" text={bio} onChangeText={setBio} placeholder="Kendini tanıt..." isDark={isDark} />
                </View>

                <Text style={[styles.sectionTitle, { color: theme.textSecondary }]}>Sohbet</Text>
                <View style={[styles.section, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }]}>
                    <View>
                        <Text style={[styles.rowTitle, { color: theme.textPrimary }]}>Sosyal Özellikler</Text>
                        <Text style={[styles.rowSubtitle, { color: theme.textTertiary }]}>Keşfet ve Mesajlar sekmelerini göster</Text>
                    </View>
                    <Switch value={socialEnabled} onValueChange={handleSocialToggle} trackColor={{ true: theme.primary }} />
                </View>
                <Text style={[styles.footerText, { color: theme.textTertiary }]}>Kapatırsanız Keşfet ve Mesajlar sekmeleri gizlenir, sohbetleriniz silinmez.</Text>

                <Text style={[styles.sectionTitle, { color: theme.textSecondary }]}>Görünüm</Text>
                <TouchableOpacity
                    style={[styles.section, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }]}
                    onPress={() => setThemeDropdownOpen(!themeDropdownOpen)}
                    activeOpacity={0.7}
                >
                    <Text style={[styles.rowTitle, { color: theme.textPrimary }]}>Tema</Text>
                    <Text style={{ color: theme.primary, fontWeight: '500', fontSize: 15 }}>
                        {appTheme === 'system' ? 'Sistem' : appTheme === 'light' ? 'Açık' : 'Koyu'} ▾
                    </Text>
                </TouchableOpacity>
                {themeDropdownOpen && (
                    <View style={[styles.dropdown, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                        {(['system', 'light', 'dark'] as const).map((opt) => (
                            <TouchableOpacity
                                key={opt}
                                style={[styles.dropdownItem, opt !== 'dark' && { borderBottomWidth: 0.5, borderBottomColor: theme.borderSubtle }]}
                                onPress={() => handleThemeChange(opt)}
                            >
                                <Text style={[styles.rowTitle, { color: appTheme === opt ? theme.primary : theme.textPrimary, fontWeight: appTheme === opt ? '600' : '400' }]}>
                                    {opt === 'system' ? 'Sistem' : opt === 'light' ? 'Açık' : 'Koyu'}
                                </Text>
                                {appTheme === opt && <Text style={{ color: theme.primary, fontSize: 16 }}>✓</Text>}
                            </TouchableOpacity>
                        ))}
                    </View>
                )}

                <Text style={[styles.sectionTitle, { color: theme.textSecondary }]}>Hesap</Text>
                <TouchableOpacity style={[styles.section, styles.dangerRow, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]} onPress={handleSignOut}>
                    <Text style={styles.dangerText}>Çıkış Yap</Text>
                    <ArrowRightCircle color="#FF3B30" size={20} />
                </TouchableOpacity>
            </ScrollView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingHorizontal: Theme.spacing.md,
        paddingVertical: Theme.spacing.md,
    },
    headerText: { fontSize: 16 },
    title: { fontSize: 18, fontWeight: 'bold' },
    scroll: { padding: Theme.spacing.md, paddingBottom: Theme.spacing.xxxl },
    sectionTitle: {
        fontSize: 13,
        fontWeight: '500',
        textTransform: 'uppercase',
        marginBottom: 8,
        marginLeft: 8,
        marginTop: 16,
    },
    section: {
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
        padding: Theme.spacing.md,
        marginBottom: Theme.spacing.md,
    },
    profileHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: Theme.spacing.md },
    avatar: { width: 56, height: 56, borderRadius: 28, justifyContent: 'center', alignItems: 'center', marginRight: Theme.spacing.md },
    avatarText: { fontSize: 24, fontWeight: 'bold' },
    profileMeta: { flex: 1 },
    profileName: { fontSize: 18, fontWeight: 'bold' },
    profileEmail: { fontSize: 13 },
    divider: { height: 1, backgroundColor: '#0000001A', marginBottom: Theme.spacing.md },
    rowTitle: { fontSize: 16, fontWeight: '500', marginBottom: 2 },
    rowSubtitle: { fontSize: 12 },
    dangerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
    dangerText: { color: '#FF3B30', fontSize: 16, fontWeight: '500' },
    footerText: { fontSize: 12, marginBottom: 16, marginLeft: 8, marginTop: 4 },
    themeRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 14, paddingHorizontal: 4 },
    dropdown: {
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
        marginTop: -8,
        marginBottom: Theme.spacing.md,
        overflow: 'hidden',
    },
    dropdownItem: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingVertical: 14,
        paddingHorizontal: Theme.spacing.md,
    },
});
