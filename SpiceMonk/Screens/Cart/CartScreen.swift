//
//  CartScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Cart from `GET customer/cart`. Qty is display-only until the update endpoint is wired.
struct CartScreen: View {

    @StateObject var viewModel = CartViewModel()
    @State private var isConfirmingClear = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.loadError, viewModel.isEmpty {
                HomeErrorState(message: error) {
                    viewModel.load()
                }
            } else if viewModel.isEmpty {
                emptyState
            } else {
                cartBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { isConfirmingClear = true }
                        .disabled(viewModel.isClearing)
                }
            }
        }
        .confirmationDialog("Remove all items from your cart?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear cart", role: .destructive) { viewModel.clear() }
            Button("Cancel", role: .cancel) {}
        }
        .tint(AppTheme.accentRed)
        .onAppear {
            viewModel.load()
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    private var cartBody: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        ProductDetailScreen(
                            productId: item.productId,
                            seedName: item.productName,
                            seedImageUrl: item.productImage
                        )
                    } label: {
                        CartItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .opacity(viewModel.isRemoving(item) ? 0.45 : 1)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.remove(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await waitForRefresh() }

            summaryBar
        }
    }

    private var summaryBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text(viewModel.summary.itemCountLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if viewModel.summary.totalSavings > 0 {
                    Text("Saved \(viewModel.summary.savingsLabel)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(AppTheme.badgeSuccess)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.summary.payLabel)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    if viewModel.summary.totalMrp > viewModel.summary.totalCustomerPrice {
                        Text(viewModel.summary.mrpLabel)
                            .font(.system(size: 12))
                            .strikethrough()
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }

                Spacer()

                Button(action: viewModel.checkout) {
                    Text("Checkout")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .frame(height: 48)
                        .background(AppTheme.ctaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.accentRed)
                .frame(width: 72, height: 72)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            Text("Your cart is empty")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Add items from the shop to see them here.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
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

private struct CartItemRow: View {

    let item: CartItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: item.productImage, contentMode: .fit)
                .padding(6)
                .frame(width: 72, height: 72)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if !item.inStock {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.55))
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.productName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if item.hasDiscount, item.discountPercentTruncated > 0 {
                        Text("\(item.discountPercentTruncated)% OFF")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.discountBadge)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }

                if !item.variantName.isEmptyString {
                    Text(item.variantName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Qty \(item.qty)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.cardSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer(minLength: 0)

                    Text(item.subtotalLabel)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)

                    if item.hasDiscount {
                        Text(CartItem.money(item.mrp * Double(max(item.qty, 1))))
                            .font(.system(size: 11))
                            .strikethrough()
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }

                if !item.inStock {
                    Text("Out of stock")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accentRed)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }
}
