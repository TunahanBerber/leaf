import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, ScrollView, ActivityIndicator, TouchableOpacity } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { CoverImageView } from '../components/CoverImageView';
import { BookStoreService } from '../services/BookStoreService';
import { BookCatalogItem } from '../models';
import { Theme, getTheme } from '../components/theme';
import { Bookmark, RefreshCcw, CheckCircle } from 'lucide-react-native';

interface BookRecommendationModalProps {
    onClose: () => void;
    userBookTitles: string[];
    isDark?: boolean;
}

export const BookRecommendationModal: React.FC<BookRecommendationModalProps> = ({ onClose, userBookTitles, isDark = false }) => {
    const theme = getTheme(isDark);
    const [item, setItem] = useState<BookCatalogItem | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [seenTitles, setSeenTitles] = useState<Set<string>>(new Set());
    const [isAdding, setIsAdding] = useState(false);
    const [addedSuccessfully, setAddedSuccessfully] = useState(false);

    const loadRecommendation = async () => {
        setIsLoading(true);
        setAddedSuccessfully(false);
        setItem(null);

        const rec = await BookStoreService.fetchRecommendation(seenTitles, userBookTitles);
        if (rec) {
            setItem(rec);
            setSeenTitles(prev => new Set(prev).add(rec.title.toLowerCase()));
        }
        setIsLoading(false);
    };

    useEffect(() => {
        loadRecommendation();
    }, []);

    const addToWishlist = async () => {
        if (!item) return;
        setIsAdding(true);
        await BookStoreService.addBook({
            title: item.title,
            author: item.author,
            totalPages: item.pageCount || 0,
            isWishlist: true,
            fromCatalog: false,
        });
        // Record increment omitted here since BookStoreService does it if it was openlibrary but here it's already catalog
        await BookStoreService['incrementCatalogCount']?.(item.title, item.author);

        setIsAdding(false);
        setAddedSuccessfully(true);

        setTimeout(() => {
            onClose();
        }, 1200);
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <Text style={[styles.title, { color: theme.textPrimary }]}>Kitap Önerisi</Text>
                <TouchableOpacity onPress={onClose}>
                    <Text style={[styles.closeText, { color: theme.primary }]}>Kapat</Text>
                </TouchableOpacity>
            </View>

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator size="large" color={theme.primary} />
                    <Text style={[styles.loadingText, { color: theme.textTertiary }]}>Öneri aranıyor...</Text>
                </View>
            ) : !item ? (
                <View style={styles.center}>
                    <Text style={[{ color: theme.textPrimary, fontSize: 18, fontWeight: '600' }]}>Katalog Boş</Text>
                </View>
            ) : (
                <ScrollView contentContainerStyle={styles.scrollContent}>
                    <View style={styles.coverWrapper}>
                        <CoverImageView coverUrl={item.coverUrl} isDark={isDark} />
                    </View>

                    <View style={[styles.infoCard, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                        <Text style={[styles.bookTitle, { color: theme.textPrimary }]}>{item.title}</Text>
                        <Text style={[styles.bookAuthor, { color: theme.textSecondary }]}>{item.author}</Text>
                        {item.pageCount ? <Text style={[styles.bookPages, { color: theme.textTertiary }]}>{item.pageCount} sayfa</Text> : null}
                    </View>

                    <View style={styles.actions}>
                        <TouchableOpacity
                            style={[
                                styles.primaryBtn,
                                { backgroundColor: addedSuccessfully ? '#22c55e' : theme.primary } // Green if added
                            ]}
                            disabled={isAdding || addedSuccessfully}
                            onPress={addToWishlist}
                        >
                            {isAdding ? (
                                <ActivityIndicator color="#fff" />
                            ) : addedSuccessfully ? (
                                <>
                                    <CheckCircle color="#fff" size={20} />
                                    <Text style={styles.btnText}>Eklendi!</Text>
                                </>
                            ) : (
                                <>
                                    <Bookmark color="#fff" size={20} />
                                    <Text style={styles.btnText}>İstek Listesine Ekle</Text>
                                </>
                            )}
                        </TouchableOpacity>

                        <TouchableOpacity
                            style={[
                                styles.secondaryBtn,
                                { backgroundColor: theme.surfacePrimary, borderColor: 'rgba(47, 125, 92, 0.40)' }
                            ]}
                            disabled={isAdding || isLoading}
                            onPress={loadRecommendation}
                        >
                            <RefreshCcw color={theme.primary} size={20} />
                            <Text style={[styles.btnText, { color: theme.primary }]}>Farklı Öneri</Text>
                        </TouchableOpacity>
                    </View>
                </ScrollView>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: Theme.spacing.md,
    },
    title: { fontSize: 18, fontWeight: '600', flex: 1, textAlign: 'center', marginLeft: 40 },
    closeText: { fontSize: 16, width: 50 },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
    loadingText: { marginTop: 10, fontSize: 14 },
    scrollContent: { padding: Theme.spacing.md, alignItems: 'center', paddingBottom: Theme.spacing.xxxl },
    coverWrapper: {
        width: 160,
        height: 240,
        borderRadius: Theme.radius.large,
        overflow: 'hidden',
        shadowColor: '#000',
        shadowOpacity: 0.18,
        shadowRadius: 16,
        shadowOffset: { width: 0, height: 8 },
        elevation: 8,
        marginBottom: Theme.spacing.xl,
    },
    infoCard: {
        width: '100%',
        padding: Theme.spacing.lg,
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
        alignItems: 'center',
        marginBottom: Theme.spacing.xl,
    },
    bookTitle: { fontSize: 20, fontWeight: '600', textAlign: 'center', marginBottom: 4 },
    bookAuthor: { fontSize: 15, marginBottom: 8 },
    bookPages: { fontSize: 12 },
    actions: { width: '100%', gap: 12 },
    primaryBtn: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 14,
        borderRadius: Theme.radius.medium,
        gap: 8,
    },
    btnText: { fontSize: 16, fontWeight: '600', color: '#fff' },
    secondaryBtn: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 14,
        borderRadius: Theme.radius.medium,
        borderWidth: 1,
        gap: 8,
    }
});
