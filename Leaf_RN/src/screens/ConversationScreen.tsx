import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, ActivityIndicator, KeyboardAvoidingView, Platform, Alert } from 'react-native';
import { LeafGradientBackground } from '../components/LeafGradientBackground';
import { getTheme, Theme } from '../components/theme';
import { SocialService } from '../services/SocialService';
import { supabase } from '../services/supabase';
import { Message } from '../models';
import { ArrowLeft, ArrowUpCircle, Trash2 } from 'lucide-react-native';
import { useAppTheme } from '../components/ThemeContext';

export const ConversationScreen: React.FC<any> = ({ route, navigation }) => {
    const { conversationId, otherUsername } = route.params;
    const { isDark } = useAppTheme();
    const theme = getTheme(isDark);

    const [messages, setMessages] = useState<Message[]>([]);
    const [inputText, setInputText] = useState('');
    const [isLoading, setIsLoading] = useState(true);
    const [currentUserId, setCurrentUserId] = useState<string>('');
    const scrollViewRef = useRef<ScrollView>(null);

    useEffect(() => {
        loadInitial();

        SocialService.subscribeToMessages(conversationId, (msg) => {
            setMessages(prev => [...prev, msg]);
            setTimeout(() => scrollViewRef.current?.scrollToEnd({ animated: true }), 100);
        });

        return () => {
            SocialService.unsubscribeFromMessages();
        };
    }, []);

    const loadInitial = async () => {
        const { data } = await supabase.auth.getSession();
        setCurrentUserId(data?.session?.user.id.toLowerCase() || '');
        try {
            const msgs = await SocialService.fetchMessages(conversationId);
            setMessages(msgs);
            setTimeout(() => scrollViewRef.current?.scrollToEnd({ animated: false }), 100);
        } catch (e) {
            console.error(e);
        } finally {
            setIsLoading(false);
        }
    };

    const handleSend = async () => {
        const text = inputText.trim();
        if (!text) return;
        setInputText('');
        try {
            await SocialService.sendMessage(conversationId, text);
        } catch (e) { }
    };

    const handleDeleteMessage = (msg: Message) => {
        Alert.alert('Sil', 'Mesajı silmek istiyor musunuz?', [
            { text: 'İptal', style: 'cancel' },
            {
                text: 'Sil', style: 'destructive', onPress: async () => {
                    await SocialService.deleteMessage(msg.id);
                    setMessages(prev => prev.filter(m => m.id !== msg.id));
                }
            }
        ]);
    };

    return (
        <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
            <LeafGradientBackground isDark={isDark} />

            <View style={[styles.header, { borderBottomColor: theme.borderSubtle, borderBottomWidth: 1 }]}>
                <TouchableOpacity onPress={() => navigation.goBack()} style={{ padding: 8 }}>
                    <ArrowLeft color={theme.textPrimary} size={24} />
                </TouchableOpacity>
                <Text style={[styles.headerTitle, { color: theme.textPrimary }]}>{otherUsername}</Text>
                <View style={{ width: 40 }} />
            </View>

            {isLoading ? (
                <View style={styles.center}>
                    <ActivityIndicator color={theme.primary} />
                </View>
            ) : (
                <ScrollView
                    ref={scrollViewRef}
                    contentContainerStyle={styles.messageList}
                    onContentSizeChange={() => scrollViewRef.current?.scrollToEnd({ animated: true })}
                >
                    {messages.map((msg, idx) => {
                        const isOwn = msg.senderId === currentUserId;
                        return (
                            <TouchableOpacity
                                key={msg.id}
                                style={[styles.msgWrapper, { justifyContent: isOwn ? 'flex-end' : 'flex-start' }]}
                                onLongPress={() => isOwn ? handleDeleteMessage(msg) : null}
                            >
                                <View style={[styles.bubble, {
                                    backgroundColor: isOwn ? theme.primary : theme.surfacePrimary,
                                    borderColor: theme.borderSubtle,
                                    borderWidth: isOwn ? 0 : 0.5
                                }]}>
                                    <Text style={{ color: isOwn ? '#FFF' : theme.textPrimary, fontSize: 16 }}>{msg.content}</Text>
                                    <Text style={{ color: isOwn ? '#FFF8' : theme.textTertiary, fontSize: 10, alignSelf: 'flex-end', marginTop: 4 }}>
                                        {new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                    </Text>
                                </View>
                            </TouchableOpacity>
                        );
                    })}
                </ScrollView>
            )}

            <View style={[styles.inputBar, { backgroundColor: theme.surfacePrimary + 'E6', borderTopColor: theme.borderSubtle }]}>
                <TextInput
                    style={[styles.input, { borderColor: theme.borderSubtle, color: theme.textPrimary }]}
                    placeholder="Mesaj yaz..."
                    placeholderTextColor={theme.textTertiary}
                    value={inputText}
                    onChangeText={setInputText}
                    multiline
                    maxLength={500}
                />
                <TouchableOpacity onPress={handleSend} disabled={!inputText.trim()}>
                    <ArrowUpCircle size={36} color={!inputText.trim() ? theme.textTertiary : theme.primary} />
                </TouchableOpacity>
            </View>
        </KeyboardAvoidingView>
    );
};

const styles = StyleSheet.create({
    container: { flex: 1 },
    header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 60, paddingHorizontal: 10, paddingBottom: 10 },
    headerTitle: { fontSize: 18, fontWeight: 'bold' },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
    messageList: { paddingHorizontal: Theme.spacing.md, paddingVertical: Theme.spacing.md },
    msgWrapper: { flexDirection: 'row', width: '100%', marginBottom: 12 },
    bubble: { maxWidth: '80%', paddingHorizontal: Theme.spacing.md, paddingVertical: 10, borderRadius: Theme.radius.large },
    inputBar: { flexDirection: 'row', alignItems: 'flex-end', paddingHorizontal: Theme.spacing.sm, paddingVertical: 8, borderTopWidth: 1, paddingBottom: 24 },
    input: { flex: 1, minHeight: 40, maxHeight: 100, borderWidth: 1, borderRadius: 20, paddingHorizontal: 16, paddingTop: 12, paddingBottom: 12, fontSize: 16, marginRight: 8 }
});
