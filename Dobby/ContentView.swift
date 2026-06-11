import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var lm: LanguageManager

    var body: some View {
        TabView {
            RoomListView()
                .tabItem {
                    Label(lm.s.tabRooms, systemImage: "house")
                }

            SearchView()
                .tabItem {
                    Label(lm.s.tabSearch, systemImage: "magnifyingglass")
                }

            PhotoAddTabView()
                .tabItem {
                    Label(lm.s.tabSmartAdd, systemImage: "camera.viewfinder")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
