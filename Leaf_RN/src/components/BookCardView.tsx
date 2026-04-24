import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { CoverImageView } from './CoverImageView';
import { Theme, getTheme } from './theme';
import { Book } from '../models';

interface BookCardProps {
    book: Book;
    isDark?: boolean;
}

export const BookCardView: React.FC<BookCardProps> = ({ book, isDark = false }) => {
    const theme = getTheme(isDark);

    return (
        <View style={[styles.card, { backgroundColor: theme.surfacePrimary, borderColor: theme.borderSubtle }]}>
            <View style={styles.coverWrapper}>
                <CoverImageView coverUrl={book.coverImageUrl} isDark={isDark} />
            </View>

            <View style={styles.content}>
                <Text
                    style={[styles.title, { color: theme.textPrimary }]}
                    numberOfLines={2}
                >
                    {book.title}
                </Text>

                <Text
                    style={[styles.author, { color: theme.textTertiary }]}
                    numberOfLines={1}
                >
                    {book.author}
                </Text>

                {book.currentPage > 0 && book.totalPages > 0 && (
                    <View style={styles.progressWrapper}>
                        <View style={[styles.progressTrack, { backgroundColor: 'rgba(47, 125, 92, 0.20)' }]}>
                            <View
                                style={[
                                    styles.progressFill,
                                    {
                                        backgroundColor: theme.primary,
                                        width: `${Math.min(100, Math.max(0, (book.currentPage / book.totalPages) * 100))}%`
                                    }
                                ]}
                            />
                        </View>
                    </View>
                )}
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    card: {
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
        overflow: 'hidden',
        boxShadow: '0px 4px 8px rgba(0, 0, 0, 0.06)',
        elevation: 3,
    } as any,
    coverWrapper: {
        height: 220,
        width: '100%',
    },
    content: {
        paddingHorizontal: Theme.spacing.sm,
        paddingVertical: Theme.spacing.sm,
    },
    title: {
        fontSize: 13,
        fontWeight: '600',
        marginBottom: Theme.spacing.xxs,
    },
    author: {
        fontSize: 12,
    },
    progressWrapper: {
        marginTop: Theme.spacing.xxs,
        paddingTop: Theme.spacing.xxs,
    },
    progressTrack: {
        height: 4,
        borderRadius: 2,
        width: '100%',
        overflow: 'hidden',
    },
    progressFill: {
        height: '100%',
        borderRadius: 2,
    }
});
