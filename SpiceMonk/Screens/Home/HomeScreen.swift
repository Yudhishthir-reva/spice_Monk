//
//  HomeScreen.swift
//  SpiceMonk
//

import SwiftUI

struct HomeScreen: View {

    @StateObject var viewModel = HomeViewModel()
    @StateObject private var addressViewModel = AddressViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var selectedTab: HomeTab = .home
    @State private var cartDestination: HomeTabDestination?
    @State private var searchBarOffset: CGFloat = 0
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
            if !isSearchActive {
                FloatingWhatsAppButton()
                    .padding(.trailing, 16)
                    .padding(.bottom, 68)
            }
        }
        .overlay(alignment: .top) {
            if selectedTab == .home {
                Color.clear
                    .frame(height: 0)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.homeHeaderTop.ignoresSafeArea(edges: .top))
                    .allowsHitTesting(false)
            }
        }
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
                        header(safeAreaTop: topInset)
                            .zIndex(2)

                        feedBody
                            .zIndex(1)
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
        AccountPlaceholderScreen(addressViewModel: addressViewModel)
    }

    // MARK: - Header & Feed

    private func header(safeAreaTop: CGFloat) -> some View {
        HomeTopBar(
            address: addressViewModel.defaultAddress,
            addressOpacity: addressOpacity(safeAreaTop: safeAreaTop),
            safeAreaTop: safeAreaTop,
            searchPlaceholders: viewModel.searchPlaceholders,
            onAddressTap: { isPickingAddress = true },
            onProfileTap: { isConfirmingLogout = true },
            onSearchTap: enterSearch,
            onSearchMic: enterSearch
        )
        .visualEffect { content, proxy in
            content.offset(y: offsetYSearchBar(proxy, safeAreaTop: safeAreaTop))
        }
        .visualEffect { content, proxy in
            content.offset(y: offsetYFullHeader(proxy))
        }
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
            HomeTopBar(
                address: addressViewModel.defaultAddress,
                addressOpacity: 0,
                safeAreaTop: safeAreaTop,
                searchActive: true,
                searchQuery: Binding(
                    get: { searchViewModel.query },
                    set: { searchViewModel.updateQuery($0) }
                ),
                searchPlaceholders: viewModel.searchPlaceholders,
                onAddressTap: {},
                onProfileTap: {},
                onSearchBack: exitSearch,
                onSearchClear: { searchViewModel.clear() },
                onSearchSubmit: { searchViewModel.submit() },
                onSearchMic: {}
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

    nonisolated private func offsetYSearchBar(_ proxy: GeometryProxy, safeAreaTop: CGFloat) -> CGFloat {
        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
        Task { @MainActor in
            searchBarOffset = minY
        }
        _ = safeAreaTop
        return minY > 0 ? 0 : -minY
    }

    private func addressOpacity(safeAreaTop: CGFloat) -> CGFloat {
        let inset = max(safeAreaTop, 1)
        let clamped = min(max(searchBarOffset, -inset), 0)
        return min(max(1 - (clamped / -inset), 0), 1)
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
