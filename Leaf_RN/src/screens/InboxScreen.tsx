import React, { useEffect, useState, useCallback, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert, DeviceEventEmitter, Animated, PanResponder, Dimensions, Platform } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { getTheme, Theme } from '../components/theme';
import { SocialService } from '../services/SocialService';
import { Conversation, ConversationRequest } from '../models';
import { MessageSquareOff, Trash2, Check, X } from 'lucide-react-native';
import { useAppTheme } from '../components/ThemeContext';

const SCREEN_WIDTH = Dimensions.get('window').width;

const SwipeableConversationItem = ({ conv, onPress, onDelete, theme, isDark }: any) => {
    const pan = useRef(new Animated.Value(0)).current;
    
    const panResponder = useRef(
        PanResponder.create({
            onStartShouldSetPanResponder: () => false,
            onMoveShouldSetPanResponder: (evt, gestureState) => {
                return gestureState.dx < -15 && Math.abs(gestureState.dx) > Math.abs(gestureState.dy);
            },
            onPanResponderMove: (evt, gestureState) => {
                if (gestureState.dx < 0) {
                    pan.setValue(Math.max(gestureState.dx, -SCREEN_WIDTH));
                }
            },
            onPanResponderRelease: (evt, gestureState) => {
                if (gestureState.dx < -150) {
                    Animated.spring(pan, { toValue: 0, useNativeDriver: false }).start();
                    onDelete(conv);
                } else if (gestureState.dx < -60) {
                    Animated.spring(pan, { toValue: -80, useNativeDriver: false }).start();
                } else {
                    Animated.spring(pan, { toValue: 0, useNativeDriver: false }).start();
                }
            },
            onPanResponderTerminate: () => {
                Animated.spring(pan, { toValue: 0, useNativeDriver: false }).start();
            }
        })
    ).current;

    const lastMsg = conv.lastMessage;
    const isUnread = lastMsg && !lastMsg.isRead && lastMsg.senderId === conv.otherUser?.id;

    const solidBg = isDark ? '#0A0A0A' : theme.surfacePrimary;

    // Fade in the red background only when swiping left to prevent border bleed
    const deleteOpacity = pan.interpolate({
        inputRange: [-20, 0],
        outputRange: [1, 0],
        extrapolate: 'clamp'
    });

    return (
        <View style={{ marginBottom: 8, position: 'relative' }}>
            <Animated.View style={{ position: 'absolute', left: 1, right: 1, top: 1, bottom: 1, backgroundColor: '#FF3B30', borderRadius: Theme.radius.large, justifyContent: 'center', alignItems: 'flex-end', opacity: deleteOpacity }}>
                <TouchableOpacity onPress={() => onDelete(conv)} style={{ width: 80, height: '100%', justifyContent: 'center', alignItems: 'center' }}>
                    <Trash2 size={24} color="#FFF" />
                </TouchableOpacity>
            </Animated.View>

            <Animated.View style={{ transform: [{ translateX: pan }] }} {...panResponder.panHandlers}>
                <TouchableOpacity
                    style={[styles.convCard, { backgroundColor: solidBg, borderColor: theme.borderSubtle, marginBottom: 0, width: '100%' }]}
                    onPress={() => {
                        pan.setValue(0);
                        onPress(conv);
                    }}
                    activeOpacity={0.8}
                >
                    <View style={[styles.avatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                        <Text style={[styles.avatarText, { color: theme.primary }]}>
                            {(conv.otherUser?.username || 'K').charAt(0).toUpperCase()}
                        </Text>
                    </View>
                    <View style={styles.convInfo}>
                        <Text style={[styles.reqName, { color: theme.textPrimary }]}>{conv.otherUser?.username || 'Kullanıcı'}</Text>
                        <Text style={[styles.reqSub, { color: isUnread ? theme.textPrimary : theme.textSecondary, fontWeight: isUnread ? 'bold' : 'normal' }]} numberOfLines={1}>
                            {lastMsg ? lastMsg.content : 'Sohbete başla'}
                        </Text>
                    </View>
                    {isUnread && (
                        <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: theme.primary }} />
                    )}
                </TouchableOpacity>
            </Animated.View>
        </View>
    );
};

