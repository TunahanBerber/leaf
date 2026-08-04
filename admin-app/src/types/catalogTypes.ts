export type CatalogStatus = 'pending' | 'approved';

export interface CatalogBook {
  id: string;
  title: string;
  author: string;
  page_count: number | null;
  language: string | null;
  cover_url: string | null;
  publisher: string | null;
  published_year: string | null;
  added_count: number;
  status: CatalogStatus;
  created_at: string;
}

// düzenleme formu — id ve added_count hariç her alan opsiyonel değişebilir
export type CatalogBookUpdate = Partial<
  Pick<CatalogBook, 'title' | 'author' | 'page_count' | 'language' | 'cover_url' | 'publisher' | 'published_year'>
>;
