import SwiftData
import SwiftUI

@main
struct MathSketchApp: App {
    @State private var model = SketchModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .modelContainer(for: SavedSketch.self)
    }
}
