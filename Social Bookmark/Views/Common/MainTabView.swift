import SwiftUI

// MARK: - Tab Enum

enum AppTab: String, CaseIterable, Hashable {
    case home
    case library
    case add
    case search
}

// MARK: - MainTabView (iOS 26+ Liquid Glass)

/// Ana tab bar navigation - iOS 26 Liquid Glass Tab API
/// Search tab'ı role: .search ile ayrı gösterilir
@available(iOS 26.0, *)
struct MainTabView: View {
    // MARK: - Properties
    
    @Bindable var viewModel: HomeViewModel
    @State private var selectedTab: AppTab = .home
    @State private var searchText = ""
    @StateObject private var sessionStore = SessionStore()
    
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
                AddTabContent(viewModel: viewModel, selectedTab: $selectedTab)
            }
            
            // Search Tab - role: .search ile Liquid Glass'ta ayrı görünür
            Tab(value: .search,  role: .search) {
                NavigationStack {
                    SearchView(viewModel: viewModel, selectedTab: $selectedTab, searchText: $searchText)
                        .environmentObject(sessionStore)
                        .navigationTitle(String(localized: "tab.search"))
                }
                .searchable(text: $searchText, placement: .automatic)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown) // Scroll'da tab bar küçülür
    }
}

// MARK: - MainTabView (iOS 18-25)

@available(iOS 18.0, *)
struct MainTabViewiOS18: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedTab: AppTab = .home
    @State private var searchText = ""
    @StateObject private var sessionStore = SessionStore()
    
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
                AddTabContent(viewModel: viewModel, selectedTab: $selectedTab)
            }
            
            // Search Tab with role: .search
            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchView(viewModel: viewModel, selectedTab: $selectedTab, searchText: $searchText)
                        .environmentObject(sessionStore)
                        .navigationTitle(String(localized: "tab.search"))
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
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
            // Home
            NavigationStack {
                HomeView(viewModel: viewModel)
                    .environmentObject(sessionStore)
            }
            .tabItem {
                Label(String(localized: "tab.home"), systemImage: "house.fill")
            }
            .tag(AppTab.home)
            
            // Library
            NavigationStack {
                LibraryView(viewModel: viewModel, selectedTab: $selectedTab)
                    .environmentObject(sessionStore)
            }
            .tabItem {
                Label(String(localized: "tab.library"), systemImage: "books.vertical.fill")
            }
            .tag(AppTab.library)
            
            // Add
            AddTabContent(viewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label(String(localized: "tab.add"), systemImage: "plus.circle.fill")
                }
                .tag(AppTab.add)
            
            // Search
            NavigationStack {
                SearchView(viewModel: viewModel, selectedTab: $selectedTab, searchText: $searchText)
                    .environmentObject(sessionStore)
                    .navigationTitle(String(localized: "tab.search"))
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .tabItem {
                Label(String(localized: "tab.search"), systemImage: "magnifyingglass")
            }
            .tag(AppTab.search)
        }
    }
}

// MARK: - Add Tab Content (Shared)

/// Add Tab için ayrı struct - lazy loading ve state preservation
private struct AddTabContent: View {
    let viewModel: HomeViewModel
    @Binding var selectedTab: AppTab
    @State private var addViewModel: AddBookmarkViewModel?
    
    var body: some View {
        NavigationStack {
            Group {
                if let addVM = addViewModel {
                    AddBookmarkView(
                        viewModel: addVM,
                        onSaved: {
                            Task{
                                await  viewModel.refresh()
                            }
                            selectedTab = .home
                        }
                    )
                } else {
                    ProgressView()
                        .onAppear {
                            addViewModel = AddBookmarkViewModel(
                                repository: viewModel.bookmarkRepository,
                                categoryRepository: viewModel.categoryRepository
                            )
                        }
                }
            }
        }
    }
}

// MARK: - Adaptive MainTabView

struct AdaptiveMainTabView: View {
    @Bindable var viewModel: HomeViewModel
    
    var body: some View {
        if #available(iOS 26.0, *) {
            MainTabView(viewModel: viewModel)
        } else if #available(iOS 18.0, *) {
            MainTabViewiOS18(viewModel: viewModel)
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
