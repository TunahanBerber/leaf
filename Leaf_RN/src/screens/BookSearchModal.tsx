import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, FlatList, TouchableOpacity, ActivityIndicator } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { CoverImageView } from '../components/CoverImageView';
import { Theme, getTheme } from '../components/theme';
import { Search, XCircle, ChevronRight, BookOpen } from 'lucide-react-native';
import { OpenLibraryService } from '../services/OpenLibraryService';
import { BookSearchResult } from '../models';

interface BookSearchModalProps {
    onSelectBook: (book: BookSearchResult) => void;
    onCancel: () => void;
    isDark?: boolean;
}

export const BookSearchModal: React.FC<BookSearchModalProps> = ({ onSelectBook, onCancel, isDark = false }) => {
    const theme = getTheme(isDark);
    const [query, setQuery] = useState('');
    const [results, setResults] = useState<BookSearchResult[]>([]);
    const [isLoading, setIsLoading] = useState(false);

    useEffect(() => {
        const handler = setTimeout(() => {
            if (query.trim()) {
                search(query);
            } else {
                setResults([]);
            }
        }, 500);
        return () => clearTimeout(handler);
    }, [query]);

    const search = async (q: string) => {
        setIsLoading(true);
        const data = await OpenLibraryService.performSearch(q);
        setResults(data);
        setIsLoading(false);
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <TouchableOpacity style={{ flex: 1, alignItems: 'flex-start' }} onPress={onCancel}>
                    <Text style={[styles.cancelText, { color: theme.primary }]}>İptal</Text>
                </TouchableOpacity>
                <View style={{ flex: 2, alignItems: 'center' }}>
                    <Text style={[styles.title, { color: theme.textPrimary }]} numberOfLines={1}>Kitap Ara</Text>
                </View>
                <View style={{ flex: 1 }} />
            </View>

            <View style={[styles.searchBar, { backgroundColor: theme.surfaceSecondary, borderColor: theme.borderPrimary }]}>
                <Search size={18} color={theme.textTertiary} />
                <TextInput
                    style={[styles.input, { color: theme.textPrimary }]}
                    placeholder="Kitap adı veya yazar..."
                    placeholderTextColor={theme.textTertiary}
                    value={query}
                    onChangeText={setQuery}
                    autoFocus
                />
                {query.length > 0 && (
                    <TouchableOpacity onPress={() => setQuery('')}>
                        <XCircle size={18} color={theme.textTertiary} />
                    </TouchableOpacity>
                )}
            </View>

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator size="large" color={theme.primary} />
                </View>
            ) : results.length > 0 ? (
                <FlatList
                    data={results}
                    keyExtractor={item => item.id}
                    contentContainerStyle={styles.listContent}
                    renderItem={({ item }) => (
                        <TouchableOpacity
                            style={[styles.resultItem, { backgroundColor: theme.surfaceSecondary, borderColor: theme.borderSubtle }]}
                            onPress={() => onSelectBook(item)}
                        >
                            <View style={styles.thumbnailWrap}>
                                <CoverImageView coverUrl={item.coverURL || item.highResCoverURL} placeholderIconSize={20} isDark={isDark} />
                            </View>

                            <View style={styles.infoWrap}>
                                <Text style={[styles.itemTitle, { color: theme.textPrimary }]} numberOfLines={2}>{item.title}</Text>
                                {item.authorsText ? <Text style={[styles.itemAuthor, { color: theme.textSecondary }]} numberOfLines={1}>{item.authorsText}</Text> : null}
                                {item.pageCount ? <Text style={[styles.itemPages, { color: theme.textTertiary }]}>{item.pageCount} sayfa</Text> : null}
                            </View>

                            <ChevronRight size={16} color={theme.textTertiary} />
                        </TouchableOpacity>
                    )}
                />
            ) : query.length > 0 ? (
                <View style={styles.center}>
                    <Text style={{ color: theme.textSecondary }}>"{query}" için sonuç bulunamadı</Text>
                </View>
            ) : (
                <View style={styles.center}>
                    <BookOpen size={48} color={'rgba(47, 125, 92, 0.40)'} />
                    <Text style={[styles.emptyHeadline, { color: theme.textPrimary }]}>Kitabını Bul</Text>
                    <Text style={[styles.emptySub, { color: theme.textSecondary }]}>
                        Kitap adı veya yazar ismiyle arama yap, kapak ve bilgileri otomatik dolsun.
                    </Text>
                </View>
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
    cancelText: { fontSize: 16 },
    title: { fontSize: 18, fontWeight: '600' },
    searchBar: {
        flexDirection: 'row',
        alignItems: 'center',
        marginHorizontal: Theme.spacing.md,
        paddingHorizontal: 14,
        paddingVertical: 11,
        borderRadius: Theme.radius.medium,
        borderWidth: 0.5,
    },
    input: {
        flex: 1,
        marginLeft: 10,
        fontSize: 16,
    },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 },
    emptyHeadline: { fontSize: 18, fontWeight: '600', marginTop: 10 },
    emptySub: { fontSize: 14, textAlign: 'center', marginTop: 6 },
    listContent: { padding: Theme.spacing.md },
    resultItem: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 12,
        marginBottom: 10,
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
    },
    thumbnailWrap: { width: 48, height: 68, borderRadius: 6, overflow: 'hidden' },
    infoWrap: { flex: 1, paddingHorizontal: 14 },
    itemTitle: { fontSize: 15, fontWeight: '600', marginBottom: 4 },
    itemAuthor: { fontSize: 13, marginBottom: 2 },
    itemPages: { fontSize: 12 }
});
