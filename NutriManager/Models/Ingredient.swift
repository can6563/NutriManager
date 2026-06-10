import Foundation
import SwiftData

/// 식자재(재고) 모델. 온디바이스(SwiftData)에만 저장된다.
@Model
final class Ingredient {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    /// 소비기한
    var expirationDate: Date
    /// 원가(민감정보) — 화면에서는 권한/맥락에 따라 노출.
    var cost: Double
    var supplierName: String?
    var supplierContact: String?
    /// 채소/육류/수산/곡물/유제품/기타
    var category: String

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String,
        expirationDate: Date,
        cost: Double,
        supplierName: String? = nil,
        supplierContact: String? = nil,
        category: String = "기타"
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.expirationDate = expirationDate
        self.cost = cost
        self.supplierName = supplierName
        self.supplierContact = supplierContact
        self.category = category
    }

    /// 오늘 0시 기준, 소비기한까지 남은 일수. 음수면 이미 지난 것.
    var daysLeft: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: expirationDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 3일 이내(또는 이미 지난) 임박 재료인지.
    var isExpiringSoon: Bool { daysLeft <= 3 }
}
