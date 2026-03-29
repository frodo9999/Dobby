import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var searchText = ""
    @State private var showingSearch = false

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
        .modelContainer(for: [Room.self, Cabinet.self, Item.self], inMemory: true)
}
