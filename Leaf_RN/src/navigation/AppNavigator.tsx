import React, { useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { DeviceEventEmitter, View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { BlurView } from 'expo-blur';
import { AuthScreen } from '../screens/AuthScreen';
import { LibraryScreen } from '../screens/LibraryScreen';
import { DiscoverScreen } from '../screens/DiscoverScreen';
import { InboxScreen } from '../screens/InboxScreen';
import { WishlistScreen } from '../screens/WishlistScreen';
import { BookDetailScreen } from '../screens/BookDetailScreen';
import { UserProfileScreen } from '../screens/UserProfileScreen';
import { ProfileSetupScreen } from '../screens/ProfileSetupScreen';
import { ConversationScreen } from '../screens/ConversationScreen';
import { BookOpen, Users, MessageCircle, Bookmark } from 'lucide-react-native';
import { getTheme } from '../components/theme';
import { ThemeProvider, useAppTheme } from '../components/ThemeContext';
import { AuthService } from '../services/AuthService';
import { SocialService } from '../services/SocialService';
import { User } from '@supabase/supabase-js';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

// ─── Liquid Glass Tab Bar ───────────────────────────────────────────
const LiquidGlassTabBar = ({ state, descriptors, navigation }: any) => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);
    const glassBg = isDark ? 'rgba(20, 20, 25, 0.50)' : 'rgba(255, 255, 255, 0)';
    const highlightColor = isDark ? 'rgba(255, 255, 255, 0.12)' : 'rgba(255, 255, 255, 0.7)';

    return (
        <View style={glassStyles.container}>
            {/* Blur backdrop */}
            <BlurView intensity={70} tint="light" style={StyleSheet.absoluteFillObject} />
            {/* Semi-transparent glass overlay */}
            <View style={[glassStyles.glassOverlay, { backgroundColor: glassBg }]} />
            <View style={[glassStyles.topHighlight, { backgroundColor: highlightColor }]} />

            <View style={glassStyles.tabRow}>
                {state.routes.map((route: any, index: number) => {
                    const { options } = descriptors[route.key];
                    const isFocused = state.index === index;
                    const color = isFocused ? theme.primary : theme.textTertiary;
                    const badge = options.tabBarBadge;

                    const onPress = () => {
                        const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
                        if (!isFocused && !event.defaultPrevented) {
                            navigation.navigate(route.name);
                        }
                    };

                    const label = typeof options.tabBarLabel === 'string' ? options.tabBarLabel : route.name;

                    return (
                        <TouchableOpacity
                            key={route.key}
                            onPress={onPress}
                            activeOpacity={0.7}
                            style={glassStyles.tab}
                        >
                            {/* Active pill background */}
                            {isFocused && <View style={[glassStyles.activePill, { backgroundColor: 'rgba(47, 125, 92, 0.1)' }]} />}

                            <View style={glassStyles.iconLabel}>
                                <View>
                                    {options.tabBarIcon?.({ color, size: 22, focused: isFocused })}
                                    {badge !== undefined ? (
                                        <View style={[glassStyles.badgeContainer, { backgroundColor: theme.primary }]}>
                                            <Text style={glassStyles.badgeText}>{badge}</Text>
                                        </View>
                                    ) : null}
                                </View>
                                <Text style={[glassStyles.label, { color, fontWeight: isFocused ? '600' : '400' }]}>
                                    {label}
                                </Text>
                            </View>
                        </TouchableOpacity>
                    );
                })}
            </View>
        </View>
    );
};

const glassStyles = StyleSheet.create({
    container: {
        position: 'absolute',
        bottom: 16,
        left: 16,
        right: 16,
        overflow: 'hidden',
        borderRadius: 22,
        // Web glass effect
        backdropFilter: 'blur(24px) saturate(180%)',
        WebkitBackdropFilter: 'blur(24px) saturate(180%)',
        boxShadow: '0px 4px 20px rgba(0, 0, 0, 0.08), 0px 1px 4px rgba(0, 0, 0, 0.04)',
        elevation: 8,
    } as any,
    glassOverlay: {
        ...StyleSheet.absoluteFillObject,
        backgroundColor: 'rgba(255, 255, 255, 0)',
    },
    topHighlight: {
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: 0.5,
        backgroundColor: 'rgba(255, 255, 255, 0.7)',
    },
    tabRow: {
        flexDirection: 'row',
        paddingTop: 10,
        paddingBottom: 10,
        paddingHorizontal: 8,
    },
    tab: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        position: 'relative',
        paddingVertical: 4,
    },
    activePill: {
        position: 'absolute',
        top: 2,
        bottom: 2,
        left: 8,
        right: 8,
        borderRadius: 14,
    },
    iconLabel: {
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1,
        gap: 3,
    },
    label: {
        fontSize: 10,
        letterSpacing: -0.2,
    },
    badgeContainer: {
        position: 'absolute',
        top: -4,
        right: -8,
        borderRadius: 10,
        minWidth: 16,
        height: 16,
        justifyContent: 'center',
        alignItems: 'center',
        paddingHorizontal: 4,
        borderWidth: 1.5,
        borderColor: 'rgba(255, 255, 255, 0.2)',
    },
    badgeText: {
        color: '#FFF',
        fontSize: 9,
        fontWeight: 'bold',
    },
});

