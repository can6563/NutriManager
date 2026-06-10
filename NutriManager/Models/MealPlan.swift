import Foundation
import SwiftData

/// 날짜·끼니별 식단. AI 또는 폴백 생성기가 만든 추천을 수락하면 저장된다.
@Model
final class MealPlan {
    var id: UUID
    var date: Date
    /// 조식 / 중식 / 석식
    var mealType: String
    /// 메뉴 이름들
    var dishes: [String]
    /// 사용(소진) 재료 이름들
    var usedIngredients: [String]
    /// 1인분 추정 단가(원)
    var estimatedCost: Double
    var accepted: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        mealType: String,
        dishes: [String],
        usedIngredients: [String],
        estimatedCost: Double = 0,
        accepted: Bool = false
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.dishes = dishes
        self.usedIngredients = usedIngredients
        self.estimatedCost = estimatedCost
        self.accepted = accepted
    }
}
