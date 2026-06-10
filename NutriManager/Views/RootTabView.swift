import SwiftUI

/// 하단 탭 5개: 홈 · 창고 · 식단(AI) · 발주 · 마이
struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeDashboardView()
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(AppTab.home)

            InventoryView()
                .tabItem { Label("창고", systemImage: "shippingbox.fill") }
                .tag(AppTab.inventory)

            AIPlannerView()
                .tabItem { Label("식단", systemImage: "wand.and.stars") }
                .tag(AppTab.planner)

            SupplierBoardView()
                .tabItem { Label("발주", systemImage: "phone.fill") }
                .tag(AppTab.supplier)

            MyView()
                .tabItem { Label("마이", systemImage: "person.fill") }
                .tag(AppTab.my)
        }
    }
}
