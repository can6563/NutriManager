import Foundation

/// Gemini REST(generateContent)를 호출해 식단 JSON을 받아오고, 실패하면 폴백으로 대체한다.
struct NutritionAIService {

    enum AIError: LocalizedError {
        case missingKey
        case badResponse(Int)
        case emptyContent
        case decodeFailed(String)
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .missingKey: return "API 키가 설정되지 않았습니다."
            case .badResponse(let code): return "AI 서버 응답 오류(HTTP \(code))."
            case .emptyContent: return "AI 응답이 비어 있습니다."
            case .decodeFailed(let detail): return "AI 응답 해석 실패: \(detail)"
            case .transport(let detail): return "네트워크 오류: \(detail)"
            }
        }
    }

    var apiKey: String = Secrets.geminiAPIKey
    /// 안정적인 별칭(자동으로 최신 flash 모델로 연결). 특정 버전이 폐기돼도 깨지지 않는다.
    var model: String = "gemini-flash-latest"

    /// 식단을 생성한다. 우선 Gemini를 시도하고, 어떤 이유로든 실패하면 폴백 생성기로 대체한다.
    /// 결과에는 출처(GenerationSource)가 함께 담겨 화면에서 "오프라인 대체" 안내를 띄울 수 있다.
    func generate(
        request: PlanRequest,
        inventory: [Ingredient],
        recentPlans: [MealPlan],
        previousResult: [MealSuggestion]? = nil,
        revisionNote: String? = nil
    ) async -> GenerationResult {
        let recent = PromptBuilder.recentDishes(from: recentPlans)

        do {
            let meals = try await callGemini(
                request: request,
                inventory: inventory,
                recentDishes: recent,
                previousResult: previousResult,
                revisionNote: revisionNote
            )
            guard !meals.isEmpty else { throw AIError.emptyContent }
            return GenerationResult(meals: meals, source: .ai, request: request)
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let meals = FallbackGenerator.generate(
                request: request,
                inventory: inventory,
                recentDishes: Set(recent)
            )
            return GenerationResult(meals: meals, source: .fallback(reason: reason), request: request)
        }
    }

    /// 일시적 오류(네트워크/5xx/429/빈 응답)는 짧게 재시도한 뒤에야 폴백으로 넘긴다.
    private func callGemini(
        request: PlanRequest,
        inventory: [Ingredient],
        recentDishes: [String],
        previousResult: [MealSuggestion]?,
        revisionNote: String?
    ) async throws -> [MealSuggestion] {
        let maxAttempts = 2
        var lastError: Error = AIError.emptyContent
        for attempt in 1...maxAttempts {
            do {
                return try await singleCall(
                    request: request,
                    inventory: inventory,
                    recentDishes: recentDishes,
                    previousResult: previousResult,
                    revisionNote: revisionNote
                )
            } catch {
                lastError = error
                guard attempt < maxAttempts, isRetryable(error) else { throw error }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
        throw lastError
    }

    /// 재시도할 가치가 있는 일시적 오류인지 판단.
    private func isRetryable(_ error: Error) -> Bool {
        guard let e = error as? AIError else { return false }
        switch e {
        case .transport, .emptyContent: return true
        case .badResponse(let code): return code >= 500 || code == 429
        case .missingKey, .decodeFailed: return false
        }
    }

    /// 실제 Gemini 단건 호출부.
    private func singleCall(
        request: PlanRequest,
        inventory: [Ingredient],
        recentDishes: [String],
        previousResult: [MealSuggestion]?,
        revisionNote: String?
    ) async throws -> [MealSuggestion] {
        guard !apiKey.isEmpty, apiKey != "PUT_YOUR_KEY_HERE" else {
            throw AIError.missingKey
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw AIError.transport("잘못된 URL") }

        let body = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: PromptBuilder.systemInstruction())]),
            contents: [
                .init(role: "user", parts: [.init(text: PromptBuilder.userMessage(
                    request: request,
                    inventory: inventory,
                    recentDishes: recentDishes,
                    previousResult: previousResult,
                    revisionNote: revisionNote
                ))])
            ],
            generationConfig: .init(
                temperature: 0.7,
                responseMimeType: "application/json",
                responseSchema: GeminiRequest.mealResponseSchema
            )
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 25

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIError.badResponse(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIError.badResponse(http.statusCode)
        }

        let decoded: GeminiResponse
        do {
            decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            throw AIError.decodeFailed("응답 봉투 해석 실패")
        }

        guard let text = decoded.candidates?.first?.content?.parts?.first?.text, !text.isEmpty else {
            throw AIError.emptyContent
        }

        return try parseMeals(from: text)
    }

    /// 응답 텍스트에서 JSON 부분만 추출해 [MealSuggestion]으로 디코딩.
    private func parseMeals(from text: String) throws -> [MealSuggestion] {
        let cleaned = extractJSON(text)
        guard let data = cleaned.data(using: .utf8) else {
            throw AIError.decodeFailed("UTF-8 변환 실패")
        }
        do {
            let result = try JSONDecoder().decode(MealPlanResponse.self, from: data)
            return result.meals
        } catch {
            throw AIError.decodeFailed(error.localizedDescription)
        }
    }

    /// 모델이 ```json 펜스나 잡소리를 붙였을 때 첫 '{'부터 마지막 '}'까지만 잘라낸다.
    private func extractJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s
    }
}

// MARK: - Gemini REST 모델

private struct GeminiRequest: Encodable {
    struct Part: Encodable { let text: String }
    struct Content: Encodable {
        var role: String? = nil
        let parts: [Part]
    }
    struct SystemInstruction: Encodable { let parts: [Part] }
    struct GenerationConfig: Encodable {
        let temperature: Double
        let responseMimeType: String
        let responseSchema: SchemaNode
    }
    let systemInstruction: SystemInstruction
    let contents: [Content]
    let generationConfig: GenerationConfig

    /// Gemini 구조화 출력 스키마 노드(OpenAPI 서브셋). 자기참조가 필요해 클래스로 둔다.
    /// 옵셔널 필드는 합성된 Encodable이 nil이면 자동 생략(encodeIfPresent)한다.
    final class SchemaNode: Encodable {
        let type: String
        let items: SchemaNode?
        let properties: [String: SchemaNode]?
        let required: [String]?
        let propertyOrdering: [String]?

        init(type: String,
             items: SchemaNode? = nil,
             properties: [String: SchemaNode]? = nil,
             required: [String]? = nil,
             propertyOrdering: [String]? = nil) {
            self.type = type
            self.items = items
            self.properties = properties
            self.required = required
            self.propertyOrdering = propertyOrdering
        }
    }

    /// 응답이 MealPlanResponse 형태와 정확히 일치하도록 강제하는 스키마.
    static let mealResponseSchema: SchemaNode = {
        let string = SchemaNode(type: "STRING")
        let stringArray = SchemaNode(type: "ARRAY", items: SchemaNode(type: "STRING"))
        let meal = SchemaNode(
            type: "OBJECT",
            properties: [
                "mealType": string,
                "dishes": stringArray,
                "usedIngredients": stringArray,
                "estimatedCost": SchemaNode(type: "NUMBER")
            ],
            required: ["mealType", "dishes", "usedIngredients", "estimatedCost"],
            propertyOrdering: ["mealType", "dishes", "usedIngredients", "estimatedCost"]
        )
        return SchemaNode(
            type: "OBJECT",
            properties: ["meals": SchemaNode(type: "ARRAY", items: meal)],
            required: ["meals"]
        )
    }()
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}
