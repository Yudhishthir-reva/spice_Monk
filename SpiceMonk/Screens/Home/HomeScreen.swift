//
//  HomeScreen.swift
//  SpiceMonk
//

import SwiftUI

struct HomeScreen: View {

    @StateObject var viewModel = HomeViewModel()
    @StateObject private var addressViewModel = AddressViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var tabDestination: HomeTabDestination?
    @State private var searchBarOffset: CGFloat = 0
    @State private var isConfirmingLogout = false
    @State private var isPickingAddress = false
    @State private var isSearchActive = false

    var body: some View {
        NavigationStack {
            homeRoot
        }
    }

    private var homeRoot: some View {
        VStack(spacing: 0) {
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

            if !isSearchActive {
                HomeBottomBar(onSelect: openTab)
            }
        }
        .background(AppTheme.homeCanvas, ignoresSafeAreaEdges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $tabDestination) { destination in
            switch destination {
            case .categories:
                CategoriesTabScreen(categories: viewModel.allCategories)
            case .cart:
                CartScreen(addressViewModel: addressViewModel)
            case .account:
                AccountPlaceholderScreen(addressViewModel: addressViewModel)
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
        // A 0-height view at the top of the layout, with a background that is allowed to paint
        // into the status bar. The in-scroll header can move; this strip cannot, so the clock
        // never sits on a hole.
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .frame(maxWidth: .infinity)
                .background(AppTheme.homeHeaderTop.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
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

    /// Address + search live in the scroll view so they can share its geometry. `visualEffect`
    /// then pins the search row once the address has scrolled through the status bar.
    private func header(safeAreaTop: CGFloat) -> some View {
        HomeTopBar(
            address: addressViewModel.defaultAddress,
            addressOpacity: addressOpacity(safeAreaTop: safeAreaTop),
            safeAreaTop: safeAreaTop,
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

    private func openTab(_ tab: HomeTab) {
        switch tab {
        case .home:
            break
        case .categories:
            tabDestination = .categories
        case .cart:
            tabDestination = .cart
        case .account:
            tabDestination = .account
        }
    }

    /// Rubber-band: while the user pulls the feed down, slide the header back by the same amount
    /// so it stays parked under the status bar instead of stretching away from the top.
    nonisolated private func offsetYFullHeader(_ proxy: GeometryProxy) -> CGFloat {
        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
        return minY > 0 ? -minY : 0
    }

    /// Once the header starts scrolling up, push it back by `-minY` so the plum fill stays in the
    /// status bar and search stays below the notch. E-RSPL used `-(minY + safeAreaTop)` because
    /// their address row kept its height; we collapse that row, so pinning at `-safeAreaTop` would
    /// sit the search on top of the clock.
    nonisolated private func offsetYSearchBar(_ proxy: GeometryProxy, safeAreaTop: CGFloat) -> CGFloat {
        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
        Task { @MainActor in
            searchBarOffset = minY
        }
        _ = safeAreaTop
        return minY > 0 ? 0 : -minY
    }

    /// Address is fully visible at rest and gone once `searchBarOffset` has travelled one status-bar
    /// height — the same window the search bar uses to pin.
    private func addressOpacity(safeAreaTop: CGFloat) -> CGFloat {
        let inset = max(safeAreaTop, 1)
        let clamped = min(max(searchBarOffset, -inset), 0)
        return min(max(1 - (clamped / -inset), 0), 1)
    }

    /// GeometryReader reports 0 for the top inset when it is itself laid out below the status bar.
    /// Fall back to the window so the header still pads by a real notch height.
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
