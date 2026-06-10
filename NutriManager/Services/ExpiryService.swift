import Foundation
import SwiftUI

/// 소비기한(D-day) 계산과 임박 재료 필터링을 담당하는 순수 로직 모음.
enum ExpiryService {
    /// 임박 기준(일). 이 값 이하이면 "임박"으로 본다.
    static let warningThreshold = 3

    static func daysLeft(until date: Date, from reference: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: reference)
        let end = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 소비기한 임박(또는 경과) 재료만 골라 임박 순으로 정렬.
    static func expiringSoon(_ items: [Ingredient]) -> [Ingredient] {
        items.filter { $0.daysLeft <= warningThreshold }
            .sorted { $0.daysLeft < $1.daysLeft }
    }

    static func expiringCount(_ items: [Ingredient]) -> Int {
        items.filter { $0.daysLeft <= warningThreshold }.count
    }

    /// D-day 뱃지에 쓸 색상. 경과/임박=빨강, 일주일 이내=주황, 그 외=초록.
    static func color(forDaysLeft days: Int) -> Color {
        if days <= warningThreshold { return .red }
        if days <= 7 { return .orange }
        return .green
    }

    /// "D-3", "D-DAY", "D+2"(경과) 형태의 라벨.
    static func ddayLabel(forDaysLeft days: Int) -> String {
        if days == 0 { return "D-DAY" }
        if days < 0 { return "D+\(-days)" }
        return "D-\(days)"
    }
}
