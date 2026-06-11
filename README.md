

#  NutriManager — 영양사용 급식 관리 앱

> 시연 영상: _https://www.youtube.com/watch?v=1_05SEOLMoQ

영양사·조리사를 위한 재고/소비기한 관리 + AI 식단 자동 생성 iOS 앱입니다.
모든 데이터는 중앙 서버 없이 기기 내부(SwiftData) 에만 저장됩니다.

---

##  해결하는 문제

1. 폐기 손실 — 냉장고/창고 재고와 소비기한을 관리해 *곧 상하는 재료를 먼저* 쓰게 알려줍니다.
2. 식단 피로 — AI가 "남은 재고 + 최근 2주 메뉴"를 보고 *겹치지 않는 식단*을 자동으로 짜줍니다.

---

# 주요 기능

| 탭 | 화면 | 설명 |
|---|---|---|
|  홈 | `HomeDashboardView` | 이번 주 남은 예산 / 소비기한 임박 경고 카드 + 식단 달력(빈 날짜 → AI 자동 채우기) |
|  창고 | `InventoryView` | 임박순 재고 리스트, `[-] [+]` 스텝퍼, D-day 뱃지, "전수조사 완료" 저장 토스트, 재료 추가 폼(입력 검증) |
|  식단 | `AIPlannerView` → `MealResultView` | 예산 슬라이더 · 필수 재료 체크(임박 자동선택) · 끼니/인원 → AI 생성 → 수락/재검색 |
|  발주 | `SupplierBoardView` | 도매업체 연락망, 전화 연결(중개 아님 명시) |
|  마이 | `MyView` | AI 사용 현황 / 프리미엄 상태 / 데모 리셋 |

###AI 식단 생성 
- `PromptBuilder` 가 재고 + 최근 14일 메뉴를 JSON 텍스트로 만들고, 환각 억제 규칙
  ("이 재고만 / 임박 우선 / 최근 메뉴 중복금지 / 예산 준수 / JSON으로만 응답")을 시스템 프롬프트로 강제합니다.
- `NutritionAIService` 가 Gemini `generateContent` REST** 를 `URLSession async` 로 호출하고 응답 JSON을 `[MealSuggestion]` 으로 디코딩합니다.
- 실패하면 자동으로 `FallbackGenerator`(오프라인 규칙 기반 생성기)로 대체**하고, 결과 화면에
  "AI 연결 실패 → 오프라인 추천으로 대체했어요" 를 안내합니다. 이를 통해 데모 또한 끊기지 않는 답변을, 유료 결제을 추가할 때 유도할 수 있습니다.
- "일부분만 고쳐서 다시 검색" 은 **직전 결과를 맥락으로 함께 전송**해 다시 생성합니다.

##부분 유료화 
- 무료 하루 3회, 초과 시 `PaywallSheet` 로 결제 유도 → 해제 시 당일 무제한.
- StoreKit 2 + 로컬 `Products.storekit` 로 앱스토어 등록 없이 시뮬레이터에서 흐름 시연.
- 로컬 상품이 로드되지 않는 환경에서도 시뮬레이션 성공 경로로 데모가 멈추지 않습니다.

---

## 기술 스택

- Swift 5 / SwiftUI (iOS 17.0+)
- SwiftData— 온디바이스 영속 저장 (`Ingredient`, `MealPlan`, `Supplier`, `UsageCounter`)
- Gemini REST API (`gemini-flash-latest`) + 오프라인 폴백 생성기
- StoreKit 2 + 로컬 `.storekit` 결제 설정

---


##  폴더 구조

```
NutriManager/
├── NutriManagerApp.swift          # 앱 진입점 + ModelContainer
├── AppRouter.swift                # 탭/화면 이동 라우터
├── Secrets.swift                  # API 키 (gitignore)
├── Models/                        # Ingredient, MealPlan, Supplier, UsageCounter
├── Services/                      # ExpiryService, PromptBuilder, NutritionAIService,
│                                  #   FallbackGenerator, UsageManager, StoreManager
├── Views/                         # Home / Inventory / AIPlanner / MealResult /
│   └── Components/                #   Supplier / My / Paywall + 공용 컴포넌트
└── Resources/                     # SampleData.swift, Products.storekit
```

---


##  향후 계획
- iCloud(CloudKit) 동기화 — 유료 개발자 계정 필요로 현재는 온디바이스만 지원.

---

*2091104 · 이찬희 · iOS 프로그래밍(A분반)*
