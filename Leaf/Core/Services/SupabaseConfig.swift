// SupabaseConfig.swift
// Leaf — Supabase istemci yapılandırması

import Foundation
import Supabase

private enum SupabaseEnv {
    static func string(_ key: String) -> String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            fatalError("Missing Info.plist key: \(key). Check xcconfig setup.")
        }
        return value
    }
}

// Uygulama genelinde tek Supabase istemcisi
// Tüm auth ve veritabanı işlemleri bu nesne üzerinden yapılır
let supabase = SupabaseClient(
    supabaseURL: {
        let urlString = SupabaseEnv.string("SUPABASE_URL")
        guard let url = URL(string: urlString) else {
            fatalError("Invalid SUPABASE_URL: \(urlString)")
        }
        return url
    }(),
    supabaseKey: SupabaseEnv.string("SUPABASE_ANON_KEY")
)
