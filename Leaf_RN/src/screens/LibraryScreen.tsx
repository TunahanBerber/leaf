import React, { useState, useCallback } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { View, StyleSheet, TouchableOpacity, Text, Modal } from 'react-native';
import { Plus } from 'lucide-react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { LibraryGridScreen } from './LibraryGridScreen';
import { AddBookScreen } from './AddBookScreen';
import { SettingsScreen } from './SettingsScreen';
import { Theme, getTheme } from '../components/theme';
import { Book } from '../models';
import { BookStoreService } from '../services/BookStoreService';
import { SocialService } from '../services/SocialService';
import { useAppTheme } from '../components/ThemeContext';

export const LibraryScreen: React.FC<any> = ({ navigation }) => {
    // In a real app, these states would come from a Context/Zustand store or React Query
    const [books, setBooks] = useState<Book[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [showAddBook, setShowAddBook] = useState(false);
    const [showSettings, setShowSettings] = useState(false);
    const [userInitial, setUserInitial] = useState('U');

    useFocusEffect(
        useCallback(() => {
            loadBooks();
            loadUserInitial();
        }, [])
    );

    const loadUserInitial = async () => {
        try {
            const profile = await SocialService.loadCurrentProfile();
            if (profile?.username) {
                setUserInitial(profile.username.charAt(0).toUpperCase());
            }
        } catch (e) { }
    };

    const loadBooks = async () => {
        setIsLoading(true);
        try {
            const data = await BookStoreService.fetchAllBooks();
            setBooks(data);
        } catch (error) {
            console.error("Kitaplar yüklenirken hata oluştu:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />
            <View style={styles.header}>
                <TouchableOpacity onPress={() => setShowSettings(true)}>
                    <View style={[styles.avatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)', borderColor: 'rgba(47, 125, 92, 0.30)' }]}>
                        <Text style={[styles.avatarText, { color: theme.primary }]}>{userInitial}</Text>
                    </View>
                </TouchableOpacity>

                <Text style={[styles.title, { color: theme.textPrimary }]}>Kitaplığım</Text>

                <TouchableOpacity onPress={() => setShowAddBook(true)}>
                    <Plus size={24} color={theme.primary} />
                </TouchableOpacity>
            </View>

            <LibraryGridScreen
                books={books}
                isLoading={isLoading}
                onBookPress={(book) => {
                    navigation.navigate('BookDetail', { book });
                }}
                onAddBook={() => setShowAddBook(true)}
                isDark={isDark}
            />

            <Modal visible={showAddBook} animationType="slide" presentationStyle="pageSheet">
                <AddBookScreen
                    onCancel={() => setShowAddBook(false)}
                    onSave={async (params) => {
                        try {
                            setIsLoading(true);
                            await BookStoreService.addBook({
                                title: params.title,
                                author: params.author,
                                totalPages: params.totalPages || 100,
                                coverImageUrl: params.coverImageUrl,
                                isWishlist: false
                            });
                            await loadBooks(); // reload library
                        } catch (e) {
                            console.error(e);
                        } finally {
                            setIsLoading(false);
                            setShowAddBook(false);
                        }
                    }}
                    isDark={isDark}
                />
            </Modal>

            <Modal visible={showSettings} animationType="slide" presentationStyle="pageSheet">
                <SettingsScreen onClose={() => setShowSettings(false)} isDark={isDark} />
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
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: Theme.spacing.md,
        paddingTop: Theme.spacing.xxl, // Safe area roughly
        paddingBottom: Theme.spacing.sm,
        backgroundColor: 'transparent',
        zIndex: 10,
    },
    avatar: {
        width: 32,
        height: 32,
        borderRadius: 16,
        borderWidth: 0.5,
        justifyContent: 'center',
        alignItems: 'center',
    },
    avatarText: {
        fontSize: 14,
        fontWeight: 'bold',
    },
    title: {
        fontSize: 28,
        fontWeight: 'bold',
    }
});
