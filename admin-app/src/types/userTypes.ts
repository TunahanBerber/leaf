export interface Profile {
  id: string;
  username: string;
  bio: string | null;
  age: number | null;
  created_at: string | null;
}

export interface AdminUser extends Profile {
  email: string | null;
  isBanned: boolean;
}
