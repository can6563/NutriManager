import SwiftUI
import SwiftData

/// ① 홈 대시보드 — 예산/소비기한 경고 카드 + 식단 달력.
struct HomeDashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @Query private var ingredients: [Ingredient]
    @Query private var mealPlans: [MealPlan]

    /// 이번 주 식자재 예산(원). 데모용 고정값.
    private let weeklyBudget: Double = 700_000

    @State private var monthAnchor = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCards
                    expiringSection
                    calendarSection
                }
                .padding()
            }
            .navigationTitle("NutriManager")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: 요약 카드

    private var spentThisWeek: Double {
        let cal = Calendar.current
        guard let week = cal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return mealPlans
            .filter { $0.accepted && week.contains($0.date) }
            .reduce(0) { $0 + $1.estimatedCost }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            InfoCard(
                title: "이번 주 남은 예산",
                value: "₩\(Int(weeklyBudget - spentThisWeek).formatted())",
                subtitle: "총 ₩\(Int(weeklyBudget).formatted()) 중 사용 ₩\(Int(spentThisWeek).formatted())",
                systemImage: "wonsign.circle.fill",
                tint: .blue
            )
            InfoCard(
                title: "소비기한 경고",
                value: "\(ExpiryService.expiringCount(ingredients))건",
                subtitle: "소비기한 D-\(ExpiryService.warningThreshold) 이내 재료",
                systemImage: "exclamationmark.triangle.fill",
                tint: ExpiryService.expiringCount(ingredients) > 0 ? .red : .green
            )
        }
    }

    // MARK: 임박 재료

    private var expiringSection: some View {
        let soon = ExpiryService.expiringSoon(ingredients)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "지금 먼저 써야 할 재료", systemImage: "flame.fill")
            if soon.isEmpty {
                Text("임박한 재료가 없습니다. 👍")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(soon) { ing in
                            VStack(alignment: .leading, spacing: 6) {
                                DDayBadge(daysLeft: ing.daysLeft)
                                Text(ing.name).font(.subheadline.bold())
                                Text("\(ing.quantity.clean)\(ing.unit)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(width: 110, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    // MARK: 달력

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: monthTitle, systemImage: "calendar")
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
            }
            weekdayHeader
            CalendarGrid(
                month: monthAnchor,
                plannedDays: plannedDays,
                onSelect: { date in router.openPlanner(for: date) }
            )
            Label("빈 날짜를 누르면 AI 식단 자동 채우기로 이동합니다.", systemImage: "hand.tap.fill")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["일","월","화","수","목","금","토"], id: \.self) { d in
                Text(d).font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 이 달에 식단이 등록된 날짜들(0시 기준).
    private var plannedDays: Set<Date> {
        let cal = Calendar.current
        return Set(mealPlans.map { cal.startOfDay(for: $0.date) })
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: monthAnchor)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }
}

/// 한 달짜리 달력 그리드. 식단 있는 날은 점, 누르면 콜백.
private struct CalendarGrid: View {
    let month: Date
    let plannedDays: Set<Date>
    let onSelect: (Date) -> Void

    private let cal = Calendar.current

    var body: some View {
        let days = makeDays()
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days.indices, id: \.self) { i in
                if let date = days[i] {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday = cal.isDateInToday(date)
        let hasPlan = plannedDays.contains(cal.startOfDay(for: date))
        return Button {
            onSelect(date)
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: date))")
                    .font(.subheadline)
                    .foregroundStyle(isToday ? Color.white : .primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isToday ? Color.accentColor : Color.clear))
                Circle()
                    .fill(hasPlan ? Color.green : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// 달력에 깔 날짜 배열(앞쪽 빈칸은 nil).
    private func makeDays() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let firstWeekday = cal.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }
        let leading = firstWeekday - 1 // 일요일=1 기준 앞 빈칸
        let dayCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<dayCount {
            if let date = cal.date(byAdding: .day, value: d, to: interval.start) {
                cells.append(date)
            }
        }
        return cells
    }
}

extension Double {
    /// 12.0 → "12", 1.5 → "1.5"
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }
}
