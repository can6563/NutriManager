import Foundation

/// 재고 + 최근 메뉴 + 생성 조건을 AI가 먹기 좋은 텍스트로 조립한다.
/// 환각 억제를 위해 "이 재료만 써라 / 임박 우선 / 최근 메뉴 중복금지 / JSON으로만 답하라"를 강제한다.
enum PromptBuilder {

    /// 모든 요청에 공통으로 붙는 규칙(시스템 인스트럭션).
    /// JSON 형식은 responseSchema(구조화 출력)가 강제하므로, 여기서는 내용·표현 규칙만 담아 간결하게.
    static func systemInstruction() -> String {
        """
        너는 한국 단체급식 영양사다. 규칙:
        1. inventory에 있는 재료만 쓴다. 없는 재료를 지어내지 않는다.
        2. daysLeft가 작은(임박) 재료를 우선 소진한다.
        3. recentDishes에 이미 나온 메뉴와 겹치지 않게 새로 짠다.
        4. 1인분 단가를 budgetPerServing(원) 이하로 맞춘다.
        5. mustUse 재료는 가능한 한 포함한다.
        6. 각 끼니(mealTypes)는 밥 1 + 국 1 + 반찬 2~3개로, 메뉴마다 별도로 적는다.
        7. 메뉴 이름은 급식 표준 명칭으로 짧고 자연스럽게 쓴다(예: 현미밥, 닭가슴살구이, 시금치나물).
           여러 재료를 한 요리명으로 억지로 합치지 않고, 설명·수식어를 붙이지 않는다.
        """
    }

    /// 이번 요청의 사용자 메시지(재고/메뉴/조건을 JSON 텍스트로).
    /// - Parameter previousResult: "이거 빼고 다시" 재검색 시 직전 결과를 맥락으로 함께 보낸다.
    static func userMessage(
        request: PlanRequest,
        inventory: [Ingredient],
        recentDishes: [String],
        previousResult: [MealSuggestion]? = nil,
        revisionNote: String? = nil
    ) -> String {
        let inventoryJSON = inventory.map { ing in
            """
            {"name":"\(esc(ing.name))","quantity":\(ing.quantity),"unit":"\(esc(ing.unit))","daysLeft":\(ing.daysLeft),"cost":\(Int(ing.cost)),"category":"\(esc(ing.category))"}
            """
        }.joined(separator: ",")

        let recentJSON = recentDishes.map { "\"\(esc($0))\"" }.joined(separator: ",")
        let mealsJSON = request.mealTypes.map { "\"\(esc($0))\"" }.joined(separator: ",")
        let mustJSON = request.mustUse.map { "\"\(esc($0))\"" }.joined(separator: ",")

        var message = """
        다음 조건으로 식단을 설계해줘. 반드시 JSON 스키마로만 답해.

        request = {
          "mealTypes": [\(mealsJSON)],
          "headcount": \(request.headcount),
          "budgetPerServing": \(Int(request.budgetPerServing)),
          "mustUse": [\(mustJSON)]
        }

        inventory = [\(inventoryJSON)]

        recentDishes = [\(recentJSON)]
        """

        if let previousResult, let revisionNote {
            let prevJSON = previousResult.map { m in
                "{\"mealType\":\"\(esc(m.mealType))\",\"dishes\":[\(m.dishes.map { "\"\(esc($0))\"" }.joined(separator: ","))]}"
            }.joined(separator: ",")
            message += """


            // 직전에 생성한 식단(맥락):
            previousResult = [\(prevJSON)]
            // 수정 요청: \(revisionNote)
            // 위 previousResult의 메뉴와 최대한 다르게, 위 수정 요청을 반영해서 다시 짜줘.
            """
        }

        return message
    }

    /// 최근 2주간 식단에서 나온 메뉴 이름을 중복 제거해 모은다.
    static func recentDishes(from plans: [MealPlan], within days: Int = 14) -> [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var set = Set<String>()
        var ordered: [String] = []
        for plan in plans where plan.date >= cutoff {
            for dish in plan.dishes where !set.contains(dish) {
                set.insert(dish)
                ordered.append(dish)
            }
        }
        return ordered
    }

    /// JSON 문자열 안전 처리(따옴표/역슬래시 이스케이프).
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
