import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Modal } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { LeafTextField, PressableScale } from '../components/LeafComponents';
import { Theme, getTheme } from '../components/theme';
import { Search, Camera } from 'lucide-react-native';
import { CoverImageView } from '../components/CoverImageView';
import * as ImagePicker from 'expo-image-picker';
import { Book, BookSearchResult } from '../models';
import { BookSearchModal } from './BookSearchModal';

interface AddBookScreenProps {
    bookToEdit?: Book;
    isWishlist?: boolean;
    onSave: (params: any) => Promise<void>;
    onCancel: () => void;
    isDark?: boolean;
}

export const AddBookScreen: React.FC<AddBookScreenProps> = ({
    bookToEdit,
    isWishlist = false,
    onSave,
    onCancel,
    isDark = false
}) => {
    const theme = getTheme(isDark);

    const [title, setTitle] = useState(bookToEdit?.title || '');
    const [author, setAuthor] = useState(bookToEdit?.author || '');
    const [totalPages, setTotalPages] = useState(bookToEdit?.totalPages ? String(bookToEdit.totalPages) : '');
    const [coverUrl, setCoverUrl] = useState(bookToEdit?.coverImageUrl || '');
    const [isSaving, setIsSaving] = useState(false);
    const [showSearch, setShowSearch] = useState(false);

    const handlePopulate = (book: BookSearchResult) => {
        setTitle(book.title || '');
        setAuthor(book.authors ? book.authors.join(', ') : '');
        setTotalPages(book.pageCount ? String(book.pageCount) : '');
        setCoverUrl(book.highResCoverURL || book.coverURL || '');
        setShowSearch(false);
    };

    const pickImage = async () => {
        let result = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ['images'],
            allowsEditing: true,
            aspect: [2, 3],
            quality: 0.8,
        });

        if (!result.canceled) {
            setCoverUrl(result.assets[0].uri);
        }
    };

    const handleSave = async () => {
        setIsSaving(true);
        await onSave({
            title,
            author,
            totalPages: parseInt(totalPages) || 0,
            coverImageUrl: coverUrl || null
        });
        setIsSaving(false);
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <TouchableOpacity style={{ flex: 1, alignItems: 'flex-start' }} onPress={onCancel}>
                    <Text style={[styles.headerText, { color: theme.textSecondary }]}>İptal</Text>
                </TouchableOpacity>
                <View style={{ flex: 2, alignItems: 'center' }}>
                    <Text style={[styles.title, { color: theme.textPrimary }]} numberOfLines={1}>{bookToEdit ? 'Kitabı Düzenle' : 'Kitap Ekle'}</Text>
                </View>
                <TouchableOpacity style={{ flex: 1, alignItems: 'flex-end' }} onPress={handleSave} disabled={isSaving || !title.trim()}>
                    {isSaving ? (
                        <ActivityIndicator color={theme.primary} />
                    ) : (
                        <Text style={[styles.headerText, styles.saveRaw, { color: !title.trim() ? theme.textTertiary : theme.primary }]}>Kaydet</Text>
                    )}
                </TouchableOpacity>
            </View>

            <ScrollView contentContainerStyle={styles.scrollContent}>
                <View style={styles.coverPickerContainer}>
                    <TouchableOpacity onPress={pickImage} activeOpacity={0.8}>
                        {coverUrl ? (
                            <View style={styles.coverPickerFilled}>
                                <CoverImageView coverUrl={coverUrl} isDark={isDark} />
                                <View style={[styles.editCoverOverlay, { backgroundColor: 'rgba(0,0,0,0.5)' }]}>
                                    <Camera color="#FFF" size={24} />
                                </View>
                            </View>
                        ) : (
                            <View style={[styles.coverPicker, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderPrimary }]}>
                                <Camera color={theme.textTertiary} size={32} style={{ marginBottom: 8 }} />
                                <Text style={{ color: theme.textTertiary }}>Kapak Ekle</Text>
                            </View>
                        )}
                    </TouchableOpacity>
                </View>

                <PressableScale onPress={() => setShowSearch(true)}>
                    <View style={[styles.searchButton, { backgroundColor: 'rgba(47, 125, 92, 0.10)' }]}>
                        <Search size={20} color={theme.primary} />
                        <Text style={[styles.searchText, { color: theme.primary }]}>İnternetten Kitap Ara</Text>
                    </View>
                </PressableScale>

                <View style={styles.formContainer}>
                    <LeafTextField
                        title="Kitap Adı"
                        text={title}
                        onChangeText={setTitle}
                        placeholder="Kitabın adını yazın"
                        isDark={isDark}
                    />
                    <LeafTextField
                        title="Yazar"
                        text={author}
                        onChangeText={setAuthor}
                        placeholder="Yazarın adını yazın"
                        isDark={isDark}
                    />
                    <LeafTextField
                        title="Sayfa Sayısı"
                        text={totalPages}
                        onChangeText={setTotalPages}
                        placeholder="Sayfa sayısını girin"
                        keyboardType="number-pad"
                        isDark={isDark}
                    />
                </View>
            </ScrollView>

            <Modal visible={showSearch} animationType="slide" presentationStyle="pageSheet">
                <BookSearchModal
                    onCancel={() => setShowSearch(false)}
                    onSelectBook={handlePopulate}
                    isDark={isDark}
                />
            </Modal>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        paddingHorizontal: Theme.spacing.md,
        paddingVertical: Theme.spacing.md,
        alignItems: 'center'
    },
    title: {
        fontSize: 18,
        fontWeight: '600'
    },
    headerText: {
        fontSize: 16,
    },
    saveRaw: {
        fontWeight: '600',
    },
    scrollContent: {
        paddingBottom: Theme.spacing.xxxl,
    },
    coverPickerContainer: {
        paddingTop: Theme.spacing.md,
        alignItems: 'center',
        marginBottom: Theme.spacing.lg,
    },
    coverPicker: {
        width: 140,
        height: 200,
        borderRadius: Theme.radius.medium,
        justifyContent: 'center',
        alignItems: 'center',
        borderWidth: 1,
        borderStyle: 'dashed',
    },
    coverPickerFilled: {
        width: 140,
        height: 200,
        borderRadius: Theme.radius.medium,
        overflow: 'hidden',
        boxShadow: '0px 4px 12px rgba(0,0,0,0.1)',
        elevation: 4,
    } as any,
    editCoverOverlay: {
        ...StyleSheet.absoluteFillObject,
        justifyContent: 'center',
        alignItems: 'center',
    },
    searchButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 14,
        marginHorizontal: Theme.spacing.md,
        borderRadius: Theme.radius.medium,
        marginBottom: Theme.spacing.lg,
    },
    searchText: {
        fontWeight: '500',
        fontSize: 16,
        marginLeft: Theme.spacing.xs,
    },
    formContainer: {
        paddingHorizontal: Theme.spacing.md,
    }
});
