import Foundation

// MARK: - 식단 생성 입력/출력 공통 타입

/// 식단 생성 요청 조건. 기획실 화면에서 만들어 생성기로 넘긴다.
struct PlanRequest {
    /// 생성 대상 날짜
    var date: Date
    /// 만들 끼니들 (조식/중식/석식)
    var mealTypes: [String]
    /// 1인분 단가 상한(원)
    var budgetPerServing: Double
    /// 인원수
    var headcount: Int
    /// 반드시 포함할 재료 이름들
    var mustUse: [String]
}

/// 생성된 한 끼 식단. AI 응답 JSON / 폴백 / 화면 표시에 공통으로 쓰인다.
struct MealSuggestion: Codable, Identifiable, Equatable {
    var id = UUID()
    let mealType: String
    let dishes: [String]
    let usedIngredients: [String]
    let estimatedCost: Double

    enum CodingKeys: String, CodingKey {
        case mealType, dishes, usedIngredients, estimatedCost
    }
}

/// AI에 강제하는 응답 스키마의 루트.
struct MealPlanResponse: Codable {
    let meals: [MealSuggestion]
}

/// 생성 결과가 진짜 AI에서 왔는지, 폴백에서 왔는지 화면에 알려주기 위한 출처.
enum GenerationSource: Equatable {
    case ai
    case fallback(reason: String)

    var isFallback: Bool {
        if case .fallback = self { return true }
        return false
    }
}

/// 생성 결과 묶음.
struct GenerationResult {
    let meals: [MealSuggestion]
    let source: GenerationSource
    let request: PlanRequest
}
