import SwiftUI

enum AppTab: Hashable {
    case home, inventory, planner, supplier, my
}

/// 탭 전환과 "특정 날짜를 들고 식단 기획실로 이동" 같은 화면 간 이동을 관리한다.
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    /// 홈 달력의 빈 날짜를 눌러 기획실로 넘어올 때 들고 오는 날짜.
    @Published var plannerSeedDate: Date? = nil

    func openPlanner(for date: Date) {
        plannerSeedDate = Calendar.current.startOfDay(for: date)
        selectedTab = .planner
    }
}
