//
//  HomeScreen.swift
//  SpiceMonk
//

import SwiftUI

struct HomeScreen: View {

    @StateObject var viewModel = HomeViewModel()
    @StateObject private var addressViewModel = AddressViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @ObservedObject private var cartStore = CartStore.shared
    @State private var selectedTab: HomeTab = .home
    @State private var cartDestination: HomeTabDestination?
    @State private var searchBarOffset: CGFloat = 0
    @State private var topHeaderOffset: CGFloat = 0
    @State private var isConfirmingLogout = false
    @State private var isPickingAddress = false
    @State private var isSearchActive = false
    @State private var selectedVariantProduct: ProductItem? = nil

    var body: some View {
        NavigationStack {
            mainContent
                .environment(\EnvironmentValues.onSelectVariantSheet) { product in
                    selectedVariantProduct = product
                }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .home:
                    homeContent
                case .categories:
                    categoriesContent
                case .account:
                    accountContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isSearchActive {
                FloatingCartBar {
                    cartDestination = .cart
                }
                HomeBottomBar(selected: selectedTab, onSelect: { tab in
                    selectedTab = tab
                })
            }
        }
        .background(AppTheme.homeCanvas, ignoresSafeAreaEdges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $cartDestination) { destination in
            switch destination {
            case .cart:
                CartScreen(addressViewModel: addressViewModel)
            default:
                EmptyView()
            }
        }
        .navigationDestination(item: $searchViewModel.resultsDestination) { destination in
            WidgetProductsScreen(
                searchQuery: destination.query,
                title: destination.title,
                categoryId: destination.categoryId,
                brandId: destination.brandId,
                productId: destination.productId
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if !isSearchActive && cartStore.summary.totalItems == 0 {
                FloatingWhatsAppButton()
                    .padding(.trailing, 16)
                    .padding(.bottom, 68)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: cartStore.summary.totalItems == 0)
        .onAppear {
            if !viewModel.hasContent {
                viewModel.loadHome()
            }
            addressViewModel.load()
            CartStore.shared.loadIfNeeded()
        }
        .sheet(isPresented: $isPickingAddress) {
            AddressPickerSheet(viewModel: addressViewModel)
        }
        .sheet(item: $selectedVariantProduct) { product in
            VariantSelectorSheet(product: product)
        }
        .confirmationDialog("Log out of SpiceMonk?", isPresented: $isConfirmingLogout) {
            Button("Log out", role: .destructive) {
                viewModel.logout()
            }
            Button("Cancel", role: .cancel) {}
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .toast(isPresenting: $addressViewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: addressViewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .toast(isPresenting: $searchViewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: searchViewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .cartStoreToast()
    }

    // MARK: - Home Tab

    private var homeContent: some View {
        GeometryReader { geometry in
            let topInset = resolvedTopInset(geometry.safeAreaInsets.top)

            if isSearchActive {
                searchMode(safeAreaTop: topInset)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            header(safeAreaTop: topInset)
                                .zIndex(1000003)
                        }
                        .zIndex(1000001)
                        .visualEffect { content, proxy in
                            content.offset(y: offsetYFullHeader(proxy))
                        }

                        feedBody
                            .zIndex(1000000)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .refreshable { await refreshFeed() }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Categories Tab

    private var categoriesContent: some View {
        CategoriesTabScreen(categories: viewModel.allCategories)
    }

    // MARK: - Account Tab

    private var accountContent: some View {
        AccountTabScreen(
            addressViewModel: addressViewModel,
            onLogout: {
                viewModel.logout()
            }
        )
    }

    private let addressScrollThreshold: CGFloat = 44

    private var addressOpacity: CGFloat {
        let clamped = min(max(searchBarOffset, -addressScrollThreshold), 0)
        return max(0, min(1, 1.0 - (clamped / -addressScrollThreshold)))
    }

    // MARK: - Header & Feed

    private func header(safeAreaTop: CGFloat) -> some View {
        HomeTopBar(
            address: addressViewModel.defaultAddress,
            addressOpacity: addressOpacity,
            safeAreaTop: safeAreaTop,
            searchPlaceholders: viewModel.searchPlaceholders,
            onAddressTap: { isPickingAddress = true },
            onNotificationTap: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.toastMessage = "Notifications coming soon!"
                viewModel.isShowToastView = true
            },
            onSearchTap: enterSearch,
            onSearchMic: enterSearch
        )
        .visualEffect { content, proxy in
            let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
            Task { @MainActor in
                if self.searchBarOffset != minY {
                    self.searchBarOffset = minY
                }
            }
            let offset = minY > -addressScrollThreshold ? 0 : -(minY + addressScrollThreshold)
            return content.offset(y: offset)
        }
        .zIndex(1000003)
    }

    @ViewBuilder
    private var feedBody: some View {
        if viewModel.isLoading && !viewModel.hasContent {
            HomeSkeleton()
        } else if let error = viewModel.loadError, !viewModel.hasContent {
            HomeErrorState(message: error) {
                viewModel.loadHome()
            }
            .padding(.top, 60)
        } else {
            VStack(spacing: 22) {
                ForEach(viewModel.widgets) { widget in
                    HomeWidgetBlock(widget: widget)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private func searchMode(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            SearchTopBar(
                query: Binding(
                    get: { searchViewModel.query },
                    set: { searchViewModel.updateQuery($0) }
                ),
                placeholder: viewModel.searchPlaceholders.first ?? "Search spices, masala, oils…",
                safeAreaTop: safeAreaTop,
                onBack: exitSearch,
                onClear: { searchViewModel.clear() },
                onSubmit: { searchViewModel.submit() }
            )

            SearchSuggestionsPane(viewModel: searchViewModel)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func enterSearch() {
        isSearchActive = true
    }

    private func exitSearch() {
        isSearchActive = false
        searchViewModel.clear()
    }

    // MARK: - Scroll helpers

    nonisolated private func offsetYFullHeader(_ proxy: GeometryProxy) -> CGFloat {
        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
        return minY > 0 ? -minY : 0
    }

    private func resolvedTopInset(_ fromGeometry: CGFloat) -> CGFloat {
        if fromGeometry > 0 { return fromGeometry }
        return UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 59
    }
    private func refreshFeed() async {
        viewModel.refresh()
        while viewModel.isRefreshing {
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
}

#Preview {
    HomeScreen()
}
