import { supabase } from './supabase';
import { BookSearchResult, BookCatalogItem } from '../models';

export class OpenLibraryService {
    /**
     * Merges results prioritizing catalog, then language, then OpenLibrary
     */
    private static mergeAll(
        catalog: BookSearchResult[],
        google: BookSearchResult[],
        openLibrary: BookSearchResult[]
    ): BookSearchResult[] {
        const seen = new Set<string>();
        const merged: BookSearchResult[] = [];

        const normalize = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/gi, '');

        for (const r of catalog) {
            const key = normalize(r.title + r.authorsText);
            if (!seen.has(key)) {
                seen.add(key);
                merged.push(r);
            }
        }

        const rest = [...openLibrary, ...google].sort((a, b) => {
            const aIsOL = a.id.startsWith('ol_');
            const bIsOL = b.id.startsWith('ol_');
            const aIsTurk = a.language === 'tr' || a.language === 'tur';
            const bIsTurk = b.language === 'tr' || b.language === 'tur';
            if (aIsTurk !== bIsTurk) return aIsTurk ? -1 : 1;
            if (aIsOL !== bIsOL) return aIsOL ? -1 : 1;
            return 0;
        });

        for (const r of rest) {
            const key = normalize(r.title + r.authorsText);
            if (!seen.has(key)) {
                seen.add(key);
                merged.push(r);
            }
        }

        return merged;
    }

    static async fetchCatalog(query: string): Promise<BookSearchResult[]> {
        if (!query) return [];
        try {
            const { data, error } = await supabase
                .from('book_catalog')
                .select('*')
                .or(`title.ilike.%${query}%,author.ilike.%${query}%`)
                .order('added_count', { ascending: false })
                .limit(10);

            if (error || !data) return [];

            return data.map((r: any) => ({
                id: `cat_${r.id}`,
                title: r.title,
                authors: r.author ? [r.author] : [],
                pageCount: r.page_count,
                coverURL: r.cover_url,
                highResCoverURL: r.cover_url,
                publisher: r.publisher,
                publishedDate: r.published_year,
                language: r.language,
                authorsText: r.author || ''
            }));
        } catch {
            return [];
        }
    }

    static async fetchGoogle(query: string): Promise<BookSearchResult[]> {
        try {
            const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=20&printType=books`;
            const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
            if (!res.ok) return [];
            const json = await res.json();

            return (json.items || []).map((item: any) => {
                const info = item.volumeInfo;
                if (!info || !info.title) return null;

                const toHTTPS = (s: string) => s ? s.replace('http://', 'https://') : undefined;
                let thumb = toHTTPS(info.imageLinks?.thumbnail);
                let small = toHTTPS(info.imageLinks?.smallThumbnail);
                let highRes = thumb ? thumb.replace('zoom=1', 'zoom=3') : undefined;

                return {
                    id: `gb_${item.id}`,
                    title: info.title,
                    authors: info.authors || [],
                    pageCount: info.pageCount,
                    coverURL: small || thumb,
                    highResCoverURL: highRes || thumb,
                    publisher: info.publisher,
                    publishedDate: info.publishedDate,
                    language: info.language,
                    authorsText: (info.authors || []).join(', ')
                };
            }).filter(Boolean);
        } catch {
            return [];
        }
    }

    static async fetchOpenLibrary(query: string): Promise<BookSearchResult[]> {
        try {
            const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=12&fields=key,title,author_name,number_of_pages_median,cover_i,publisher,first_publish_year,language`;
            const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
            if (!res.ok) return [];
            const json = await res.json();

            return (json.docs || []).map((doc: any) => {
                if (!doc.key || !doc.title) return null;

                let small, large;
                if (doc.cover_i) {
                    small = `https://covers.openlibrary.org/b/id/${doc.cover_i}-M.jpg`;
                    large = `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg`;
                }

                return {
                    id: `ol_${doc.key}`,
                    title: doc.title,
                    authors: doc.author_name || [],
                    pageCount: doc.number_of_pages_median,
                    coverURL: small,
                    highResCoverURL: large,
                    publisher: doc.publisher?.[0],
                    publishedDate: doc.first_publish_year ? String(doc.first_publish_year) : undefined,
                    language: doc.language?.[0],
                    authorsText: (doc.author_name || []).join(', ')
                };
            }).filter(Boolean);
        } catch {
            return [];
        }
    }

    static async performSearch(query: string): Promise<BookSearchResult[]> {
        if (!query.trim()) return [];

        const [catalog, google, openLibrary] = await Promise.all([
            this.fetchCatalog(query),
            this.fetchGoogle(query).catch(() => []),
            this.fetchOpenLibrary(query).catch(() => [])
        ]);

        return this.mergeAll(catalog, google, openLibrary);
    }
}
