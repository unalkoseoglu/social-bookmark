import SwiftUI

// MARK: - Tab Enum

enum AppTab: String, CaseIterable {
    case home, library, add, search
}

// MARK: - MainTabView (iOS 18+)

/// Ana tab bar navigation - iOS 18 Native Tab API
/// Search sağda ayrı olarak gösterilir
@available(iOS 18.0, *)
struct MainTabView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @State private var searchText = ""
    @StateObject private var sessionStore = SessionStore()
    @State private var selectedTab: AppTab = .home
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            Tab(String(localized: "tab.home"), systemImage: "house.fill", value: .home) {
                NavigationStack {
                    HomeView(viewModel: viewModel)
                        .environmentObject(sessionStore)
                }
            }
            
            // Library Tab
            Tab(String(localized: "tab.library"), systemImage: "books.vertical.fill", value: .library) {
                NavigationStack {
                    LibraryView(viewModel: viewModel, selectedTab: $selectedTab)
                        .environmentObject(sessionStore)
                }
            }
            
            // Add Tab
            Tab(String(localized: "tab.add"), systemImage: "plus.circle.fill", value: .add) {
                NavigationStack {
                    AddBookmarkView(
                        viewModel: AddBookmarkViewModel(
                            repository: viewModel.bookmarkRepository,
                            categoryRepository: viewModel.categoryRepository
                        ),
                        onSaved: {
                            viewModel.refresh()
                            selectedTab = .home
                        }
                    )
                }
            }
            
            // Search Tab (role: .search - sağda ayrı gösterilir)
            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchView(viewModel: viewModel, selectedTab: $selectedTab,  searchText: $searchText)
                        .environmentObject(sessionStore)
                        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                }
            }
        }
    }
}

// MARK: - MainTabView Legacy (iOS 17)

struct MainTabViewLegacy: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedTab: AppTab = .home
    @State private var searchText = ""
    @StateObject private var sessionStore = SessionStore()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(viewModel: viewModel)
                    .environmentObject(sessionStore)
            }
            .tabItem {
                Label(String(localized: "tab.home"), systemImage: "house.fill")
            }
            .tag(AppTab.home)
            
            NavigationStack {
                LibraryView(viewModel: viewModel, selectedTab: $selectedTab)
                    .environmentObject(sessionStore)
            }
            .tabItem {
                Label(String(localized: "tab.library"), systemImage: "books.vertical.fill")
            }
            .tag(AppTab.library)
            
            NavigationStack {
                AddBookmarkView(
                    viewModel: AddBookmarkViewModel(
                        repository: viewModel.bookmarkRepository,
                        categoryRepository: viewModel.categoryRepository,
                        
                    ),
                    onSaved: {
                        viewModel.refresh()
                        selectedTab = .home
                    },
                )
            }
            .tabItem {
                Label(String(localized: "tab.add"), systemImage: "plus.circle.fill")
            }
            .tag(AppTab.add)
            
            NavigationStack {
                SearchView(viewModel: viewModel,
                           selectedTab: $selectedTab,
                           searchText: $searchText,)
                    .environmentObject(sessionStore)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            }
            .tabItem {
                Label(String(localized: "tab.search"), systemImage: "magnifyingglass")
            }
            .tag(AppTab.search)
        }
    }
}

// MARK: - Adaptive MainTabView

struct AdaptiveMainTabView: View {
    @Bindable var viewModel: HomeViewModel
    
    var body: some View {
        if #available(iOS 18.0, *) {
            MainTabView(viewModel: viewModel)
        } else {
            MainTabViewLegacy(viewModel: viewModel)
        }
    }
}

// MARK: - Preview

#Preview {
    AdaptiveMainTabView(
        viewModel: HomeViewModel(
            bookmarkRepository: PreviewMockRepository.shared,
            categoryRepository: PreviewMockCategoryRepository.shared
        )
    )
}
