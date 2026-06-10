import SwiftUI
import SwiftData

/// ③ AI 식단 기획실 — 예산 슬라이더 · 필수 재료 체크 · 끼니/인원 · 생성.
struct AIPlannerView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var usage: UsageManager

    @Query(sort: \Ingredient.expirationDate) private var ingredients: [Ingredient]
    @Query private var mealPlans: [MealPlan]

    @State private var targetDate = Date()
    @State private var budgetPerServing: Double = 4000
    @State private var headcount = 100
    @State private var selectedMeals: Set<String> = ["중식"]
    @State private var mustUse: Set<String> = []

    @State private var isGenerating = false
    @State private var result: GenerationResult?
    @State private var navigate = false
    @State private var showPaywall = false
    @State private var didAutoSelect = false

    private let mealTypes = ["조식", "중식", "석식"]
    private let service = NutritionAIService()

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                mealSection
                budgetSection
                mustUseSection
                usageSection
            }
            .navigationTitle("AI 식단 기획실")
            .safeAreaInset(edge: .bottom) { generateBar }
            .navigationDestination(isPresented: $navigate) {
                if let result {
                    MealResultView(
                        initial: result,
                        regenerate: regenerate(note:previous:),
                        onAccepted: handleAccepted
                    )
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet {
                    usage.unlockPremium()
                    showPaywall = false
                    Task { await startGeneration() }
                }
            }
            .onAppear(perform: applySeedDateAndAutoSelect)
            .onChange(of: router.plannerSeedDate) { _, _ in applySeedDateAndAutoSelect() }
        }
    }

    // MARK: 섹션들

    private var dateSection: some View {
        Section("날짜") {
            DatePicker("식단 날짜", selection: $targetDate, displayedComponents: .date)
        }
    }

    private var mealSection: some View {
        Section("끼니 선택") {
            HStack {
                ForEach(mealTypes, id: \.self) { meal in
                    let on = selectedMeals.contains(meal)
                    Button {
                        if on { selectedMeals.remove(meal) } else { selectedMeals.insert(meal) }
                    } label: {
                        Text(meal)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(on ? Color.accentColor : Color(.tertiarySystemFill)))
                            .foregroundStyle(on ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Stepper("인원수: \(headcount)명", value: $headcount, in: 1...2000, step: 10)
        }
    }

    private var budgetSection: some View {
        Section("1인분 단가 상한") {
            VStack(alignment: .leading) {
                Text("₩\(Int(budgetPerServing).formatted()) 이하")
                    .font(.headline).foregroundStyle(.accent)
                Slider(value: $budgetPerServing, in: 2000...10000, step: 500)
                HStack {
                    Text("₩2,000").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("₩10,000").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var mustUseSection: some View {
        Section {
            if ingredients.isEmpty {
                Text("재고가 없습니다. 창고 탭에서 재료를 먼저 등록하세요.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(ingredients) { ing in
                    Button {
                        toggleMust(ing.name)
                    } label: {
                        HStack {
                            Image(systemName: mustUse.contains(ing.name) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(mustUse.contains(ing.name) ? .accent : .secondary)
                            Text(ing.name)
                            if ing.isExpiringSoon { DDayBadge(daysLeft: ing.daysLeft) }
                            Spacer()
                            Text("\(ing.quantity.clean)\(ing.unit)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("필수 포함 식자재 (임박 재료는 자동 선택)")
        }
    }

    private var usageSection: some View {
        Section("오늘 AI 사용") {
            HStack {
                Image(systemName: usage.isUnlocked ? "infinity.circle.fill" : "bolt.circle.fill")
                    .foregroundStyle(usage.isUnlocked ? .green : .accent)
                Text(usage.isUnlocked
                     ? "프리미엄: 무제한 생성"
                     : "무료 \(UsageManager.freeDailyLimit)회 중 \(usage.remaining)회 남음")
                Spacer()
            }
        }
    }

    private var generateBar: some View {
        VStack(spacing: 6) {
            if ingredients.isEmpty {
                Text("재고가 비어 생성할 수 없습니다.")
                    .font(.caption).foregroundStyle(.red)
            }
            Button {
                Task { await onTapGenerate() }
            } label: {
                if isGenerating {
                    HStack { ProgressView().tint(.white); Text("식단 생성 중…") }
                } else {
                    Label("식단 생성 시작", systemImage: "wand.and.stars")
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: canGenerate))
            .disabled(!canGenerate || isGenerating)
        }
        .padding()
        .background(.bar)
    }

    // MARK: 로직

    private var canGenerate: Bool {
        !ingredients.isEmpty && !selectedMeals.isEmpty
    }

    private func toggleMust(_ name: String) {
        if mustUse.contains(name) { mustUse.remove(name) } else { mustUse.insert(name) }
    }

    /// 진입 시 홈에서 넘겨준 날짜 적용 + 임박 재료 자동 체크(1회).
    private func applySeedDateAndAutoSelect() {
        if let seed = router.plannerSeedDate {
            targetDate = seed
            router.plannerSeedDate = nil
        }
        if !didAutoSelect {
            for ing in ingredients where ing.isExpiringSoon {
                mustUse.insert(ing.name)
            }
            didAutoSelect = true
        }
    }

    private func onTapGenerate() async {
        guard canGenerate else { return }
        // 무료 횟수 초과 → 결제 시트.
        guard usage.canGenerate else {
            showPaywall = true
            return
        }
        await startGeneration()
    }

    private func orderedMeals() -> [String] {
        mealTypes.filter { selectedMeals.contains($0) }
    }

    private func currentRequest() -> PlanRequest {
        PlanRequest(
            date: Calendar.current.startOfDay(for: targetDate),
            mealTypes: orderedMeals(),
            budgetPerServing: budgetPerServing,
            headcount: headcount,
            mustUse: Array(mustUse)
        )
    }

    private func startGeneration() async {
        isGenerating = true
        defer { isGenerating = false }
        let request = currentRequest()
        let output = await service.generate(
            request: request,
            inventory: ingredients,
            recentPlans: mealPlans
        )
        usage.recordUse()
        result = output
        navigate = true
    }

    /// 결과 화면의 "일부만 고쳐서 다시 검색" → 직전 결과를 맥락으로 재요청.
    private func regenerate(note: String, previous: [MealSuggestion]) async -> GenerationResult {
        let request = currentRequest()
        let output = await service.generate(
            request: request,
            inventory: ingredients,
            recentPlans: mealPlans,
            previousResult: previous,
            revisionNote: note
        )
        usage.recordUse()
        return output
    }

    /// 결과 수락 → MealPlan 저장.
    private func handleAccepted(_ meals: [MealSuggestion], _ request: PlanRequest) {
        for meal in meals {
            let plan = MealPlan(
                date: request.date,
                mealType: meal.mealType,
                dishes: meal.dishes,
                usedIngredients: meal.usedIngredients,
                estimatedCost: meal.estimatedCost,
                accepted: true
            )
            context.insert(plan)
        }
        try? context.save()
        navigate = false
        router.selectedTab = .home
    }
}
