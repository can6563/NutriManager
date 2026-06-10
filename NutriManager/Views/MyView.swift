import SwiftUI
import SwiftData

/// ⑤ 마이 — AI 사용 현황 / 프리미엄 상태 / 데모 리셋 / 앱 정보.
struct MyView: View {
    @EnvironmentObject private var usage: UsageManager
    @Query private var mealPlans: [MealPlan]
    @Query private var ingredients: [Ingredient]

    @State private var showPaywall = false
    @State private var toastMessage: String?

    private var acceptedCount: Int { mealPlans.filter { $0.accepted }.count }

    var body: some View {
        NavigationStack {
            List {
                Section("AI 사용 현황") {
                    row("오늘 사용 횟수", "\(usage.isUnlocked ? "무제한" : "\(UsageManager.freeDailyLimit - usage.remaining)/\(UsageManager.freeDailyLimit)회")", "bolt.fill")
                    row("프리미엄 상태", usage.isUnlocked ? "해제됨" : "미해제", "crown.fill")
                    if !usage.isUnlocked {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("프리미엄 해제하기", systemImage: "crown.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("요약") {
                    row("등록 재료", "\(ingredients.count)종", "shippingbox.fill")
                    row("저장된 식단", "\(acceptedCount)건", "calendar")
                    row("임박 재료", "\(ExpiryService.expiringCount(ingredients))건", "exclamationmark.triangle.fill")
                }

                Section("데모 도구") {
                    Button {
                        usage.resetForDemo()
                        toastMessage = "오늘 사용량을 초기화했습니다"
                    } label: {
                        Label("AI 사용 횟수 초기화", systemImage: "arrow.counterclockwise")
                    }
                }

                Section("앱 정보") {
                    row("앱 이름", "NutriManager", "app.badge")
                    row("버전", "1.0.0", "number")
                    Text("영양사·조리사를 위한 재고·소비기한 관리 + AI 식단 생성 앱. 모든 데이터는 기기 안(SwiftData)에만 저장됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("마이")
            .sheet(isPresented: $showPaywall) {
                PaywallSheet {
                    usage.unlockPremium()
                    showPaywall = false
                    toastMessage = "프리미엄이 해제되었습니다"
                }
            }
            .toast($toastMessage)
        }
    }

    private func row(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
