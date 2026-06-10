import SwiftUI

/// ④ 추천 식단 결과 — 끼니별 카드 + 수락 + "일부만 고쳐서 다시 검색".
struct MealResultView: View {
    let initial: GenerationResult
    /// (수정요청, 직전결과) → 새 결과
    let regenerate: (String, [MealSuggestion]) async -> GenerationResult
    let onAccepted: ([MealSuggestion], PlanRequest) -> Void

    @State private var meals: [MealSuggestion] = []
    @State private var source: GenerationSource = .ai
    @State private var isWorking = false
    @State private var showReviseSheet = false
    @State private var reviseNote = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if source.isFallback { fallbackBanner }
                ForEach(meals) { meal in
                    mealCard(meal)
                }
                actionButtons
            }
            .padding()
        }
        .navigationTitle("추천 식단")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .overlay { if isWorking { loadingOverlay } }
        .sheet(isPresented: $showReviseSheet) { reviseSheet }
        .onAppear {
            if meals.isEmpty {
                meals = initial.meals
                source = initial.source
            }
        }
    }

    // MARK: 출처 안내

    private var fallbackBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 연결 실패 → 오프라인 추천으로 대체했어요")
                    .font(.subheadline.weight(.semibold))
                if case .fallback(let reason) = source {
                    Text(reason).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
    }

    // MARK: 끼니 카드

    private func mealCard(_ meal: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(meal.mealType, systemImage: "fork.knife")
                    .font(.headline).foregroundStyle(.accent)
                Spacer()
                Text("1인분 ₩\(Int(meal.estimatedCost).formatted())")
                    .font(.subheadline.weight(.semibold))
            }
            Divider()
            ForEach(meal.dishes, id: \.self) { dish in
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.secondary)
                    Text(dish).font(.body)
                }
            }
            if !meal.usedIngredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(meal.usedIngredients, id: \.self) { ing in
                            TagChip(text: "\(ing) 소진", systemImage: "leaf.fill", tint: .green)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }

    // MARK: 액션

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onAccepted(meals, initial.request)
            } label: {
                Label("수락 — 달력에 반영", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                reviseNote = ""
                showReviseSheet = true
            } label: {
                Label("일부분만 고쳐서 다시 검색", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor, lineWidth: 1.5))
            }
            .disabled(isWorking)
        }
        .padding(.top, 4)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                Text("다시 생성 중…").font(.subheadline)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        }
    }

    // MARK: 재검색 시트

    private var reviseSheet: some View {
        NavigationStack {
            Form {
                Section("무엇을 바꿀까요?") {
                    TextField("예: 닭가슴살 메뉴 빼줘 / 더 저렴하게", text: $reviseNote, axis: .vertical)
                        .lineLimit(3...5)
                }
                Section {
                    Button {
                        Task { await runRevision() }
                    } label: {
                        Label("이 조건으로 다시 생성", systemImage: "wand.and.stars")
                    }
                    .disabled(reviseNote.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("식단 수정 요청")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showReviseSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func runRevision() async {
        let note = reviseNote
        showReviseSheet = false
        isWorking = true
        defer { isWorking = false }
        let output = await regenerate(note, meals)
        meals = output.meals
        source = output.source
    }
}