export const InboxScreen: React.FC<any> = ({ navigation }) => {
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);

    const [requests, setRequests] = useState<ConversationRequest[]>([]);
    const [conversations, setConversations] = useState<Conversation[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    useFocusEffect(
        useCallback(() => {
            loadData();
        }, [])
    );

    const loadData = async () => {
        setIsLoading(true);
        try {
            const reqs = await SocialService.fetchPendingRequests();
            const convs = await SocialService.fetchConversations();
            setRequests(reqs);
            setConversations(convs);
            DeviceEventEmitter.emit('requestsUpdated', reqs.length);
        } catch (e) {
            console.error(e);
        } finally {
            setIsLoading(false);
        }
    };

    const handleAccept = async (req: ConversationRequest) => {
        try {
            const convId = await SocialService.acceptRequest(req);
            if (convId) {
                navigation.navigate('Conversation', { conversationId: convId, otherUsername: req.senderProfile?.username || 'Kullanıcı' });
            }
        } catch (e) { }
    };

    const handleReject = async (req: ConversationRequest) => {
        try {
            await SocialService.rejectRequest(req);
            await loadData();
        } catch (e) { }
    };

    const handleDeleteConversation = async (conv: Conversation) => {
        if (Platform.OS === 'web') {
            const confirmed = window.confirm('Sohbeti silmek istediğinize emin misiniz?');
            if (confirmed) {
                try {
                    await SocialService.deleteConversation(conv.id);
                    await loadData();
                } catch (e) { }
            }
        } else {
            Alert.alert('Emin misiniz?', 'Sohbeti silmek istediğinize emin misiniz?', [
                { text: 'İptal', style: 'cancel' },
                {
                    text: 'Sil', style: 'destructive', onPress: async () => {
                        try {
                            await SocialService.deleteConversation(conv.id);
                            await loadData();
                        } catch (e) { }
                    }
                }
            ]);
        }
    };

    return (
        <View style={styles.container}>
            <LeafGradientBackground isDark={isDark} />
            <View style={styles.header}>
                <Text style={[styles.headerTitle, { color: theme.textPrimary }]}>Mesajlar</Text>
            </View>

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator color={theme.primary} size="large" />
                </View>
            ) : requests.length === 0 && conversations.length === 0 ? (
                <View style={styles.center}>
                    <MessageSquareOff size={48} color={theme.textTertiary} />
                    <Text style={[styles.emptyTitle, { color: theme.textPrimary }]}>Henüz mesajın yok</Text>
                    <Text style={[styles.emptySubtitle, { color: theme.textSecondary }]}>
                        Keşfet ekranından{'\n'}kitap dostlarını bul.
                    </Text>
                </View>
            ) : (
                <ScrollView contentContainerStyle={styles.content}>
                    {requests.length > 0 && (
                        <View style={styles.section}>
                            <View style={styles.sectionHeaderRow}>
                                <Text style={[styles.sectionTitle, { color: theme.textSecondary }]}>Sohbet İstekleri</Text>
                                <View style={[styles.badge, { backgroundColor: theme.primary }]}><Text style={styles.badgeText}>{requests.length}</Text></View>
                            </View>
                            {requests.map(req => (
                                <View key={req.id} style={[styles.reqCard, { backgroundColor: theme.surfacePrimary, borderColor: 'rgba(47, 125, 92, 0.20)' }]}>
                                    <View style={[styles.avatar, { backgroundColor: 'rgba(47, 125, 92, 0.15)' }]}>
                                        <Text style={[styles.avatarText, { color: theme.primary }]}>
                                            {(req.senderProfile?.username || 'K').charAt(0).toUpperCase()}
                                        </Text>
                                    </View>
                                    <View style={styles.reqInfo}>
                                        <Text style={[styles.reqName, { color: theme.textPrimary }]}>{req.senderProfile?.username || 'Kullanıcı'}</Text>
                                        <Text style={[styles.reqSub, { color: theme.textSecondary }]}>Sohbet isteği gönderdi</Text>
                                    </View>
                                    <TouchableOpacity onPress={() => handleReject(req)} style={[styles.iconAction, { backgroundColor: '#FF3B30' }]}>
                                        <X size={16} color="#FFF" />
                                    </TouchableOpacity>
                                    <TouchableOpacity onPress={() => handleAccept(req)} style={[styles.iconAction, { backgroundColor: theme.primary }]}>
                                        <Check size={16} color="#FFF" />
                                    </TouchableOpacity>
                                </View>
                            ))}
                        </View>
                    )}

                    {conversations.length > 0 && (
                        <View style={styles.section}>
                            <Text style={[styles.sectionTitle, { color: theme.textSecondary, marginBottom: 8 }]}>Sohbetler</Text>
                            {conversations.map(conv => (
                                <SwipeableConversationItem
                                    key={conv.id}
                                    conv={conv}
                                    theme={theme}
                                    isDark={isDark}
                                    onPress={(c: any) => navigation.navigate('Conversation', { conversationId: c.id, otherUsername: c.otherUser?.username || 'Kullanıcı' })}
                                    onDelete={handleDeleteConversation}
                                />
                            ))}
                        </View>
                    )}
                </ScrollView>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: { paddingTop: 60, paddingHorizontal: Theme.spacing.md, paddingBottom: Theme.spacing.sm },
    headerTitle: { fontSize: 24, fontWeight: 'bold' },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: Theme.spacing.xxl },
    emptyTitle: { fontSize: 18, fontWeight: '600', marginTop: 16 },
    emptySubtitle: { fontSize: 14, textAlign: 'center', marginTop: 8 },
    content: { paddingHorizontal: Theme.spacing.md, paddingBottom: Theme.spacing.xxxl },
    section: { marginBottom: Theme.spacing.lg },
    sectionHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
    sectionTitle: { fontSize: 14, fontWeight: 'bold' },
    badge: { borderRadius: 12, paddingHorizontal: 6, paddingVertical: 2, marginLeft: 6 },
    badgeText: { color: '#FFF', fontSize: 10, fontWeight: 'bold' },
    reqCard: { flexDirection: 'row', alignItems: 'center', padding: Theme.spacing.md, borderRadius: Theme.radius.large, borderWidth: 1, marginBottom: 8 },
    avatar: { width: 48, height: 48, borderRadius: 24, justifyContent: 'center', alignItems: 'center' },
    avatarText: { fontSize: 18, fontWeight: 'bold' },
    reqInfo: { flex: 1, marginLeft: 12 },
    reqName: { fontSize: 16, fontWeight: 'bold' },
    reqSub: { fontSize: 12, marginTop: 2 },
    iconAction: { width: 34, height: 34, borderRadius: 17, justifyContent: 'center', alignItems: 'center', marginLeft: 8 },
    convCard: { flex: 1, flexDirection: 'row', alignItems: 'center', padding: Theme.spacing.md, borderRadius: Theme.radius.large, borderWidth: 0.5, marginBottom: 8 },
    convInfo: { flex: 1, marginLeft: 12 }
});
