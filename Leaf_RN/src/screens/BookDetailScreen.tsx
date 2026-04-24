import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert, Modal, TextInput } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { CoverImageView } from '../components/CoverImageView';
import { GlassCard } from '../components/GlassCard';
import { Theme, getTheme } from '../components/theme';
import { ArrowLeft, Edit2, Trash2, PlusCircle, Bookmark } from 'lucide-react-native';
import { Book, BookNote } from '../models';
import { BookStoreService } from '../services/BookStoreService';
import { AddBookScreen } from './AddBookScreen';
import { AddNoteScreen } from './AddNoteScreen';
import { useAppTheme } from '../components/ThemeContext';

export const BookDetailScreen: React.FC<any> = ({ route, navigation }) => {
    const { book } = route.params as { book: Book };
    const [bookLocal, setBookLocal] = useState<Book>(book);
    const [notes, setNotes] = useState<BookNote[]>([]);
    const [isLoading, setIsLoading] = useState(false);

    // Modals
    const [showAddNote, setShowAddNote] = useState(false);
    const [showEditBook, setShowEditBook] = useState(false);
    const [showEditPage, setShowEditPage] = useState(false);
    const [pageText, setPageText] = useState(String(bookLocal.currentPage));

    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);

    useEffect(() => {
        loadNotes();
    }, [book.id]);

    const loadNotes = async () => {
        setIsLoading(true);
        try {
            const data = await BookStoreService.fetchNotes(book.id);
            setNotes(data);
        } catch (e) {
            console.error(e);
        } finally {
            setIsLoading(false);
        }
    };

    const handleDelete = async () => {
        // Simple confirmation before deleting
        try {
            setIsLoading(true);
            await BookStoreService.deleteBook(bookLocal.id);
            navigation.goBack();
        } catch (e) {
            console.error('Delete error', e);
            setIsLoading(false);
        }
    };

    const handleUpdatePage = async () => {
        const p = parseInt(pageText) || 0;
        try {
            setIsLoading(true);
            const updated = await BookStoreService.updateBook({ ...bookLocal, currentPage: Math.min(p, bookLocal.totalPages) });
            setBookLocal(updated);
            setShowEditPage(false);
        } catch (e) {
            console.error(e);
        } finally {
            setIsLoading(false);
        }
    };

    const handleDeleteNote = async (noteId: string) => {
        try {
            await BookStoreService.deleteNote(noteId);
            await loadNotes();
        } catch (e) {
            console.error(e);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <TouchableOpacity onPress={() => navigation.goBack()} style={styles.iconButton}>
                    <ArrowLeft size={24} color={theme.textPrimary} />
                </TouchableOpacity>
                <View style={styles.actions}>
                    <TouchableOpacity onPress={() => setShowAddNote(true)} style={[styles.iconButton, { marginRight: 8 }]}>
                        <PlusCircle size={24} color={theme.textPrimary} />
                    </TouchableOpacity>
                    <TouchableOpacity onPress={() => setShowEditBook(true)} style={[styles.iconButton, { marginRight: 8 }]}>
                        <Edit2 size={24} color={theme.textSecondary} />
                    </TouchableOpacity>
                    <TouchableOpacity onPress={handleDelete} style={styles.iconButton}>
                        <Trash2 size={24} color="#FF3B30" />
                    </TouchableOpacity>
                </View>
            </View>

            <ScrollView contentContainerStyle={styles.content}>
                <View style={styles.topSection}>
                    <View style={styles.coverWrapper}>
                        <CoverImageView coverUrl={bookLocal.coverImageUrl} isDark={isDark} placeholderIconSize={48} />
                    </View>
                </View>

                <GlassCard style={styles.infoCard}>
                    <Text style={[styles.title, { color: theme.textPrimary }]}>{bookLocal.title}</Text>
                    <Text style={[styles.author, { color: theme.textSecondary }]}>{bookLocal.author}</Text>
                    {bookLocal.totalPages > 0 && (
                        <Text style={[styles.pages, { color: theme.textTertiary }]}>{bookLocal.totalPages} sayfa</Text>
                    )}
                </GlassCard>

                <GlassCard style={styles.infoCard}>
                    <View style={styles.progressRow}>
                        <Text style={[styles.progressTitle, { color: theme.textPrimary }]}>Okuma İlerlemesi</Text>
                        <Text style={[styles.progressTitle, { color: theme.primary }]}>
                            {bookLocal.totalPages > 0 ? `%${Math.floor((bookLocal.currentPage / bookLocal.totalPages) * 100)}` : '—'}
                        </Text>
                    </View>
                    {bookLocal.totalPages > 0 && (
                        <View style={[styles.progressTrack, { backgroundColor: 'rgba(47, 125, 92, 0.20)' }]}>
                            <View style={[styles.progressFill, { backgroundColor: theme.primary, width: `${Math.min(100, Math.max(0, (bookLocal.currentPage / bookLocal.totalPages) * 100))}%` }]} />
                        </View>
                    )}
                    <TouchableOpacity style={[styles.pageButton, { backgroundColor: 'rgba(47, 125, 92, 0.10)' }]} onPress={() => setShowEditPage(true)}>
                        <Bookmark size={14} color={theme.primary} style={{ marginRight: 4 }} />
                        <Text style={{ color: theme.primary, fontWeight: '500' }}>Sayfa {bookLocal.currentPage} / {bookLocal.totalPages}</Text>
                    </TouchableOpacity>
                </GlassCard>

                <View style={styles.notesSection}>
                    <Text style={[styles.sectionTitle, { color: theme.textPrimary }]}>Notlar</Text>

                    {isLoading ? (
                        <ActivityIndicator color={theme.primary} style={{ marginTop: 24 }} />
                    ) : notes.length === 0 ? (
                        <View style={styles.emptyNotes}>
                            <Text style={{ color: theme.textTertiary }}>Bu kitaba henüz not eklenmemiş.</Text>
                        </View>
                    ) : (
                        notes.map(note => (
                            <View key={note.id} style={[styles.noteCard, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                                <View style={styles.noteHeader}>
                                    <Text style={[styles.noteTitle, { color: theme.textPrimary }]}>{note.title}</Text>
                                    <TouchableOpacity onPress={() => handleDeleteNote(note.id)}>
                                        <Trash2 size={16} color="#FF3B30" />
                                    </TouchableOpacity>
                                </View>
                                {note.pageNumber && note.pageNumber > 0 ? (
                                    <View style={[styles.notePageBadge, { backgroundColor: 'rgba(47, 125, 92, 0.10)' }]}>
                                        <Text style={{ fontSize: 12, color: theme.primary }}>s. {note.pageNumber}</Text>
                                    </View>
                                ) : null}
                                <Text style={[styles.noteContent, { color: theme.textSecondary }]}>{note.content}</Text>
                            </View>
                        ))
                    )}
                </View>
            </ScrollView>

            <Modal visible={showAddNote} animationType="slide" presentationStyle="pageSheet">
                <AddNoteScreen bookId={bookLocal.id} onCancel={() => setShowAddNote(false)} onSave={() => { setShowAddNote(false); loadNotes(); }} />
            </Modal>

            <Modal visible={showEditBook} animationType="slide" presentationStyle="pageSheet">
                <AddBookScreen
                    bookToEdit={bookLocal}
                    onCancel={() => setShowEditBook(false)}
                    onSave={async (params) => {
                        var up = await BookStoreService.updateBook({ ...bookLocal, title: params.title, author: params.author, totalPages: params.totalPages, coverImageUrl: params.coverImageUrl });
                        setBookLocal(up); setShowEditBook(false);
                    }}
                />
            </Modal>

            <Modal visible={showEditPage} transparent animationType="fade">
                <View style={styles.modalBg}>
                    <View style={[styles.modalBox, { backgroundColor: theme.surfacePrimary }]}>
                        <Text style={[styles.modalTitle, { color: theme.textPrimary }]}>Şu an kaçıncı sayfadasınız?</Text>
                        <TextInput style={[styles.modalInput, { borderColor: theme.primary, color: theme.textPrimary }]} keyboardType="number-pad" value={pageText} onChangeText={setPageText} />
                        <View style={styles.modalActions}>
                            <TouchableOpacity onPress={() => setShowEditPage(false)} style={styles.modalBtn}><Text style={{ color: theme.textSecondary }}>İptal</Text></TouchableOpacity>
                            <TouchableOpacity onPress={handleUpdatePage} style={styles.modalBtn}><Text style={{ color: theme.primary, fontWeight: 'bold' }}>Güncelle</Text></TouchableOpacity>
                        </View>
                    </View>
                </View>
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
        paddingTop: 60,
        paddingHorizontal: Theme.spacing.md,
        paddingBottom: Theme.spacing.sm,
        zIndex: 10,
    },
    actions: {
        flexDirection: 'row'
    },
    iconButton: {
        width: 40,
        height: 40,
        justifyContent: 'center',
        alignItems: 'center',
    },
    content: {
        paddingHorizontal: Theme.spacing.md,
        paddingBottom: Theme.spacing.xxxl,
    },
    topSection: {
        alignItems: 'center',
        marginTop: Theme.spacing.lg,
        marginBottom: Theme.spacing.lg,
    },
    coverWrapper: {
        width: 140,
        height: 210,
        borderRadius: Theme.radius.large,
        overflow: 'hidden',
        borderWidth: 0.5,
        borderColor: '#0000001A',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 10 },
        shadowOpacity: 0.15,
        shadowRadius: 20,
        elevation: 8,
    },
    infoCard: {
        padding: Theme.spacing.md,
        borderWidth: 0,
        marginBottom: Theme.spacing.lg,
    },
    title: {
        fontSize: 20,
        fontWeight: 'bold',
        marginBottom: 4,
    },
    author: {
        fontSize: 16,
        marginBottom: 4,
    },
    pages: {
        fontSize: 12,
    },
    progressRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 },
    progressTitle: { fontSize: 13, fontWeight: '500' },
    progressTrack: { height: 6, borderRadius: 3, overflow: 'hidden', marginBottom: 12 },
    progressFill: { height: '100%', borderRadius: 3 },
    pageButton: { flexDirection: 'row', justifyContent: 'center', padding: 8, borderRadius: Theme.radius.small },
    notesSection: {
        marginTop: Theme.spacing.sm,
    },
    sectionTitle: {
        fontSize: 20,
        fontWeight: 'bold',
        marginBottom: Theme.spacing.md,
    },
    emptyNotes: {
        padding: Theme.spacing.xl,
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 1,
        borderStyle: 'dashed',
        borderColor: '#00000033',
        borderRadius: Theme.radius.medium,
    },
    noteCard: {
        padding: Theme.spacing.md,
        borderRadius: Theme.radius.medium,
        borderWidth: 0.5,
        marginBottom: Theme.spacing.sm,
    },
    noteHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginBottom: 4,
    },
    noteTitle: {
        fontSize: 16,
        fontWeight: '600',
    },
    notePageBadge: {
        alignSelf: 'flex-start',
        paddingHorizontal: 8, paddingVertical: 2,
        borderRadius: 12,
        marginBottom: 4,
    },
    noteContent: {
        fontSize: 14,
        lineHeight: 20,
    },
    modalBg: { flex: 1, backgroundColor: '#00000080', justifyContent: 'center', alignItems: 'center' },
    modalBox: { width: '80%', padding: 20, borderRadius: Theme.radius.large },
    modalTitle: { fontSize: 16, fontWeight: 'bold', marginBottom: 16, textAlign: 'center' },
    modalInput: { borderWidth: 1, borderRadius: Theme.radius.medium, padding: 12, marginBottom: 16, fontSize: 16, textAlign: 'center' },
    modalActions: { flexDirection: 'row', justifyContent: 'space-around' },
    modalBtn: { padding: 10 }
});
