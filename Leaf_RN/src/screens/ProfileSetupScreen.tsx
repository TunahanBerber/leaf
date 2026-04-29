import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { GlassCard } from '../components/GlassCard';
import { Theme, getTheme } from '../components/theme';
import { UserPlus, AtSign, Calendar, MessageSquareQuote } from 'lucide-react-native';
import { SocialService } from '../services/SocialService';
import { useAppTheme } from '../components/ThemeContext';

export const ProfileSetupScreen: React.FC<any> = ({ route }) => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);
    
    const [username, setUsername] = useState('');
    const [ageText, setAgeText] = useState('');
    const [bio, setBio] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [errorMsg, setErrorMsg] = useState<string | null>(null);

    const isFormValid = username.trim().length >= 3 && parseInt(ageText, 10) >= 1;

    const handleCreateProfile = async () => {
        const age = parseInt(ageText, 10);
        if (!age) return;

        setIsLoading(true);
        setErrorMsg(null);

        try {
            const success = await SocialService.createProfile(username.trim(), bio.trim(), age);
            
            if (success) {
                if (age < 18) {
                    Alert.alert(
                        "Yaş Sınırı",
                        "Sosyal özellikler 18 yaş ve üzeri kullanıcılara açıktır.\nYine de kitap takibine devam edebilirsin.",
                        [
                            { 
                                text: "Tamam", 
                                onPress: () => {
                                    if (route.params?.onProfileCreated) {
                                        route.params.onProfileCreated();
                                    }
                                } 
                            }
                        ]
                    );
                } else {
                    if (route.params?.onProfileCreated) {
                        route.params.onProfileCreated();
                    }
                }
            }
        } catch (e: any) {
            setErrorMsg(e.message || "Profil oluşturulamadı.");
            setIsLoading(false);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <ScrollView contentContainerStyle={styles.scroll}>
                <View style={styles.header}>
                    <View style={[styles.iconWrap, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                        <UserPlus size={36} color={theme.primary} />
                    </View>
                    <Text style={[styles.title, { color: theme.textPrimary }]}>Profilini Oluştur</Text>
                    <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
                        Kitap dostlarını bulmak için{'\n'}bir profil oluştur.
                    </Text>
                </View>

                <GlassCard isDark={isDark} style={styles.formCard}>
                    <View style={styles.inputs}>
                        
                        {/* Username */}
                        <View style={styles.inputGroup}>
                            <View style={styles.labelRow}>
                                <AtSign size={14} color={theme.textSecondary} />
                                <Text style={[styles.label, { color: theme.textSecondary }]}>Kullanıcı Adı</Text>
                            </View>
                            <TextInput
                                style={[styles.input, { color: theme.textPrimary, backgroundColor: theme.surfaceSecondary, borderColor: theme.borderSubtle }]}
                                placeholder="en az 3 karakter"
                                placeholderTextColor={theme.textTertiary}
                                value={username}
                                onChangeText={setUsername}
                                autoCapitalize="none"
                                autoCorrect={false}
                            />
                        </View>

                        {/* Age */}
                        <View style={styles.inputGroup}>
                            <View style={styles.labelRow}>
                                <Calendar size={14} color={theme.textSecondary} />
                                <Text style={[styles.label, { color: theme.textSecondary }]}>Yaş</Text>
                            </View>
                            <TextInput
                                style={[styles.input, { color: theme.textPrimary, backgroundColor: theme.surfaceSecondary, borderColor: theme.borderSubtle }]}
                                placeholder="Yaşını gir"
                                placeholderTextColor={theme.textTertiary}
                                value={ageText}
                                onChangeText={(text) => setAgeText(text.replace(/[^0-9]/g, ''))}
                                keyboardType="number-pad"
                            />
                        </View>

                        {/* Bio */}
                        <View style={styles.inputGroup}>
                            <View style={styles.labelRow}>
                                <MessageSquareQuote size={14} color={theme.textSecondary} />
                                <Text style={[styles.label, { color: theme.textSecondary }]}>Hakkında (opsiyonel)</Text>
                            </View>
                            <TextInput
                                style={[styles.inputArea, { color: theme.textPrimary, backgroundColor: theme.surfaceSecondary, borderColor: theme.borderSubtle }]}
                                placeholder="Kendini kısaca tanıt..."
                                placeholderTextColor={theme.textTertiary}
                                value={bio}
                                onChangeText={setBio}
                                multiline
                                numberOfLines={4}
                                textAlignVertical="top"
                            />
                        </View>

                    </View>

                    {errorMsg && (
                        <Text style={styles.errorText}>{errorMsg}</Text>
                    )}
                </GlassCard>

                <TouchableOpacity
                    style={[
                        styles.submitButton, 
                        { backgroundColor: isFormValid ? theme.primary : 'rgba(150,150,150,0.3)' }
                    ]}
                    disabled={!isFormValid || isLoading}
                    onPress={handleCreateProfile}
                >
                    {isLoading ? (
                        <ActivityIndicator color="#fff" />
                    ) : (
                        <Text style={styles.submitText}>Profili Oluştur</Text>
                    )}
                </TouchableOpacity>

            </ScrollView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    scroll: { paddingTop: 80, paddingHorizontal: Theme.spacing.md, paddingBottom: 40 },
    header: { alignItems: 'center', marginBottom: 32 },
    iconWrap: {
        width: 80, height: 80, borderRadius: 40,
        justifyContent: 'center', alignItems: 'center',
        marginBottom: 16
    },
    title: { fontSize: 24, fontWeight: 'bold', marginBottom: 8 },
    subtitle: { fontSize: 15, textAlign: 'center', lineHeight: 22 },
    formCard: { padding: Theme.spacing.lg, marginBottom: 24 },
    inputs: { gap: 20 },
    inputGroup: { gap: 8 },
    labelRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
    label: { fontSize: 13, fontWeight: '600' },
    input: {
        height: 50,
        borderRadius: Theme.radius.medium,
        borderWidth: 1,
        paddingHorizontal: 16,
        fontSize: 16
    },
    inputArea: {
        height: 100,
        borderRadius: Theme.radius.medium,
        borderWidth: 1,
        paddingHorizontal: 16,
        paddingVertical: 12,
        fontSize: 16
    },
    errorText: { color: 'red', textAlign: 'center', marginTop: 16, fontSize: 13 },
    submitButton: { 
        height: 54, 
        borderRadius: Theme.radius.large, 
        justifyContent: 'center', 
        alignItems: 'center' 
    },
    submitText: { color: '#fff', fontSize: 17, fontWeight: 'bold' }
});
