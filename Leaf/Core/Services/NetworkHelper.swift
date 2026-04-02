// NetworkHelper.swift
// Leaf — Ağ Hataları için Yük Devredici (Retry & Backoff)

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case badResponse(statusCode: Int)
    case maxRetriesReached(lastError: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz arama isteği."
        case .badResponse(let code): return "Sunucu hatası: \(code). Daha sonra tekrar deneyin."
        case .maxRetriesReached: return "İnternet bağlantınız zayıf, lütfen tekrar deneyin."
        }
    }
}

actor NetworkHelper {
    
    /// Exponential backoff ile ağ isteklerini yeniden dener
    /// - Parameters:
    ///   - maxRetries: Maksimum deneme sayısı
    ///   - initialDelay: İlk hata sonrası bekleme süresi (saniye)
    ///   - backoffFactor: Bekleme süresinin ne kadar kat kat artacağı
    ///   - operation: Yapılacak ağ isteği closure'u
    static func retry<T>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffFactor: Double = 2.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var retries = 0
        var currentDelay = initialDelay
        
        while true {
            do {
                if Task.isCancelled { throw CancellationError() }
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if retries >= maxRetries {
                    throw NetworkError.maxRetriesReached(lastError: error)
                }
                
                // Exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                
                retries += 1
                currentDelay *= backoffFactor
            }
        }
    }
}