// ─── Main Tabs ──────────────────────────────────────────────────────
const MainTabs = () => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);
    const [socialEnabled, setSocialEnabled] = useState(true);
    const [requestCount, setRequestCount] = useState(0);

    const loadRequestCount = async () => {
        try {
            const reqs = await SocialService.fetchPendingRequests();
            setRequestCount(reqs.length);
        } catch(e) {}
    };

    useEffect(() => {
        AsyncStorage.getItem('socialFeaturesEnabled').then(val => {
            if (val !== null) setSocialEnabled(val === 'true');
        });
        const sub = DeviceEventEmitter.addListener('socialSettingsChanged', setSocialEnabled);
        
        loadRequestCount();
        const subRequests = DeviceEventEmitter.addListener('requestsUpdated', setRequestCount);
        
        return () => {
            sub.remove();
            subRequests.remove();
        };
    }, []);

    return (
        <Tab.Navigator
            tabBar={(props) => <LiquidGlassTabBar {...props} />}
            screenOptions={{
                headerShown: false,
            }}
        >
            <Tab.Screen
                name="Library"
                component={LibraryScreen}
                options={{ tabBarLabel: 'Kitaplığım', tabBarIcon: ({ color, size }) => <BookOpen color={color} size={size} /> }}
            />
            {socialEnabled && (
                <>
                    <Tab.Screen
                        name="Discover"
                        component={DiscoverScreen}
                        options={{ tabBarLabel: 'Keşfet', tabBarIcon: ({ color, size }) => <Users color={color} size={size} /> }}
                    />
                    <Tab.Screen
                        name="Inbox"
                        component={InboxScreen}
                        options={{ 
                            tabBarLabel: 'Mesajlar', 
                            tabBarIcon: ({ color, size }) => <MessageCircle color={color} size={size} />,
                            tabBarBadge: requestCount > 0 ? requestCount : undefined
                        }}
                    />
                </>
            )}
            <Tab.Screen
                name="Wishlist"
                component={WishlistScreen}
                options={{ tabBarLabel: 'İstekler', tabBarIcon: ({ color, size }) => <Bookmark color={color} size={size} /> }}
            />
        </Tab.Navigator>
    );
};

// ─── App Navigator ──────────────────────────────────────────────────
export const AppNavigator = () => {
    const [user, setUser] = useState<User | null>(null);
    const [hasProfile, setHasProfile] = useState<boolean | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        const checkAuthAndProfile = async (sessionUser: User | null) => {
            if (!sessionUser) {
                setUser(null);
                setHasProfile(false);
                setIsLoading(false);
                return;
            }
            setUser(sessionUser);
            const profile = await SocialService.loadCurrentProfile();
            setHasProfile(!!profile);
            
            if (profile && profile.age !== undefined && profile.age !== null && profile.age < 18) {
                await AsyncStorage.setItem('socialFeaturesEnabled', 'false');
                DeviceEventEmitter.emit('socialSettingsChanged', false);
            }

            setIsLoading(false);
        };

        AuthService.getSession().then((session) => {
            checkAuthAndProfile(session?.user ?? null);
        });

        const unsubscribe = AuthService.onAuthStateChange((newUser) => {
            setIsLoading(true);
            checkAuthAndProfile(newUser);
        });

        return () => unsubscribe();
    }, []);

    if (isLoading) return null;

    return (
        <ThemeProvider>
            <NavigationContainer>
                <Stack.Navigator screenOptions={{ headerShown: false, animation: 'fade' }}>
                    {user ? (
                        hasProfile ? (
                            <>
                                <Stack.Screen name="MainTabs" component={MainTabs} />
                                <Stack.Screen name="BookDetail" component={BookDetailScreen} />
                                <Stack.Screen name="UserProfile" component={UserProfileScreen} />
                                <Stack.Screen name="Conversation" component={ConversationScreen} />
                            </>
                        ) : (
                            <Stack.Screen 
                                name="ProfileSetup" 
                                component={ProfileSetupScreen} 
                                initialParams={{ onProfileCreated: () => setHasProfile(true) }} 
                            />
                        )
                    ) : (
                        <Stack.Screen name="Auth" component={AuthScreen} />
                    )}
                </Stack.Navigator>
            </NavigationContainer>
        </ThemeProvider>
    );
};
