import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView {
            RoomListView()
                .tabItem {
                    Label("房间", systemImage: "house")
                }

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }

            PhotoAddTabView()
                .tabItem {
                    Label("拍照添加", systemImage: "camera.viewfinder")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
