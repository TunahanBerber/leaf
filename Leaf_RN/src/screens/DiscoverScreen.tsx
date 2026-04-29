import React, { useState, useCallback, useRef } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { View, Text, StyleSheet, Animated, PanResponder, Dimensions, TouchableOpacity, ActivityIndicator } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { Theme, getTheme } from '../components/theme';
import { UserProfile } from '../models';
import { SocialService } from '../services/SocialService';
import { Users, X, MessageCircle } from 'lucide-react-native';
import { useAppTheme } from '../components/ThemeContext';

const SCREEN_WIDTH = Dimensions.get('window').width;
const SCREEN_HEIGHT = Dimensions.get('window').height;
const SWIPE_THRESHOLD = 0.25 * SCREEN_WIDTH;
const SWIPE_OUT_DURATION = 250;

export const DiscoverScreen: React.FC<any> = ({ navigation }) => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);
    
    const [users, setUsers] = useState<UserProfile[]>([]);
    const [currentIndex, setCurrentIndex] = useState(0);
    const [isLoading, setIsLoading] = useState(true);

    const position = useRef(new Animated.ValueXY()).current;

    const panResponder = useRef(
        PanResponder.create({
            onStartShouldSetPanResponder: () => true,
            onPanResponderMove: (event, gesture) => {
                position.setValue({ x: gesture.dx, y: gesture.dy });
            },
            onPanResponderRelease: (event, gesture) => {
                if (gesture.dx > SWIPE_THRESHOLD) {
                    forceSwipe('right');
                } else if (gesture.dx < -SWIPE_THRESHOLD) {
                    forceSwipe('left');
                } else {
                    resetPosition();
                }
            }
        })
    ).current;

    useFocusEffect(
        useCallback(() => {
            loadUsers();
        }, [])
    );

    const shuffleArray = (array: any[]) => {
        let currIndex = array.length, randomIndex;
        while (currIndex !== 0) {
            randomIndex = Math.floor(Math.random() * currIndex);
            currIndex--;
            [array[currIndex], array[randomIndex]] = [array[randomIndex], array[currIndex]];
        }
        return array;
    };

    const loadUsers = async () => {
        setIsLoading(true);
        try {
            const data = await SocialService.discoverUsers();
            setUsers(shuffleArray(data));
            setCurrentIndex(0);
        } catch {
            setUsers([]);
        }
        setIsLoading(false);
    };

    const forceSwipe = (direction: 'right' | 'left') => {
        const x = direction === 'right' ? SCREEN_WIDTH : -SCREEN_WIDTH;
        Animated.timing(position, {
            toValue: { x, y: 0 },
            duration: SWIPE_OUT_DURATION,
            useNativeDriver: false
        }).start(() => onSwipeComplete(direction));
    };

    const resetPosition = () => {
        Animated.spring(position, {
            toValue: { x: 0, y: 0 },
            useNativeDriver: false
        }).start();
    };

    const onSwipeComplete = async (direction: 'right' | 'left') => {
        const item = users[currentIndex];
        
        if (direction === 'right') {
            try {
                await SocialService.sendConversationRequest(item.id);
            } catch (e) {
                // Ignore silent failure
            }
        }

        position.setValue({ x: 0, y: 0 });
        setCurrentIndex(prev => prev + 1);
    };

    const getCardStyle = () => {
        const rotate = position.x.interpolate({
            inputRange: [-SCREEN_WIDTH * 1.5, 0, SCREEN_WIDTH * 1.5],
            outputRange: ['-120deg', '0deg', '120deg']
        });

        return {
            ...position.getLayout(),
            transform: [{ rotate }]
        };
    };

    const renderCards = () => {
        if (currentIndex >= users.length) {
            return (
                <View style={styles.center}>
                    <Users size={48} color={theme.textTertiary} />
                    <Text style={[styles.emptyTitle, { color: theme.textPrimary }]}>Kimse kalmadı</Text>
                    <Text style={[styles.emptySubtitle, { color: theme.textSecondary }]}>
                        Daha fazla kitap ekleyerek{'\n'}yeni eşleşmeler bulabilirsin.
                    </Text>
                </View>
            );
        }

        const solidBg = isDark ? '#121212' : '#FFFFFF';

        return users.map((user, i) => {
            if (i < currentIndex) return null;
            if (i > currentIndex + 1) return null; // Only render top 2 cards for performance

            if (i === currentIndex) {
                return (
                    <Animated.View
                        key={user.id}
                        style={[getCardStyle(), styles.cardStyle, { backgroundColor: solidBg, borderColor: theme.borderSubtle }]}
                        {...panResponder.panHandlers}
                    >
                        {renderCardContent(user, true)}
                    </Animated.View>
                );
            }

            return (
                <Animated.View
                    key={user.id}
                    style={[styles.cardStyle, { backgroundColor: solidBg, borderColor: theme.borderSubtle, top: 10, transform: [{ scale: 0.95 }] }]}
                >
                    {renderCardContent(user, false)}
                </Animated.View>
            );
        }).reverse();
    };

    const renderCardContent = (user: UserProfile, isTopCard: boolean) => {
        let likeOpacity: any = 0;
        let nopeOpacity: any = 0;

        if (isTopCard) {
            likeOpacity = position.x.interpolate({
                inputRange: [0, SCREEN_WIDTH / 3],
                outputRange: [0, 1],
                extrapolate: 'clamp'
            });
            nopeOpacity = position.x.interpolate({
                inputRange: [-SCREEN_WIDTH / 3, 0],
                outputRange: [1, 0],
                extrapolate: 'clamp'
            });
        }

        return (
            <View style={styles.cardContent}>
                {isTopCard && (
                    <>
                        <Animated.View style={[styles.stamp, styles.stampLike, { opacity: likeOpacity }]}>
                            <MessageCircle size={48} color={theme.primary} />
                        </Animated.View>
                        <Animated.View style={[styles.stamp, styles.stampNope, { opacity: nopeOpacity }]}>
                            <X size={48} color="#FF3B30" />
                        </Animated.View>
                    </>
                )}

                <View style={styles.cardTop}>
                    <View style={[styles.largeAvatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                        <Text style={[styles.largeAvatarText, { color: theme.primary }]}>
                            {user.username.charAt(0).toUpperCase()}
                        </Text>
                    </View>
                    <Text style={[styles.cardName, { color: theme.textPrimary }]}>
                        {user.username}{user.age ? `, ${user.age}` : ''}
                    </Text>
                    {user.bio ? (
                        <Text style={[styles.cardBio, { color: theme.textSecondary }]}>{user.bio}</Text>
                    ) : null}
                </View>

                {user.commonBookTitles && user.commonBookTitles.length > 0 && (
                    <View style={[styles.commonBooksContainer, { backgroundColor: isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.03)' }]}>
                        <Text style={[styles.commonBooksTitle, { color: theme.textPrimary }]}>Ortak Kitaplarınız</Text>
                        <Text style={[styles.commonBooksText, { color: theme.primary }]}>
                            {user.commonBookTitles.join(', ')}
                        </Text>
                    </View>
                )}
            </View>
        );
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />
            
            <View style={styles.header}>
                <Text style={[styles.title, { color: theme.textPrimary }]}>Keşfet</Text>
            </View>

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator color={theme.primary} size="large" />
                </View>
            ) : (
                <View style={styles.deckContainer}>
                    {renderCards()}
                </View>
            )}

            {!isLoading && currentIndex < users.length && (
                <View style={styles.buttonContainer}>
                    <TouchableOpacity
                        style={[styles.actionButton, { backgroundColor: theme.surfacePrimary, borderColor: '#FF3B30' }]}
                        onPress={() => forceSwipe('left')}
                    >
                        <X size={32} color="#FF3B30" />
                    </TouchableOpacity>
                    
                    <TouchableOpacity
                        style={[styles.actionButton, { backgroundColor: theme.surfacePrimary, borderColor: theme.primary }]}
                        onPress={() => forceSwipe('right')}
                    >
                        <MessageCircle size={32} color={theme.primary} />
                    </TouchableOpacity>
                </View>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: { paddingTop: 60, paddingHorizontal: Theme.spacing.md, paddingBottom: Theme.spacing.sm },
    title: { fontSize: 28, fontWeight: 'bold' },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: Theme.spacing.xxl },
    emptyTitle: { fontSize: 18, fontWeight: '600', marginTop: 16 },
    emptySubtitle: { fontSize: 14, textAlign: 'center', marginTop: 8 },
    deckContainer: {
        flex: 1,
        marginTop: 20,
    },
    cardStyle: {
        position: 'absolute',
        width: SCREEN_WIDTH - 32,
        height: SCREEN_HEIGHT * 0.55,
        marginLeft: 16,
        borderRadius: 24,
        borderWidth: 1,
        elevation: 5,
        overflow: 'hidden'
    },
    cardContent: {
        flex: 1,
        padding: 24,
        justifyContent: 'space-between'
    },
    cardTop: {
        alignItems: 'center',
        marginTop: 20
    },
    largeAvatar: {
        width: 120,
        height: 120,
        borderRadius: 60,
        justifyContent: 'center',
        alignItems: 'center',
        marginBottom: 20
    },
    largeAvatarText: {
        fontSize: 48,
        fontWeight: 'bold'
    },
    cardName: {
        fontSize: 28,
        fontWeight: 'bold',
        marginBottom: 8,
        textAlign: 'center'
    },
    cardBio: {
        fontSize: 16,
        textAlign: 'center',
        lineHeight: 22
    },
    commonBooksContainer: {
        padding: 16,
        borderRadius: 16,
        marginBottom: 10
    },
    commonBooksTitle: {
        fontSize: 14,
        fontWeight: '600',
        marginBottom: 6
    },
    commonBooksText: {
        fontSize: 14,
        fontWeight: '500',
        lineHeight: 20
    },
    buttonContainer: {
        flexDirection: 'row',
        justifyContent: 'space-evenly',
        marginBottom: 100,
        paddingHorizontal: 40
    },
    actionButton: {
        width: 70,
        height: 70,
        borderRadius: 35,
        borderWidth: 2,
        justifyContent: 'center',
        alignItems: 'center'
    },
    stamp: {
        position: 'absolute',
        top: 20,
        width: 80,
        height: 80,
        borderRadius: 40,
        borderWidth: 4,
        justifyContent: 'center',
        alignItems: 'center',
        zIndex: 10,
        backgroundColor: 'rgba(255,255,255,0.05)'
    },
    stampLike: {
        left: 20,
        borderColor: '#2F7D5C',
        transform: [{ rotate: '-15deg' }]
    },
    stampNope: {
        right: 20,
        borderColor: '#FF3B30',
        transform: [{ rotate: '15deg' }]
    }
});
