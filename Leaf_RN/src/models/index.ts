export interface BookNote {
    id: string;
    userId?: string;
    bookId: string;
    title: string;
    content: string;
    pageNumber?: number;
    createdAt: string; // ISO 8601 string
    updatedAt: string; // ISO 8601 string
}

export interface Book {
    id: string;
    userId?: string;
    title: string;
    author: string;
    coverImageUrl?: string;
    totalPages: number;
    currentPage: number;
    isWishlist: boolean;
    createdAt: string;
    updatedAt: string;
    notes: BookNote[];
}

export interface UserProfile {
    id: string; // Mapped from "profile_id" or "id"
    username: string;
    avatarUrl?: string;
    bio?: string;
    age?: number;
    commonBookTitles?: string[];
}

export interface Conversation {
    id: string;
    userAId: string;
    userBId: string;
    createdAt: string;
    otherUser?: UserProfile;
    lastMessage?: Message;
}

export interface ConversationRequest {
    id: string;
    senderId: string;
    receiverId: string;
    status: 'pending' | 'accepted' | 'rejected' | string;
    createdAt: string;
    senderProfile?: UserProfile;
}

export interface Message {
    id: string;
    conversationId: string;
    senderId: string;
    content: string;
    isRead: boolean;
    createdAt: string;
}

export interface BookSearchResult {
    id: string;
    title: string;
    authors: string[];
    pageCount?: number;
    coverURL?: string;
    highResCoverURL?: string;
    publisher?: string;
    publishedDate?: string;
    language?: string;
    authorsText: string;
}

export interface BookCatalogItem {
    id?: string;
    title: string;
    author: string;
    pageCount?: number;
    language?: string;
    coverUrl?: string; // stored as public url or storage path depending on context
    publisher?: string;
    publishedYear?: string;
    addedCount: number;
}
