import SwiftUI
import SwiftData

/// ② 창고 관리 / 전수조사 — 임박순 리스트 + 스텝퍼 + 저장 토스트 + 추가 폼.
struct InventoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Ingredient.expirationDate, order: .forward) private var ingredients: [Ingredient]

    @State private var toastMessage: String?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if ingredients.isEmpty {
                    ContentUnavailableView(
                        "재고가 비어 있습니다",
                        systemImage: "shippingbox",
                        description: Text("오른쪽 위 + 버튼으로 식자재를 추가하세요.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("창고 / 전수조사")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: { Image(systemName: "plus") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    saveAll()
                } label: {
                    Label("전수조사 완료", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .background(.bar)
            }
            .sheet(isPresented: $showAddSheet) {
                AddIngredientSheet { newItem in
                    context.insert(newItem)
                    try? context.save()
                    toastMessage = "추가되었습니다"
                }
            }
            .toast($toastMessage)
        }
    }

    private var list: some View {
        List {
            ForEach(ingredients) { ing in
                IngredientRow(ingredient: ing)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.insetGrouped)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(ingredients[index]) }
        try? context.save()
        toastMessage = "삭제되었습니다"
    }

    private func saveAll() {
        try? context.save()
        toastMessage = "저장되었습니다"
    }
}

/// 재료 한 행: 이름·수량·[-][+] 스텝퍼·D-day 뱃지.
private struct IngredientRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var ingredient: Ingredient

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(ingredient.name).font(.body.weight(.semibold))
                    DDayBadge(daysLeft: ingredient.daysLeft)
                }
                Text("\(ingredient.category) · 원가 ₩\(Int(ingredient.cost).formatted())")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 14) {
                Button {
                    // 음수 수량 금지(오류 정정).
                    ingredient.quantity = max(0, ingredient.quantity - 1)
                    try? context.save()
                } label: { Image(systemName: "minus.circle.fill") }
                    .disabled(ingredient.quantity <= 0)

                Text("\(ingredient.quantity.clean)\(ingredient.unit)")
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 52)

                Button {
                    ingredient.quantity += 1
                    try? context.save()
                } label: { Image(systemName: "plus.circle.fill") }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
            .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

/// 새 재료 추가 폼. 빈 이름/음수 수량 등을 막는다(오류 정정).
private struct AddIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Ingredient) -> Void

    @State private var name = ""
    @State private var quantity = 1.0
    @State private var unit = "kg"
    @State private var expiration = Date()
    @State private var cost = 0.0
    @State private var supplierName = ""
    @State private var supplierContact = ""
    @State private var category = "채소"

    private let units = ["kg", "g", "개", "모", "단", "L", "박스"]
    private let categories = ["채소", "육류", "수산", "곡물", "유제품", "기타"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름 (예: 닭가슴살)", text: $name)
                    HStack {
                        Text("수량")
                        Spacer()
                        TextField("수량", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Picker("", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                    }
                    Picker("분류", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    DatePicker("소비기한", selection: $expiration, displayedComponents: .date)
                }
                Section("원가 / 공급처") {
                    HStack {
                        Text("원가(₩)")
                        Spacer()
                        TextField("0", value: $cost, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("공급처 이름", text: $supplierName)
                    TextField("공급처 연락처", text: $supplierContact)
                        .keyboardType(.phonePad)
                }
                if !isValid {
                    Text("이름을 입력하고 수량은 0 이상이어야 합니다.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle("재료 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        onAdd(Ingredient(
                            name: name.trimmingCharacters(in: .whitespaces),
                            quantity: max(0, quantity),
                            unit: unit,
                            expirationDate: expiration,
                            cost: max(0, cost),
                            supplierName: supplierName.isEmpty ? nil : supplierName,
                            supplierContact: supplierContact.isEmpty ? nil : supplierContact,
                            category: category
                        ))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
