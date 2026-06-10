import SwiftUI
import SwiftData

/// 보조: 긴급 발주 연락망 — 업체 리스트 + 전화 연결. 거래 중개는 하지 않는다.
struct SupplierBoardView: View {
    @Query(sort: \Supplier.name) private var suppliers: [Supplier]
    @State private var filter = "전체"

    private let categories = ["전체", "채소", "육류", "수산", "곡물", "유제품", "종합"]

    private var filtered: [Supplier] {
        filter == "전체" ? suppliers : suppliers.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                notice
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button { filter = cat } label: {
                                Text(cat)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Capsule().fill(filter == cat ? Color.accentColor : Color(.tertiarySystemFill)))
                                    .foregroundStyle(filter == cat ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                List(filtered) { supplier in
                    SupplierRow(supplier: supplier)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("긴급 발주 연락망")
        }
    }

    private var notice: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(.blue)
            Text("거래는 직접 진행하세요 (앱은 연락처만 제공, 중개 아님).")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
    }
}

private struct SupplierRow: View {
    let supplier: Supplier

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(supplier.name).font(.body.weight(.semibold))
                    TagChip(text: supplier.category, tint: .orange)
                }
                Text("\(supplier.region) · \(supplier.phone)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let url = telURL {
                Link(destination: url) {
                    Image(systemName: "phone.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var telURL: URL? {
        let digits = supplier.phone.filter { $0.isNumber }
        return URL(string: "tel://\(digits)")
    }
}
