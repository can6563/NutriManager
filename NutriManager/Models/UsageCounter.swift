import Foundation
import SwiftData

/// AI 식단 생성 사용 횟수. 날짜(0시)를 키로 하루 단위로 집계한다.
/// 규칙: 무료 하루 3회, 초과 시 결제(흉내)로 해제.
@Model
final class UsageCounter {
    /// 해당 날짜의 0시 (하루 키)
    @Attribute(.unique) var date: Date
    var aiCount: Int
    /// 결제로 무제한 해제했는지
    var isUnlocked: Bool

    init(date: Date, aiCount: Int = 0, isUnlocked: Bool = false) {
        self.date = date
        self.aiCount = aiCount
        self.isUnlocked = isUnlocked
    }
}
