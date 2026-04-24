import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { getTheme, Theme } from '../components/theme';
import { UserProfile } from '../models';
import { SocialService } from '../services/SocialService';
import { supabase } from '../services/supabase';
import { Book, Clock, Send, MessageCircle, ArrowLeft } from 'lucide-react-native';
import { useAppTheme } from '../components/ThemeContext';

export const UserProfileScreen: React.FC<any> = ({ route, navigation }) => {
    const { profile } = route.params as { profile: UserProfile };
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);

    const [requestStatus, setRequestStatus] = useState<string | null>(null);
    const [existingConvId, setExistingConvId] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState(false);

    useEffect(() => {
        loadStatus();
    }, []);

    const loadStatus = async () => {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return;

        // Check conversations
        const { data: conv } = await supabase
            .from('conversations')
            .select('id')
            .or(`and(user_a_id.eq.${userId},user_b_id.eq.${profile.id}),and(user_a_id.eq.${profile.id},user_b_id.eq.${userId})`)
            .limit(1)
            .single();

        if (conv) {
            setExistingConvId(conv.id);
            setRequestStatus('accepted');
            return;
        }

        // Check requests
        const { data: req } = await supabase
            .from('conversation_requests')
            .select('status')
            .eq('sender_id', userId)
            .eq('receiver_id', profile.id)
            .limit(1)
            .single();

        if (req) {
            setRequestStatus(req.status);
        }
    };

    const handleAction = async () => {
        if (requestStatus === 'accepted' && existingConvId) {
            navigation.navigate('Conversation', { conversationId: existingConvId, otherUsername: profile.username });
        } else if (!requestStatus) {
            setIsLoading(true);
            try {
                const success = await SocialService.sendConversationRequest(profile.id);
                if (success) {
                    setRequestStatus('pending');
                    Alert.alert('İstek Gönderildi', `${profile.username} isteği kabul ederse sohbet başlayacak.`);
                }
            } catch (e) {
                console.error(e);
            } finally {
                setIsLoading(false);
            }
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.topHeader}>
                <TouchableOpacity onPress={() => navigation.goBack()} style={{ padding: 10 }}>
                    <ArrowLeft color={theme.textPrimary} size={24} />
                </TouchableOpacity>
                <Text style={[styles.headerTitle, { color: theme.textPrimary }]}>{profile.username}</Text>
                <View style={{ width: 44 }} />
            </View>

            <ScrollView contentContainerStyle={styles.content}>
                <View style={[styles.profileHeader, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                    <View style={[styles.avatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                        <Text style={[styles.avatarText, { color: theme.primary }]}>
                            {profile.username.charAt(0).toUpperCase()}
                        </Text>
                    </View>

                    <View style={styles.nameRow}>
                        <Text style={[styles.name, { color: theme.textPrimary }]}>{profile.username}</Text>
                        {profile.age ? <Text style={[styles.age, { color: theme.textTertiary }]}>{profile.age}</Text> : null}
                    </View>

                    {profile.bio ? (
                        <Text style={[styles.bio, { color: theme.textSecondary }]}>{profile.bio}</Text>
                    ) : null}
                </View>

                {profile.commonBookTitles && profile.commonBookTitles.length > 0 && (
                    <View style={styles.section}>
                        <Text style={[styles.sectionTitle, { color: theme.textPrimary }]}>Ortak Kitaplar</Text>
                        {profile.commonBookTitles.map((title, idx) => (
                            <View key={idx} style={[styles.bookRow, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                                <Book color={theme.primary} size={16} />
                                <Text style={[styles.bookTitle, { color: theme.textPrimary }]}>{title}</Text>
                            </View>
                        ))}
                    </View>
                )}

                <TouchableOpacity
                    style={[styles.actionBtn, {
                        backgroundColor: requestStatus === 'pending' ? theme.textTertiary + '80' : theme.primary
                    }]}
                    onPress={handleAction}
                    disabled={isLoading || requestStatus === 'pending'}
                >
                    {isLoading ? (
                        <ActivityIndicator color="#FFF" />
                    ) : (
                        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                            {requestStatus === 'accepted' ? <MessageCircle color="#FFF" size={20} /> :
                                requestStatus === 'pending' ? <Clock color="#FFF" size={20} /> :
                                    <Send color="#FFF" size={20} />}
                            <Text style={styles.actionText}>
                                {requestStatus === 'accepted' ? 'Sohbeti Aç' :
                                    requestStatus === 'pending' ? 'İstek Gönderildi' :
                                        'Sohbet İsteği Gönder'}
                            </Text>
                        </View>
                    )}
                </TouchableOpacity>
            </ScrollView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    topHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingTop: 60, paddingHorizontal: 10, paddingBottom: 10 },
    headerTitle: { fontSize: 18, fontWeight: 'bold' },
    content: { padding: Theme.spacing.md, paddingBottom: Theme.spacing.xxl, gap: Theme.spacing.lg },
    profileHeader: {
        alignItems: 'center',
        padding: Theme.spacing.xl,
        borderRadius: Theme.radius.xlarge,
        borderWidth: 0.5,
    },
    avatar: { width: 96, height: 96, borderRadius: 48, justifyContent: 'center', alignItems: 'center', marginBottom: Theme.spacing.md },
    avatarText: { fontSize: 40, fontWeight: 'bold' },
    nameRow: { flexDirection: 'row', gap: 8, alignItems: 'center', marginBottom: 4 },
    name: { fontSize: 24, fontWeight: 'bold' },
    age: { fontSize: 20 },
    bio: { fontSize: 16, textAlign: 'center', marginTop: 4 },
    section: { gap: Theme.spacing.sm },
    sectionTitle: { fontSize: 18, fontWeight: '600', marginLeft: 4 },
    bookRow: { flexDirection: 'row', gap: 12, alignItems: 'center', padding: Theme.spacing.md, borderRadius: Theme.radius.medium, borderWidth: 0.5 },
    bookTitle: { fontSize: 16 },
    actionBtn: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', padding: Theme.spacing.md, borderRadius: Theme.radius.large },
    actionText: { color: '#FFF', fontWeight: '600', fontSize: 16 }
});
