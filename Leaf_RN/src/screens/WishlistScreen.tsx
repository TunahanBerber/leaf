import React, { useState, useCallback } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { LibraryGridScreen } from './LibraryGridScreen';
import { AddBookScreen } from './AddBookScreen';
import { BookRecommendationModal } from './BookRecommendationModal';
import { Theme, getTheme } from '../components/theme';
import { Book } from '../models';
import { BookStoreService } from '../services/BookStoreService';
import { Plus, Sparkles, Bookmark } from 'lucide-react-native';
import { useAppTheme } from '../components/ThemeContext';

export const WishlistScreen: React.FC<any> = ({ navigation }) => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);
    const [books, setBooks] = useState<Book[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [showAddBook, setShowAddBook] = useState(false);
    const [showRecommendation, setShowRecommendation] = useState(false);

    useFocusEffect(
        useCallback(() => {
            loadWishlist();
        }, [])
    );

    const loadWishlist = async () => {
        setIsLoading(true);
        try {
            const allBooks = await BookStoreService.fetchAllBooks();
            setBooks(allBooks.filter((x: Book) => x.isWishlist));
        } catch (e) {
            console.error(e);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            {/* Header */}
            <View style={styles.header}>
                <Text style={[styles.title, { color: theme.textPrimary }]}>İstek Listesi</Text>
                {books.length > 0 && (
                    <TouchableOpacity onPress={() => setShowAddBook(true)}>
                        <Plus size={24} color={theme.primary} />
                    </TouchableOpacity>
                )}
            </View>

            <LibraryGridScreen
                books={books}
                isLoading={isLoading}
                onBookPress={(book) => navigation.navigate('BookDetail', { book })}
                onAddBook={() => setShowAddBook(true)}
                isDark={isDark}
                emptyIcon={<Bookmark size={32} color={theme.primary} strokeWidth={1.5} />}
                emptyTitle="İstek Listeniz Boş"
                emptyMessage={'Almak istediğiniz, okumayı hayal ettiğiniz\nkitapları buraya ekleyebilirsiniz.'}
                emptyButtonText="İstek Ekle"
            />

            {/* FAB — öneri butonu */}
            <TouchableOpacity
                style={[styles.fab, { backgroundColor: theme.primary }]}
                onPress={() => setShowRecommendation(true)}
                activeOpacity={0.85}
            >
                <Sparkles size={20} color="#FFF" />
            </TouchableOpacity>

            <Modal visible={showAddBook} animationType="slide" presentationStyle="pageSheet">
                <AddBookScreen
                    onCancel={() => setShowAddBook(false)}
                    onSave={async (params) => {
                        try {
                            await BookStoreService.addBook({
                                title: params.title,
                                author: params.author,
                                totalPages: params.totalPages || 100,
                                coverImageUrl: params.coverImageUrl,
                                isWishlist: true,
                            });
                            await loadWishlist();
                        } catch (e) {
                            console.error(e);
                        } finally {
                            setShowAddBook(false);
                        }
                    }}
                    isDark={isDark}
                />
            </Modal>

            <Modal visible={showRecommendation} animationType="slide" presentationStyle="pageSheet">
                <BookRecommendationModal
                    onClose={() => { setShowRecommendation(false); loadWishlist(); }}
                    userBookTitles={books.map(b => b.title)}
                    isDark={isDark}
                />
            </Modal>
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: Theme.spacing.md,
        paddingTop: 60,
        paddingBottom: Theme.spacing.sm,
    },
    title: { fontSize: 28, fontWeight: 'bold' },
    fab: {
        position: 'absolute',
        bottom: 90,
        right: Theme.spacing.md,
        width: 44,
        height: 44,
        borderRadius: 22,
        justifyContent: 'center',
        alignItems: 'center',
        boxShadow: '0px 4px 8px rgba(47, 125, 92, 0.35)',
        elevation: 6,
    } as any,
});
