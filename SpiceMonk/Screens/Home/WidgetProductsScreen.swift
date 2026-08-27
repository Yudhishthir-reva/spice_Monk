//
//  WidgetProductsScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Paged product grid for widget "View all", brand chips, banner slides, and search results.
/// Loads `per_page=10` and appends further pages when the last cell appears.
struct WidgetProductsScreen: View {

    @StateObject var viewModel: WidgetProductsViewModel

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10, alignment: .topLeading),
            count: HomeMetrics.productColumns
        )
    }

    init(widgetId: Int, title: String) {
        _viewModel = StateObject(
            wrappedValue: WidgetProductsViewModel(source: .widget(id: widgetId), title: title)
        )
    }

    init(brandId: Int, title: String) {
        _viewModel = StateObject(
            wrappedValue: WidgetProductsViewModel(source: .brand(id: brandId), title: title)
        )
    }

    init(bannerId: Int, title: String = "Offers") {
        _viewModel = StateObject(
            wrappedValue: WidgetProductsViewModel(source: .banner(id: bannerId), title: title)
        )
    }

    init(searchQuery: String, title: String, categoryId: Int = 0, brandId: Int = 0, productId: Int = 0) {
        _viewModel = StateObject(
            wrappedValue: WidgetProductsViewModel(
                source: .search(
                    query: searchQuery,
                    categoryId: categoryId,
                    brandId: brandId,
                    productId: productId
                ),
                title: title
            )
        )
    }

    @State private var showCart: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isLoading && viewModel.products.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.loadError, viewModel.products.isEmpty {
                    HomeErrorState(message: error) {
                        viewModel.loadFirstPage()
                    }
                } else if viewModel.products.isEmpty {
                    emptyState
                } else {
                    productGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingCartBar {
                showCart = true
            }
        }
        .background(Color.white)
        .spiceNavigationBar(title: viewModel.title)
        .navigationDestination(isPresented: $showCart) {
            CartScreen()
        }
        .onAppear {
            if viewModel.products.isEmpty {
                viewModel.loadFirstPage()
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .cartStoreToast()
    }

    private var productGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.products) { product in
                    ProductCard(product: product)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .onAppear {
                            if product.id == viewModel.products.last?.id {
                                viewModel.loadMore()
                            }
                        }
                }
            }
            .padding(16)

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.bottom, 24)
            }
        }
        .refreshable { await waitForRefresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No products found")
                .font(.appFont(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("We couldn't find any products here.")
                .font(.appFont(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable { await waitForRefresh() }
    }

    private func waitForRefresh() async {
        viewModel.refresh()
        while viewModel.isRefreshing {
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
}
