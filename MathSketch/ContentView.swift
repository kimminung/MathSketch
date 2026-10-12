import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SketchComposerView()
                .tabItem { Label("캔버스", systemImage: "square.on.circle") }
            GalleryView()
                .tabItem { Label("갤러리", systemImage: "photo.on.rectangle.angled") }
        }
    }
}

#Preview {
    ContentView()
        .environment(SketchModel())
}
