import React from 'react';
import { View, ScrollView, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { GlassCard } from '../components/GlassCard';
import { BookCardView } from '../components/BookCardView';
import { Theme, getTheme } from '../components/theme';
import { Book } from '../models';
import { BookOpen } from 'lucide-react-native';

interface LibraryGridScreenProps {
    books: Book[];
    isLoading: boolean;
    onBookPress: (book: Book) => void;
    onAddBook?: () => void;
    isDark?: boolean;
    emptyIcon?: React.ReactNode;
    emptyTitle?: string;
    emptyMessage?: string;
    emptyButtonText?: string;
}

export const LibraryGridScreen: React.FC<LibraryGridScreenProps> = ({
    books,
    isLoading,
    onBookPress,
    onAddBook,
    isDark = false,
    emptyIcon,
    emptyTitle = 'Kitaplığınız şu anda boş',
    emptyMessage = 'Kitaplığınız boş — ve bu da iyi.\nİlk kitabınızı ekleyerek onu oluşturun.',
    emptyButtonText = 'Kitap Ekle',
}) => {
    const theme = getTheme(isDark);

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator size="large" color={theme.primary} />
                </View>
            ) : books.length === 0 ? (
                <View style={styles.center}>
                    {/* EmptyStateView — Swift parity */}
                    <View style={styles.emptyWrapper}>
                        <GlassCard isDark={isDark} style={{ marginBottom: Theme.spacing.xl }}>
                            <View style={styles.iconBox}>
                                {emptyIcon || <BookOpen size={32} color={theme.primary} strokeWidth={1.5} />}
                            </View>
                        </GlassCard>

                        <Text style={[styles.emptyTitle, { color: theme.textPrimary }]}>{emptyTitle}</Text>
                        <Text style={[styles.emptyMessage, { color: theme.textSecondary }]}>{emptyMessage}</Text>

                        {onAddBook && (
                            <TouchableOpacity
                                onPress={onAddBook}
                                style={[styles.addButton, { backgroundColor: theme.primary }]}
                                activeOpacity={0.85}
                            >
                                <Text style={styles.addButtonText}>{emptyButtonText}</Text>
                            </TouchableOpacity>
                        )}
                    </View>
                </View>
            ) : (
                <ScrollView
                    contentContainerStyle={styles.scrollContent}
                    showsVerticalScrollIndicator={false}
                >
                    <View style={styles.grid}>
                        {books.map((book) => (
                            <View key={book.id} style={styles.gridItem}>
                                <TouchableOpacity onPress={() => onBookPress(book)} activeOpacity={0.9}>
                                    <BookCardView book={book} isDark={isDark} />
                                </TouchableOpacity>
                            </View>
                        ))}
                    </View>
                </ScrollView>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    center: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    emptyWrapper: {
        alignItems: 'center',
        paddingHorizontal: Theme.spacing.xl,
        maxWidth: 480,
    },
    iconBox: {
        width: 88,
        height: 88,
        justifyContent: 'center',
        alignItems: 'center',
    },
    emptyTitle: {
        fontSize: 20,
        fontWeight: '600',
        marginBottom: Theme.spacing.xs,
        letterSpacing: -0.3,
    },
    emptyMessage: {
        fontSize: 15,
        textAlign: 'center',
        lineHeight: 22,
        marginBottom: Theme.spacing.xxl,
    },
    addButton: {
        paddingHorizontal: Theme.spacing.lg,
        height: 44,
        borderRadius: 22,
        justifyContent: 'center',
        alignItems: 'center',
        boxShadow: '0px 4px 12px rgba(47, 125, 92, 0.25)',
    } as any,
    addButtonText: {
        color: '#FFF',
        fontSize: 13,
        fontWeight: '600',
    },
    scrollContent: {
        paddingHorizontal: Theme.spacing.md,
        paddingTop: Theme.spacing.xs,
        paddingBottom: Theme.spacing.xxxl,
    },
    grid: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        justifyContent: 'space-between',
    },
    gridItem: {
        width: '48%',
        marginBottom: Theme.spacing.lg,
    }
});
