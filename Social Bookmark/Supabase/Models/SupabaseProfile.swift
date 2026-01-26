import Foundation

/// Supabase'deki 'profiles' tablosu ile eşleşen model
struct SupabaseProfile: Codable, Identifiable {
    let id: UUID
    let is_pro: Bool?
    let created_at: Date?
    let updated_at: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case is_pro
        case created_at
        case updated_at
    }
}
