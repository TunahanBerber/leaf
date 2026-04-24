import { supabase } from './supabase';
import { Book, BookNote, BookCatalogItem } from '../models';

export class BookStoreService {
    private static readonly BUCKET_NAME = 'book-covers';

    static async fetchAllBooks(): Promise<Book[]> {
        const { data: session } = await supabase.auth.getSession();
        if (!session?.session) return [];

        const { data: records, error } = await supabase
            .from('books')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw new Error(`Kitaplar yüklenemedi: ${error.message}`);

        return (records || []).map(r => ({
            id: r.id,
            userId: r.user_id,
            title: r.title,
            author: r.author,
            coverImageUrl: r.cover_image_url,
            totalPages: r.total_pages,
            currentPage: r.current_page,
            isWishlist: r.is_wishlist,
            createdAt: r.created_at,
            updatedAt: r.updated_at,
            notes: []
        }));
    }

    static async fetchNotes(bookId: string): Promise<BookNote[]> {
        const { data: records, error } = await supabase
            .from('book_notes')
            .select('*')
            .eq('book_id', bookId)
            .order('created_at', { ascending: false });

        if (error) throw new Error(`Notlar yüklenemedi: ${error.message}`);

        return (records || []).map(r => ({
            id: r.id,
            userId: r.user_id,
            bookId: r.book_id,
            title: r.title,
            content: r.content,
            pageNumber: r.page_number,
            createdAt: r.created_at,
            updatedAt: r.updated_at
        }));
    }

    // Cover uploading not implemented fully for RN here but skeleton provided
    static async uploadCover(data: any, path: string): Promise<string | undefined> {
        // In RN, you usually upload FormData or array buffer from ImagePicker
        try {
            const { error } = await supabase.storage
                .from(this.BUCKET_NAME)
                .upload(path, data, {
                    cacheControl: '3600',
                    upsert: true,
                    contentType: 'image/jpeg'
                });

            if (error) throw error;
            return path;
        } catch (e) {
            console.log(`❌ Kapak yüklenemedi [${path}]:`, e);
            return undefined;
        }
    }

