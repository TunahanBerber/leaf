import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { Theme, getTheme } from '../components/theme';
import { UserProfile } from '../models';
import { SocialService } from '../services/SocialService';
import { Users, ChevronRight } from 'lucide-react-native';
import { useAppTheme } from '../components/ThemeContext';

interface DiscoverScreenProps {
    onUserSelect?: (user: UserProfile) => void;
    isDark?: boolean;
}

export const DiscoverScreen: React.FC<any> = ({ navigation }) => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);
    const [users, setUsers] = useState<UserProfile[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        loadUsers();
    }, []);

    const loadUsers = async () => {
        setIsLoading(true);
        try {
            const data = await SocialService.discoverUsers();
            setUsers(data);
        } catch {
            setUsers([]);
        }
        setIsLoading(false);
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <Text style={[styles.title, { color: theme.textPrimary }]}>Keşfet</Text>
            </View>

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator color={theme.primary} size="large" />
                </View>
            ) : users.length === 0 ? (
                <View style={styles.center}>
                    <Users size={48} color={theme.textTertiary} />
                    <Text style={[styles.emptyTitle, { color: theme.textPrimary }]}>Henüz eşleşme yok</Text>
                    <Text style={[styles.emptySubtitle, { color: theme.textSecondary }]}>
                        Kütüphanene kitap ekle,{'\n'}onu okuyan kişilerle buluş.
                    </Text>
                </View>
            ) : (
                <ScrollView contentContainerStyle={styles.list}>
                    {users.map(user => (
                        <TouchableOpacity
                            key={user.id}
                            style={[styles.card, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}
                            onPress={() => navigation.navigate('UserProfile', { profile: user })}
                            activeOpacity={0.8}
                        >
                            <View style={[styles.avatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                                <Text style={[styles.avatarText, { color: theme.primary }]}>
                                    {user.username.charAt(0).toUpperCase()}
                                </Text>
                            </View>

                            <View style={styles.info}>
                                <View style={styles.nameRow}>
                                    <Text style={[styles.name, { color: theme.textPrimary }]}>{user.username}</Text>
                                    {user.age ? <Text style={[styles.age, { color: theme.textTertiary }]}> · {user.age}</Text> : null}
                                </View>

                                {user.commonBookTitles && user.commonBookTitles.length > 0 && (
                                    <Text style={[styles.books, { color: theme.primary }]} numberOfLines={1}>
                                        {user.commonBookTitles.slice(0, 2).join(', ')}
                                    </Text>
                                )}

                                {user.bio ? (
                                    <Text style={[styles.bio, { color: theme.textSecondary }]} numberOfLines={1}>{user.bio}</Text>
                                ) : null}
                            </View>

                            <ChevronRight color={theme.textTertiary} size={16} />
                        </TouchableOpacity>
                    ))}
                </ScrollView>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: { paddingTop: 60, paddingHorizontal: Theme.spacing.md, paddingBottom: Theme.spacing.sm },
    title: { fontSize: 28, fontWeight: 'bold' },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: Theme.spacing.xxl },
    emptyTitle: { fontSize: 18, fontWeight: '600', marginTop: 16 },
    emptySubtitle: { fontSize: 14, textAlign: 'center', marginTop: 8 },
    list: { paddingHorizontal: Theme.spacing.md, paddingBottom: Theme.spacing.xxl },
    card: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: Theme.spacing.md,
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
        marginBottom: Theme.spacing.sm
    },
    avatar: { width: 56, height: 56, borderRadius: 28, justifyContent: 'center', alignItems: 'center' },
    avatarText: { fontSize: 20, fontWeight: 'bold' },
    info: { flex: 1, marginLeft: Theme.spacing.md, gap: 4 },
    nameRow: { flexDirection: 'row', alignItems: 'center' },
    name: { fontSize: 16, fontWeight: 'bold' },
    age: { fontSize: 14 },
    books: { fontSize: 12 },
    bio: { fontSize: 12 }
});
