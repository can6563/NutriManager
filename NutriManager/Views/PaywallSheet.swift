import SwiftUI

/// 무료 횟수 초과 시 뜨는 결제(흉내) 시트. StoreKit 로컬 상품으로 흐름만 보여준다.
struct PaywallSheet: View {
    let onUnlocked: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreManager()
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 52)).foregroundStyle(.yellow)
                    .padding(.top, 24)

                Text("오늘 무료 생성 횟수를 모두 썼어요")
                    .font(.title3.bold()).multilineTextAlignment(.center)

                Text("프리미엄을 해제하면 오늘 하루 AI 식단을 무제한으로 생성할 수 있어요.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    benefit("무제한 AI 식단 생성")
                    benefit("재검색(맥락 수정) 무제한")
                    benefit("소비기한 임박 우선 최적화")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }

                Spacer()

                Button {
                    Task { await purchase() }
                } label: {
                    if isPurchasing {
                        HStack { ProgressView().tint(.white); Text("결제 진행 중…") }
                    } else {
                        Text("\(store.displayPrice) · 오늘 무제한 해제")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isPurchasing)

                Text("로컬 StoreKit 테스트 결제입니다(실제 청구 없음).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("프리미엄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task { await store.loadProduct() }
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(text).font(.subheadline)
            Spacer()
        }
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        let ok = await store.purchase()
        if ok {
            onUnlocked()
        } else {
            errorMessage = store.lastErrorMessage ?? "결제가 취소되었습니다."
        }
    }
}
