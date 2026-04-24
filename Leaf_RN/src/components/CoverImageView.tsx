import React, { useState } from 'react';
import { View, StyleSheet, Image, ActivityIndicator } from 'react-native';
import { BookOpen } from 'lucide-react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Theme, getTheme } from './theme';

interface CoverImageViewProps {
    coverUrl?: string | null;
    placeholderIconSize?: number;
    isDark?: boolean;
}

const BASE_URL = "https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/book-covers/";

export const CoverImageView: React.FC<CoverImageViewProps> = ({
    coverUrl,
    placeholderIconSize = 36,
    isDark = false
}) => {
    const theme = getTheme(isDark);
    const [isLoading, setIsLoading] = useState(true);
    const [hasError, setHasError] = useState(false);

    const renderPlaceholderBackground = () => (
        <View
            style={[
                StyleSheet.absoluteFillObject,
                { backgroundColor: 'rgba(46, 125, 50, 0.15)' }
            ]}
        />
    );

    const isAbsolute = coverUrl?.startsWith('http://') || coverUrl?.startsWith('https://');
    const imageUri = isAbsolute ? coverUrl : `${BASE_URL}${coverUrl}`;

    return (
        <View style={styles.container}>
            {coverUrl && !hasError ? (
                <>
                    <Image
                        source={{ uri: imageUri as string }}
                        style={styles.image}
                        resizeMode="cover"
                        onLoadEnd={() => setIsLoading(false)}
                        onError={() => {
                            setIsLoading(false);
                            setHasError(true);
                        }}
                    />
                    {isLoading && (
                        <View style={styles.loadingContainer}>
                            {renderPlaceholderBackground()}
                            <ActivityIndicator color={theme.primary} />
                        </View>
                    )}
                </>
            ) : (
                <View style={styles.placeholderContainer}>
                    {renderPlaceholderBackground()}
                    <BookOpen
                        size={placeholderIconSize}
                        color={'rgba(47, 125, 92, 0.40)'} // opacity 0.4 
                        strokeWidth={1}
                    />
                </View>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        overflow: 'hidden',
        position: 'relative',
        backgroundColor: '#00000000',
    },
    image: {
        ...StyleSheet.absoluteFillObject,
        width: '100%',
        height: '100%',
    },
    loadingContainer: {
        ...StyleSheet.absoluteFillObject,
        justifyContent: 'center',
        alignItems: 'center',
    },
    placeholderContainer: {
        ...StyleSheet.absoluteFillObject,
        justifyContent: 'center',
        alignItems: 'center',
    }
});
