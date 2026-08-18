//
//  CategoryProductsScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Products for one category. The left rail lists sibling chips from the home widget so switching
/// categories stays on this screen instead of stacking another push.
struct CategoryProductsScreen: View {

    @StateObject var viewModel: CategoryProductsViewModel

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12, alignment: .topLeading),
            count: viewModel.showsRail ? 2 : 3
        )
    }

    init(categoryId: Int, title: String, siblings: [CategoryItem] = []) {
        _viewModel = StateObject(
            wrappedValue: CategoryProductsViewModel(
                categoryId: categoryId,
                title: title,
                siblings: siblings
            )
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if viewModel.showsRail {
                CategoryRail(
                    categories: viewModel.siblings,
                    selectedId: viewModel.selectedId,
                    onSelect: viewModel.select
                )
            }

            pane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .tint(AppTheme.accentRed)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if viewModel.products.isEmpty && viewModel.loadError == nil {
                viewModel.loadFirstPage()
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .cartStoreToast()
    }

    @ViewBuilder
    private var pane: some View {
        if viewModel.isLoading && viewModel.products.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.loadError, viewModel.products.isEmpty {
            HomeErrorState(message: error) {
                viewModel.loadFirstPage()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.products.isEmpty {
            emptyState
        } else {
            productGrid
        }
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
            .padding(12)

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .refreshable { await waitForRefresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No products")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("This category has no products yet.")
                .font(.system(size: 14))
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

/// Country-Delight-style sidebar. Selected chip gets a soft red wash and a left accent bar.
private struct CategoryRail: View {

    let categories: [CategoryItem]
    let selectedId: Int
    let onSelect: (CategoryItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(categories) { category in
                    railItem(category)
                }
            }
            .padding(.vertical, 10)
        }
        .frame(width: 84)
        .frame(maxHeight: .infinity)
        .background(AppTheme.categoryRail)
    }

    private func railItem(_ category: CategoryItem) -> some View {
        let selected = category.id == selectedId

        return Button {
            onSelect(category)
        } label: {
            ZStack(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(AppTheme.accentRed)
                        .frame(width: 3, height: 34)
                }

                VStack(spacing: 4) {
                    RemoteImage(url: category.imageUrl, contentMode: .fit)
                        .padding(4)
                        .frame(width: 48, height: 48)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(category.name)
                        .font(.system(size: 10, weight: selected ? .bold : .medium))
                        .foregroundStyle(selected ? AppTheme.accentRed : AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .scaleEffect(selected ? 1 : 0.94)
            }
            .background(selected ? AppTheme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }
}
