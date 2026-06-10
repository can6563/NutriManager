import SwiftUI
import SwiftData

@main
struct NutriManagerApp: App {
    let container: ModelContainer
    @StateObject private var router = AppRouter()
    @StateObject private var usage = UsageManager()

    init() {
        do {
            let schema = Schema([
                Ingredient.self,
                MealPlan.self,
                Supplier.self,
                UsageCounter.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
        SampleData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(router)
                .environmentObject(usage)
                .task { usage.configure(container.mainContext) }
        }
        .modelContainer(container)
    }
}
