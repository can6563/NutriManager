import Foundation
import SwiftData

/// 긴급 발주 연락망에 표시되는 도매업체. 거래 중개는 하지 않고 단순 표시만 한다.
@Model
final class Supplier {
    var id: UUID
    var name: String
    var region: String
    var phone: String
    /// 채소 / 육류 / 수산 / 곡물 / 유제품 / 종합
    var category: String

    init(
        id: UUID = UUID(),
        name: String,
        region: String,
        phone: String,
        category: String
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.phone = phone
        self.category = category
    }
}
