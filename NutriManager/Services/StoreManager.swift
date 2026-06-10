import Foundation
import StoreKit

/// StoreKit 2 + 로컬 Products.storekit 으로 "프리미엄 해제" 결제 흐름을 흉내 낸다.
/// 앱스토어 등록 없이 시뮬레이터에서 테스트 가능하며, 상품 로드가 실패해도
/// 데모가 멈추지 않도록 안전한 시뮬레이션 경로를 제공한다.
@MainActor
final class StoreManager: ObservableObject {
    /// .storekit 파일에 정의된 상품 ID와 일치해야 한다.
    static let premiumProductID = "com.nutrimanager.premium.daily"

    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    /// 화면에 표시할 가격 문자열(상품 로드 실패 시 기본값).
    var displayPrice: String { product?.displayPrice ?? "₩1,100" }

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            product = products.first
        } catch {
            lastErrorMessage = error.localizedDescription
            product = nil
        }
    }

    /// 구매를 시도한다. 실제 상품이 있으면 StoreKit 결제, 없으면 시뮬레이션으로 성공 처리.
    /// - Returns: 결제 성공 여부.
    func purchase() async -> Bool {
        guard let product else {
            // 로컬 상품이 로드되지 않은 환경(스킴 미설정 등) → 데모용 시뮬레이션 성공.
            return true
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return true
                }
                lastErrorMessage = "결제 검증에 실패했습니다."
                return false
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = "결제가 대기 상태입니다."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }
}
