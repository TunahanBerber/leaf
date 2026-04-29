import { supabase } from './supabase';
import { UserProfile, Conversation, ConversationRequest, Message } from '../models';

export class SocialService {
    static messageSubscription: any = null;
    /**
     * Load current user profile
     */
    static async loadCurrentProfile(): Promise<UserProfile | null> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return null;

        const { data, error } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .limit(1)
            .single();

        if (error || !data) return null;

        return {
            id: data.id,
            username: data.username,
            avatarUrl: data.avatar_url,
            bio: data.bio,
            age: data.age
        };
    }

    /**
     * Create Profile
     */
    static async createProfile(username: string, bio: string, age: number): Promise<UserProfile | null> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return null;

        const entry: any = { id: userId, username, age };
        if (bio) entry.bio = bio;

        const { data, error } = await supabase
            .from('profiles')
            .insert(entry)
            .select()
            .single();

        if (error) throw new Error('Profil oluşturulamadı.');

        return {
            id: data.id,
            username: data.username,
            avatarUrl: data.avatar_url,
            bio: data.bio,
            age: data.age
        };
    }

    /**
     * Update Profile
     */
    static async updateProfile(username: string, bio: string): Promise<UserProfile | null> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return null;

        const entry: any = { username };
        if (bio) entry.bio = bio;

        const { data, error } = await supabase
            .from('profiles')
            .update(entry)
            .eq('id', userId)
            .select()
            .single();

        if (error) throw new Error('Profil güncellenemedi.');

        return {
            id: data.id,
            username: data.username,
            avatarUrl: data.avatar_url,
            bio: data.bio,
            age: data.age
        };
    }

    /**
     * Discover Users using RPC call
     */
    static async discoverUsers(): Promise<UserProfile[]> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return [];

        const { data, error } = await supabase.rpc('discover_users');
        if (error || !data) throw new Error('Kullanıcılar yüklenemedi.');

        const users = data.map((u: any) => ({
            id: u.profile_id,
            username: u.username,
            avatarUrl: u.avatar_url,
            bio: u.bio,
            age: u.age,
            commonBookTitles: u.common_book_titles
        }));

        const { data: allReqs } = await supabase.from('conversation_requests').select('*').or(`sender_id.eq.${userId},receiver_id.eq.${userId}`);
        const { data: allConvs } = await supabase.from('conversations').select('*').or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`);

        const excludeSet = new Set<string>();
        if (allReqs) {
            allReqs.forEach((r: any) => {
                excludeSet.add(r.sender_id === userId ? r.receiver_id : r.sender_id);
            });
        }
        if (allConvs) {
            allConvs.forEach((c: any) => {
                excludeSet.add(c.user_a_id === userId ? c.user_b_id : c.user_a_id);
            });
        }

        return users.filter((u: any) => !excludeSet.has(u.id) && u.id !== userId);
    }

    /**
     * Send a conversation request
     */
    static async sendConversationRequest(receiverId: string): Promise<boolean> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return false;

        const { data: existing } = await supabase
            .from('conversation_requests')
            .select('*')
            .eq('sender_id', userId)
            .eq('receiver_id', receiverId)
            .limit(1);

        if (existing && existing.length > 0) return false;

        const { error } = await supabase
            .from('conversation_requests')
            .insert({ sender_id: userId, receiver_id: receiverId, status: 'pending' });

        if (error) throw new Error('İstek gönderilemedi.');
        return true;
    }

    /**
     * Fetch pending requests for user
     */
    static async fetchPendingRequests(): Promise<ConversationRequest[]> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return [];

        const { data: requests, error } = await supabase
            .from('conversation_requests')
            .select('*')
            .eq('receiver_id', userId)
            .eq('status', 'pending')
            .order('created_at', { ascending: false });

        if (error || !requests) throw new Error('İstekler yüklenemedi.');

        const senderIds = requests.map(r => r.sender_id);
        let profileMap: Record<string, UserProfile> = {};

        if (senderIds.length > 0) {
            const { data: profiles } = await supabase.from('profiles').select('*').in('id', senderIds);
            if (profiles) {
                profiles.forEach(p => {
                    profileMap[p.id] = { id: p.id, username: p.username, avatarUrl: p.avatar_url, bio: p.bio, age: p.age };
                });
            }
        }

        return requests.map(r => ({
            id: r.id,
            senderId: r.sender_id,
            receiverId: r.receiver_id,
            status: r.status,
            createdAt: r.created_at,
            senderProfile: profileMap[r.sender_id]
        }));
    }

    static async acceptRequest(request: ConversationRequest): Promise<string | null> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return null;

        const { data: conv, error } = await supabase
            .from('conversations')
            .insert({ user_a_id: request.senderId, user_b_id: userId })
            .select()
            .single();

        if (error) throw new Error('İstek kabul edilemedi.');

        await supabase.from('conversation_requests').delete().eq('id', request.id);
        return conv.id;
    }

    static async rejectRequest(request: ConversationRequest): Promise<void> {
        const { error } = await supabase.from('conversation_requests').delete().eq('id', request.id);
        if (error) throw new Error('İstek reddedilemedi.');
    }

    static async fetchConversations(): Promise<Conversation[]> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) return [];

        const { data: convs, error } = await supabase
            .from('conversations')
            .select(`
                *,
                messages (
                    id,
                    sender_id,
                    content,
                    is_read,
                    created_at
                )
            `)
            .or(`user_a_id.eq.${userId},user_b_id.eq.${userId}`)
            .order('created_at', { ascending: false });

        if (error || !convs) throw new Error('Sohbetler yüklenemedi.');

        const otherIds = convs.map(c => c.user_a_id === userId ? c.user_b_id : c.user_a_id);
        let profileMap: Record<string, UserProfile> = {};

        if (otherIds.length > 0) {
            const { data: profiles } = await supabase.from('profiles').select('*').in('id', otherIds);
            if (profiles) {
                profiles.forEach(p => {
                    profileMap[p.id] = { id: p.id, username: p.username, avatarUrl: p.avatar_url, bio: p.bio, age: p.age };
                });
            }
        }

        return convs.map((c: any) => {
            let lastMessage = undefined;
            if (c.messages && c.messages.length > 0) {
                const sorted = c.messages.sort((a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
                const m = sorted[0];
                lastMessage = {
                    id: m.id,
                    conversationId: c.id,
                    senderId: m.sender_id,
                    content: m.content,
                    isRead: m.is_read,
                    createdAt: m.created_at
                };
            }
            return {
                id: c.id,
                userAId: c.user_a_id,
                userBId: c.user_b_id,
                createdAt: c.created_at,
                otherUser: profileMap[c.user_a_id === userId ? c.user_b_id : c.user_a_id],
                lastMessage
            };
        });
    }

    static async fetchMessages(conversationId: string): Promise<Message[]> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();

        const { data: msgs, error } = await supabase
            .from('messages')
            .select('*')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: true });

        if (error) throw new Error('Mesajlar yüklenemedi.');

        if (userId) {
            await supabase
                .from('messages')
                .update({ is_read: true })
                .eq('conversation_id', conversationId)
                .neq('sender_id', userId)
                .eq('is_read', false);
        }

        return (msgs || []).map(m => ({
            id: m.id,
            conversationId: m.conversation_id,
            senderId: m.sender_id,
            content: m.content,
            isRead: m.is_read,
            createdAt: m.created_at
        }));
    }

    static async sendMessage(conversationId: string, content: string): Promise<Message> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) throw new Error('Giriş yapılmamış.');

        const { data: sent, error } = await supabase
            .from('messages')
            .insert({ conversation_id: conversationId, sender_id: userId, content })
            .select()
            .single();

        if (error) throw new Error('Mesaj gönderilemedi.');
        return {
            id: sent.id,
            conversationId: sent.conversation_id,
            senderId: sent.sender_id,
            content: sent.content,
            isRead: sent.is_read,
            createdAt: sent.created_at
        };
    }

    static async deleteConversation(conversationId: string): Promise<void> {
        const { error } = await supabase.from('conversations').delete().eq('id', conversationId);
        if (error) throw new Error('Sohbet silinemedi.');
    }

    static async deleteMessage(messageId: string): Promise<void> {
        const { error } = await supabase.from('messages').delete().eq('id', messageId);
        if (error) throw new Error('Mesaj silinemedi.');
    }

    static subscribeToMessages(conversationId: string, onNewMessage: (msg: Message) => void) {
        if (this.messageSubscription) {
            this.unsubscribeFromMessages();
        }

        this.messageSubscription = supabase
            .channel(`messages:conversation_id=eq.${conversationId}`)
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${conversationId}` }, (payload) => {
                const m = payload.new;
                onNewMessage({
                    id: m.id,
                    conversationId: m.conversation_id,
                    senderId: m.sender_id,
                    content: m.content,
                    isRead: m.is_read,
                    createdAt: m.created_at
                });
            })
            .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'messages', filter: `conversation_id=eq.${conversationId}` }, (payload) => {
                // A complete implementation would handle deletions dynamically via a callback,
                // but for simpler realtime sync, clients usually just re-fetch or ignore.
            })
            .subscribe();
    }

    static unsubscribeFromMessages() {
        if (this.messageSubscription) {
            supabase.removeChannel(this.messageSubscription);
            this.messageSubscription = null;
        }
    }
}
