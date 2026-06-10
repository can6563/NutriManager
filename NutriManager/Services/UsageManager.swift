import Foundation
import SwiftData

/// AI 식단 생성 횟수 제한(무료 하루 3회)과 결제 해제 상태를 관리한다.
/// 진짜 저장소는 SwiftData의 UsageCounter(날짜별 1행)이다.
@MainActor
final class UsageManager: ObservableObject {
    static let freeDailyLimit = 3

    @Published private(set) var todayCount = 0
    @Published private(set) var isUnlocked = false

    private var context: ModelContext?

    /// 앱 시작 시 모델 컨텍스트를 주입하고 오늘 카운터를 불러온다.
    func configure(_ context: ModelContext) {
        self.context = context
        refresh()
    }

    private var todayKey: Date { Calendar.current.startOfDay(for: Date()) }

    /// 오늘 날짜의 UsageCounter를 가져오거나 없으면 만든다.
    private func todayCounter() -> UsageCounter? {
        guard let context else { return nil }
        let key = todayKey
        let descriptor = FetchDescriptor<UsageCounter>(
            predicate: #Predicate { $0.date == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = UsageCounter(date: key)
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    func refresh() {
        guard let counter = todayCounter() else { return }
        todayCount = counter.aiCount
        isUnlocked = counter.isUnlocked
    }

    /// 무제한이거나 무료 횟수가 남았는지.
    var canGenerate: Bool {
        isUnlocked || todayCount < Self.freeDailyLimit
    }

    /// 오늘 남은 무료 횟수(해제 시 -1로 무제한 표시).
    var remaining: Int {
        isUnlocked ? -1 : max(0, Self.freeDailyLimit - todayCount)
    }

    /// 생성 1회 사용 기록.
    func recordUse() {
        guard let counter = todayCounter() else {
            todayCount += 1
            return
        }
        counter.aiCount += 1
        try? context?.save()
        todayCount = counter.aiCount
    }

    /// 결제(흉내) 성공 시 오늘 무제한 해제.
    func unlockPremium() {
        guard let counter = todayCounter() else {
            isUnlocked = true
            return
        }
        counter.isUnlocked = true
        try? context?.save()
        isUnlocked = true
    }

    /// 데모 편의를 위해 오늘 카운트/해제를 초기화.
    func resetForDemo() {
        guard let counter = todayCounter() else {
            todayCount = 0; isUnlocked = false; return
        }
        counter.aiCount = 0
        counter.isUnlocked = false
        try? context?.save()
        todayCount = 0
        isUnlocked = false
    }
}