    static async addBook(params: {
        title: string;
        author: string;
        coverImageData?: any;
        coverImageUrl?: string | null;
        totalPages: number;
        isWishlist: boolean;
        fromCatalog?: boolean;
        language?: string;
        publisher?: string;
        publishedYear?: string;
    }): Promise<Book> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) throw new Error("Giriş yapılmamış");

        const bookId = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2);
        let coverUrl: string | undefined = params.coverImageUrl || undefined;

        if (params.coverImageData) {
            coverUrl = await this.uploadCover(params.coverImageData, `${userId}/${bookId}`);
        }

        const record = {
            id: bookId,
            user_id: userId,
            title: params.title,
            author: params.author,
            cover_image_url: coverUrl,
            total_pages: params.totalPages,
            current_page: 0,
            is_wishlist: params.isWishlist,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
        };

        const { data: saved, error } = await supabase
            .from('books')
            .insert(record)
            .select()
            .single();

        if (error) throw new Error(`Kitap eklenemedi: ${error.message}`);

        if (params.fromCatalog) {
            await this.addToCatalog({
                title: params.title,
                author: params.author,
                pageCount: params.totalPages > 0 ? params.totalPages : undefined,
                language: params.language,
                coverUrl: coverUrl,
                publisher: params.publisher,
                publishedYear: params.publishedYear
            });
        }

        return {
            id: saved.id,
            userId: saved.user_id,
            title: saved.title,
            author: saved.author,
            coverImageUrl: saved.cover_image_url,
            totalPages: saved.total_pages,
            currentPage: saved.current_page,
            isWishlist: saved.is_wishlist,
            createdAt: saved.created_at,
            updatedAt: saved.updated_at,
            notes: []
        };
    }

    private static async addToCatalog(params: any): Promise<void> {
        let publicCoverUrl = null;
        if (params.coverUrl) {
            publicCoverUrl = `https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/book-covers/${params.coverUrl}`;
        }

        const entry = {
            title: params.title,
            author: params.author,
            page_count: params.pageCount,
            language: params.language,
            cover_url: publicCoverUrl,
            publisher: params.publisher,
            published_year: params.publishedYear
        };

        await supabase.from('book_catalog').insert(entry);
        await this.incrementCatalogCount(params.title, params.author);
    }

    private static async incrementCatalogCount(title: string, author: string): Promise<void> {
        await supabase.rpc('increment_book_catalog', { p_title: title, p_author: author });
    }

    static async updateBook(book: Book, newCoverData?: any): Promise<Book> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();
        if (!userId) throw new Error("Giriş yapılmamış");

        let coverUrl: string | undefined = book.coverImageUrl;
        if (newCoverData) {
            coverUrl = await this.uploadCover(newCoverData, `${userId}/${book.id}`);
        }

        const record = {
            title: book.title,
            author: book.author,
            cover_image_url: coverUrl,
            total_pages: book.totalPages,
            current_page: book.currentPage,
            is_wishlist: book.isWishlist,
            updated_at: new Date().toISOString()
        };

        const { error } = await supabase
            .from('books')
            .update(record)
            .eq('id', book.id);

        if (error) throw new Error(`Kitap güncellenemedi: ${error.message}`);
        return { ...book, ...record, coverImageUrl: coverUrl || undefined, updatedAt: record.updated_at, isWishlist: record.is_wishlist, totalPages: record.total_pages, currentPage: record.current_page };
    }

    static async deleteBook(bookId: string): Promise<void> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();

        const { error } = await supabase.from('books').delete().eq('id', bookId);
        if (error) throw new Error(`Kitap silinemedi: ${error.message}`);

        if (userId) {
            await supabase.storage.from(this.BUCKET_NAME).remove([`${userId}/${bookId}`]);
        }
    }

    static async addNote(title: string, content: string, pageNumber: number | null, bookId: string): Promise<BookNote> {
        const { data: session } = await supabase.auth.getSession();
        const userId = session?.session?.user.id.toLowerCase();

        const record = {
            user_id: userId,
            book_id: bookId,
            title,
            content,
            page_number: pageNumber,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };

        const { data, error } = await supabase.from('book_notes').insert(record).select().single();
        if (error) throw new Error(`Not eklenemedi: ${error.message}`);
        return {
            id: data.id,
            userId: data.user_id,
            bookId: data.book_id,
            title: data.title,
            content: data.content,
            pageNumber: data.page_number,
            createdAt: data.created_at,
            updatedAt: data.updated_at
        };
    }

    static async deleteNote(noteId: string): Promise<void> {
        const { error } = await supabase.from('book_notes').delete().eq('id', noteId);
        if (error) throw new Error(`Not silinemedi: ${error.message}`);
    }

    static async fetchRecommendation(alreadySeen: Set<string> = new Set(), userBookTitles: string[] = []): Promise<BookCatalogItem | null> {
        try {
            const { data: items } = await supabase
                .from('book_catalog')
                .select('*')
                .order('added_count', { ascending: false })
                .limit(50);

            if (!items || items.length === 0) return null;

            const userTitlesSet = new Set(userBookTitles.map(t => t.toLowerCase()));
            const seenTitlesSet = new Set([...alreadySeen].map(t => t.toLowerCase()));

            const allExcludedString = Array.from(userTitlesSet).concat(Array.from(seenTitlesSet));

            const catalogItems: BookCatalogItem[] = items.map(r => ({
                id: r.id,
                title: r.title,
                author: r.author,
                pageCount: r.page_count,
                language: r.language,
                coverUrl: r.cover_url,
                publisher: r.publisher,
                publishedYear: r.published_year,
                addedCount: r.added_count
            }));

            // Find first unseen and not in collection
            let pick = catalogItems.find(i => !allExcludedString.includes(i.title.toLowerCase()));
            if (pick) return pick;

            // Fallback: Just not in collection
            pick = catalogItems.find(i => !userTitlesSet.has(i.title.toLowerCase()));
            if (pick) return pick;

            // Fallback: Random
            return catalogItems[Math.floor(Math.random() * catalogItems.length)];
        } catch {
            return null;
        }
    }
}
