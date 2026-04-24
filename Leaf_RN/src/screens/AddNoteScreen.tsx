import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, TextInput } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { LeafTextField } from '../components/LeafComponents';
import { Theme, getTheme } from '../components/theme';
import { BookStoreService } from '../services/BookStoreService';

interface AddNoteScreenProps {
    bookId: string;
    onSave: () => void;
    onCancel: () => void;
    isDark?: boolean;
}

export const AddNoteScreen: React.FC<AddNoteScreenProps> = ({ bookId, onSave, onCancel, isDark = false }) => {
    const theme = getTheme(isDark);

    const [title, setTitle] = useState('');
    const [content, setContent] = useState('');
    const [pageNum, setPageNum] = useState('');
    const [isSaving, setIsSaving] = useState(false);

    const handleSave = async () => {
        setIsSaving(true);
        try {
            await BookStoreService.addNote(
                title,
                content,
                pageNum ? parseInt(pageNum) : null,
                bookId
            );
            onSave();
        } catch (e) {
            console.error(e);
        } finally {
            setIsSaving(false);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />

            <View style={styles.header}>
                <TouchableOpacity onPress={onCancel}>
                    <Text style={[styles.headerText, { color: theme.textSecondary }]}>İptal</Text>
                </TouchableOpacity>
                <Text style={[styles.headerTitle, { color: theme.textPrimary }]}>Not Ekle</Text>
                <TouchableOpacity onPress={handleSave} disabled={!title.trim() || !content.trim() || isSaving}>
                    {isSaving ? (
                        <ActivityIndicator color={theme.primary} />
                    ) : (
                        <Text style={[styles.headerText, { fontWeight: '600', color: (!title.trim() || !content.trim()) ? theme.textTertiary : theme.primary }]}>Kaydet</Text>
                    )}
                </TouchableOpacity>
            </View>

            <ScrollView contentContainerStyle={styles.scrollContent}>
                <LeafTextField
                    title="Not Başlığı"
                    text={title}
                    onChangeText={setTitle}
                    placeholder="Notunuza bir başlık verin"
                    isDark={isDark}
                />

                <LeafTextField
                    title="Sayfa Numarası"
                    text={pageNum}
                    onChangeText={setPageNum}
                    placeholder="İsteğe bağlı"
                    keyboardType="number-pad"
                    isDark={isDark}
                />

                <View style={styles.contentSection}>
                    <Text style={[styles.label, { color: theme.textSecondary }]}>Not İçeriği</Text>
                    <View style={[styles.textAreaContainer, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
                        <TextInput
                            style={[styles.textArea, { color: theme.textPrimary }]}
                            multiline
                            textAlignVertical="top"
                            placeholder="Notunuzu buraya yazın..."
                            placeholderTextColor={theme.textTertiary}
                            value={content}
                            onChangeText={setContent}
                        />
                    </View>
                </View>
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
    headerTitle: { fontSize: 18, fontWeight: '600' },
    scrollContent: {
        padding: Theme.spacing.md,
        paddingBottom: Theme.spacing.xxxl,
    },
    contentSection: { marginTop: Theme.spacing.sm },
    label: {
        fontSize: 13,
        fontWeight: '500',
        marginBottom: Theme.spacing.xs,
    },
    textAreaContainer: {
        borderRadius: Theme.radius.medium,
        borderWidth: 0.5,
        minHeight: 200,
        padding: Theme.spacing.sm,
    },
    textArea: {
        flex: 1,
        fontSize: 15,
        minHeight: 180,
    }
});
