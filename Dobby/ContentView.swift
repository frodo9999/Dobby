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
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
