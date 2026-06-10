import Foundation
import SwiftData

/// 데모용 초기 데이터. 빈 화면이면 채점자가 효용성을 못 느끼므로 미리 채워둔다.
/// 재료 10개(소비기한 임박 섞음) · 최근 2주 메뉴 · 업체 5개.
enum SampleData {

    /// 저장된 데이터가 하나도 없을 때만 시드한다.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        guard existing.isEmpty else { return }

        seedIngredients(context)
        seedSuppliers(context)
        seedRecentMeals(context)
        try? context.save()
    }

    private static func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }

    private static func seedIngredients(_ context: ModelContext) {
        let items: [Ingredient] = [
            Ingredient(name: "닭가슴살", quantity: 8, unit: "kg", expirationDate: day(1), cost: 12000, supplierName: "건강유통", supplierContact: "02-111-2222", category: "육류"),
            Ingredient(name: "시금치", quantity: 3, unit: "단", expirationDate: day(2), cost: 3000, supplierName: "초록농산", supplierContact: "031-222-3333", category: "채소"),
            Ingredient(name: "두부", quantity: 20, unit: "모", expirationDate: day(3), cost: 1500, supplierName: "콩사랑", supplierContact: "02-333-4444", category: "기타"),
            Ingredient(name: "계란", quantity: 180, unit: "개", expirationDate: day(5), cost: 300, supplierName: "행복란", supplierContact: "041-444-5555", category: "기타"),
            Ingredient(name: "돼지고기", quantity: 10, unit: "kg", expirationDate: day(4), cost: 9000, supplierName: "한돈마트", supplierContact: "02-555-6666", category: "육류"),
            Ingredient(name: "감자", quantity: 15, unit: "kg", expirationDate: day(12), cost: 2500, supplierName: "초록농산", supplierContact: "031-222-3333", category: "채소"),
            Ingredient(name: "양파", quantity: 18, unit: "kg", expirationDate: day(20), cost: 2000, supplierName: "초록농산", supplierContact: "031-222-3333", category: "채소"),
            Ingredient(name: "현미", quantity: 30, unit: "kg", expirationDate: day(90), cost: 3500, supplierName: "건강곡물", supplierContact: "063-666-7777", category: "곡물"),
            Ingredient(name: "고등어", quantity: 6, unit: "kg", expirationDate: day(2), cost: 7000, supplierName: "동해수산", supplierContact: "051-777-8888", category: "수산"),
            Ingredient(name: "버섯", quantity: 4, unit: "kg", expirationDate: day(6), cost: 4000, supplierName: "초록농산", supplierContact: "031-222-3333", category: "채소")
        ]
        items.forEach { context.insert($0) }
    }

    private static func seedSuppliers(_ context: ModelContext) {
        let suppliers: [Supplier] = [
            Supplier(name: "건강유통", region: "서울 송파", phone: "02-111-2222", category: "육류"),
            Supplier(name: "초록농산", region: "경기 성남", phone: "031-222-3333", category: "채소"),
            Supplier(name: "동해수산", region: "부산 중구", phone: "051-777-8888", category: "수산"),
            Supplier(name: "건강곡물", region: "전북 전주", phone: "063-666-7777", category: "곡물"),
            Supplier(name: "행복란", region: "충남 천안", phone: "041-444-5555", category: "종합")
        ]
        suppliers.forEach { context.insert($0) }
    }

    private static func seedRecentMeals(_ context: ModelContext) {
        // 최근 2주간 이미 나온 메뉴 — AI/폴백이 중복을 피하도록.
        let plans: [MealPlan] = [
            MealPlan(date: day(-1), mealType: "중식", dishes: ["흰쌀밥", "제육볶음", "콩나물국"], usedIngredients: ["돼지고기"], estimatedCost: 3500, accepted: true),
            MealPlan(date: day(-2), mealType: "중식", dishes: ["현미밥", "고등어 조림", "시금치 나물"], usedIngredients: ["고등어", "시금치"], estimatedCost: 3800, accepted: true),
            MealPlan(date: day(-3), mealType: "중식", dishes: ["잡곡밥", "돈까스", "양배추 샐러드"], usedIngredients: ["돼지고기"], estimatedCost: 4200, accepted: true),
            MealPlan(date: day(-4), mealType: "중식", dishes: ["흰쌀밥", "계란찜", "감자조림"], usedIngredients: ["계란", "감자"], estimatedCost: 3000, accepted: true),
            MealPlan(date: day(-5), mealType: "중식", dishes: ["현미밥", "두부조림", "미역국"], usedIngredients: ["두부"], estimatedCost: 2800, accepted: true)
        ]
        plans.forEach { context.insert($0) }
    }
}
