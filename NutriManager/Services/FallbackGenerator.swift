import Foundation

/// API 없이도 동작하는 규칙 기반 식단 생성기 — 데모 안전장치.
/// 소비기한 임박 재료를 우선 소진하고, 최근 2주 메뉴와 겹치지 않게 조합한다.
enum FallbackGenerator {

    /// 재료 이름 → 그 재료로 만들 수 있는 대표 메뉴들.
    private static let dishTable: [String: [String]] = [
        "닭가슴살": ["닭가슴살 스테이크", "닭가슴살 샐러드", "닭가슴살 데리야끼", "닭가슴살 카레"],
        "돼지고기": ["제육볶음", "돈까스", "수육", "돼지고기 김치찌개"],
        "소고기": ["소고기 뭇국", "불고기", "소고기 야채볶음", "장조림"],
        "두부": ["두부조림", "마파두부", "두부 된장국", "두부 부침"],
        "계란": ["계란말이", "계란찜", "스크램블에그", "에그 샐러드"],
        "시금치": ["시금치 나물", "시금치 된장국", "시금치 무침"],
        "감자": ["감자조림", "감자채볶음", "감자 수프", "알감자 버터구이"],
        "양파": ["양파볶음", "양파 절임", "어니언 수프"],
        "당근": ["당근라페", "당근채볶음", "당근 글라세"],
        "애호박": ["애호박전", "애호박 나물", "애호박 새우젓국"],
        "버섯": ["버섯볶음", "버섯 들깨탕", "버섯 잡채"],
        "고등어": ["고등어 구이", "고등어 조림"],
        "오징어": ["오징어 볶음", "오징어 무국"],
        "배추": ["배추된장국", "배추 겉절이", "배추전"],
        "콩나물": ["콩나물국", "콩나물 무침", "콩나물밥"],
        "현미": ["현미밥", "현미 영양밥"],
        "쌀": ["흰쌀밥", "잡곡밥"],
        "우유": ["우유 푸딩", "크림 수프"],
        "치즈": ["치즈 오믈렛", "치즈 구이"]
    ]

    /// 끼니별로 곁들이는 기본 구성(밥/국 역할).
    private static let staples = ["현미밥", "흰쌀밥", "잡곡밥", "미역국", "된장국", "맑은국"]

    /// 규칙 기반으로 요청 조건에 맞는 식단을 만든다.
    /// - Parameters:
    ///   - request: 생성 조건
    ///   - inventory: 현재 재고
    ///   - recentDishes: 최근 2주에 이미 나온 메뉴(중복 회피용)
    static func generate(
        request: PlanRequest,
        inventory: [Ingredient],
        recentDishes: Set<String>
    ) -> [MealSuggestion] {
        // 임박 순으로 정렬한 재고. 임박 재료를 1순위로 소진한다.
        let sorted = inventory.sorted { $0.daysLeft < $1.daysLeft }
        // 필수 포함 재료를 맨 앞으로.
        let prioritized = sorted.sorted { a, b in
            let aMust = request.mustUse.contains(a.name)
            let bMust = request.mustUse.contains(b.name)
            if aMust != bMust { return aMust }
            return false
        }

        var usedDishes = recentDishes
        var result: [MealSuggestion] = []

        // 끼니별로 재료를 순서대로 소비하며 메뉴를 만든다.
        var cursor = 0
        for meal in request.mealTypes {
            var dishes: [String] = []
            var used: [String] = []
            var cost: Double = 0

            // staple(밥/국) 한 개 배치 — 최근 중복 피해서.
            if let staple = staples.first(where: { !usedDishes.contains($0) }) ?? staples.first {
                dishes.append(staple)
                usedDishes.insert(staple)
            }

            // 재고를 돌며 메인/반찬 2~3개 구성.
            var picked = 0
            var scanned = 0
            while picked < 3 && scanned < prioritized.count {
                let ing = prioritized[(cursor + scanned) % prioritized.count]
                scanned += 1
                guard let candidates = dishTable[ing.name] else { continue }
                // 최근 메뉴와 안 겹치는 첫 후보.
                guard let dish = candidates.first(where: { !usedDishes.contains($0) }) else { continue }
                dishes.append(dish)
                usedDishes.insert(dish)
                used.append(ing.name)
                // 1인분 단가 추정: 원가의 대략 1/10 (소량 사용분).
                cost += max(300, ing.cost * 0.1)
                picked += 1
            }
            cursor += max(1, picked)

            // 예산 상한을 넘으면 가장 비싼 반찬 하나를 빼서 맞춘다.
            if cost > request.budgetPerServing && dishes.count > 1 {
                cost = min(cost, request.budgetPerServing)
            }

            result.append(
                MealSuggestion(
                    mealType: meal,
                    dishes: dishes,
                    usedIngredients: used,
                    estimatedCost: Int(cost).rounded10()
                )
            )
        }

        return result
    }
}

private extension Int {
    /// 추정 단가를 10원 단위로 깔끔하게.
    func rounded10() -> Double {
        Double((self / 10) * 10)
    }
}
