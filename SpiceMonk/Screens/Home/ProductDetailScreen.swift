//
//  ProductDetailScreen.swift
//  SpiceMonk
//

import SwiftUI

/// Blinkit-style product page: hero gallery, live price from the selected variant, and a sticky
/// add-to-cart bar that becomes a stepper once the line is in the cart.
struct ProductDetailScreen: View {

    @StateObject var viewModel: ProductDetailViewModel
    @ObservedObject private var cart = CartStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCart: Bool = false

    init(productId: Int, seedName: String, seedImageUrl: String?) {
        _viewModel = StateObject(
            wrappedValue: ProductDetailViewModel(
                productId: productId,
                seedName: seedName,
                seedImageUrl: seedImageUrl
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.notFound {
                missingState
            } else if let error = viewModel.loadError, viewModel.product == nil {
                HomeErrorState(message: error) {
                    viewModel.load()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                detailBody
            }
        }
        .background(Color.white)
        .spiceNavigationBar(title: viewModel.product?.name ?? viewModel.seedName)
        .navigationDestination(isPresented: $showCart) {
            CartScreen()
        }
        .onAppear {
            CartStore.shared.loadIfNeeded()
            if viewModel.product == nil, !viewModel.notFound {
                viewModel.load()
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .cartStoreToast()
    }

    private var missingState: some View {
        VStack(spacing: 8) {
            Text("Product not found")
                .font(.appFont(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("This product may have been removed or is no longer available.")
                .font(.appFont(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero

                    if let product = viewModel.product {
                        loadedContent(product)
                        relatedRail
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(.bottom, 24)
            }

            VStack(spacing: 0) {
                FloatingCartBar {
                    showCart = true
                }

                if let variant = viewModel.selectedVariant {
                    stickyBar(variant)
                }
            }
        }
    }

    private var hero: some View {
        let images = viewModel.heroImages
        let discount = viewModel.selectedVariant?.discountPercentRounded ?? 0

        return ZStack(alignment: .topTrailing) {
            TabView {
                if images.isEmpty {
                    AppTheme.heroTile
                } else {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, url in
                        RemoteImage(url: url, contentMode: .fit)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 44)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .background(AppTheme.heroTile)

            VStack(alignment: .trailing, spacing: 6) {
                if discount > 0 {
                    heroBadge("\(discount)% OFF", fill: AppTheme.discountBadge, foreground: .white)
                }
                if viewModel.product?.isNew == true {
                    heroBadge("NEW", fill: AppTheme.newBadgeBackground, foreground: AppTheme.newBadgeText)
                }
            }
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func loadedContent(_ product: ProductDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(product.name)
                    .font(.appFont(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)

                if let weight = viewModel.selectedVariant?.weight, !weight.isEmptyString {
                    Text(weight)
                        .font(.appFont(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let variant = viewModel.selectedVariant {
                    priceBlock(variant)
                }
            }

            if product.variants.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select size")
                        .font(.appFont(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    variantChips(product.variants)
                }
            }

            urgencyLine(product)

            trustRow(gst: viewModel.selectedVariant?.gst ?? "")

            if let description = product.description, !description.isEmptyString {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About this product")
                        .font(.appFont(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(description)
                        .font(.appFont(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(4)
                }
            }

            if let category = product.category {
                NavigationLink {
                    CategoryProductsScreen(categoryId: category.id, title: category.name)
                } label: {
                    exploreCard(
                        title: "View more in “\(category.name)”",
                        subtitle: "Explore the full \(category.name) range"
                    )
                }
                .buttonStyle(.plain)
            }

            if let brand = product.brand {
                NavigationLink {
                    WidgetProductsScreen(brandId: brand.id, title: brand.name)
                } label: {
                    exploreCard(
                        title: "More from \(brand.name)",
                        subtitle: "Browse everything by \(brand.name)"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var relatedRail: some View {
        if !viewModel.related.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("You might also like")
                    .font(.appFont(size: 17, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(viewModel.related) { product in
                            ProductCard(product: product)
                                .frame(width: 140)
                                .onAppear {
                                    if product.id == viewModel.related.last?.id {
                                        viewModel.loadMoreRelated()
                                    }
                                }
                        }

                        if viewModel.isLoadingMoreRelated {
                            ProgressView()
                                .frame(width: 40, height: 140)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, 4)
        }
    }

    private func priceBlock(_ variant: ProductDetailVariant) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("₹\(variant.displayPrice)")
                .font(.appFont(size: 22, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)

            if variant.hasDiscount {
                Text("₹\(variant.mrp)")
                    .font(.appFont(size: 15))
                    .strikethrough()
                    .foregroundStyle(AppTheme.textMuted)

                if variant.effectiveSaveAmount > 0 {
                    Text("SAVE ₹\(variant.effectiveSaveAmount)")
                        .font(.appFont(size: 11, weight: .heavy))
                        .foregroundStyle(AppTheme.badgeSuccess)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.saveBadgeFill)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
        }
    }

    private func variantChips(_ variants: [ProductDetailVariant]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(variants.enumerated()), id: \.element.id) { index, variant in
                    let selected = index == viewModel.selectedVariantIndex
                    Button {
                        viewModel.selectVariant(at: index)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(variant.weight.isEmptyString ? "Variant \(index + 1)" : variant.weight)
                                .font(.appFont(size: 14, weight: .bold))
                                .foregroundStyle(variant.inStock ? AppTheme.textPrimary : AppTheme.textMuted)
                            Text(variant.inStock ? "₹\(variant.displayPrice)" : "Out of stock")
                                .font(.appFont(size: 12, weight: .medium))
                                .foregroundStyle(selected ? AppTheme.accentRed : AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 92, alignment: .leading)
                        .background(selected ? AppTheme.accentSoft : AppTheme.cardSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? AppTheme.accentRed : AppTheme.cardBorder, lineWidth: selected ? 1.5 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!variant.inStock)
                }
            }
        }
    }

    private func urgencyLine(_ product: ProductDetail) -> some View {
        let qty = viewModel.selectedVariant?.availableQty ?? 0
        let copy: (String, String, Color) = {
            if let variant = viewModel.selectedVariant, variant.inStock, (1...5).contains(qty) {
                return ("bolt.fill", "Only \(qty) left — order soon", AppTheme.accentRed)
            }
            if product.isNew {
                return ("sparkles", "Just launched — be among the first to try it", AppTheme.accentOrange)
            }
            return ("flame.fill", "Popular pick — selling fast", AppTheme.accentOrange)
        }()

        return HStack(spacing: 8) {
            Image(systemName: copy.0)
                .font(.appFont(size: 13, weight: .semibold))
            Text(copy.1)
                .font(.appFont(size: 14, weight: .semibold))
        }
        .foregroundStyle(copy.2)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(copy.2.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func trustRow(gst: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                trustChip("Inclusive of all taxes")
                if !gst.isEmptyString {
                    trustChip("GST \(gst)%")
                }
                trustChip("100% genuine")
            }
        }
    }

    private func trustChip(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.appFont(size: 12))
                .foregroundStyle(AppTheme.badgeSuccess)
            Text(text)
                .font(.appFont(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func exploreCard(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.appFont(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accentRed)
                .frame(width: 44, height: 44)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.appFont(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.appFont(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func stickyBar(_ variant: ProductDetailVariant) -> some View {
        let qty = cart.quantity(productId: viewModel.productId, variantId: variant.id)
        let busy = cart.isBusy(productId: viewModel.productId, variantId: variant.id)

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("₹\(variant.displayPrice)")
                        .font(.appFont(size: 18, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)
                    if variant.hasDiscount {
                        Text("₹\(variant.mrp)")
                            .font(.appFont(size: 11))
                            .strikethrough()
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                Text("Inclusive of all taxes")
                    .font(.appFont(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(minWidth: 90, alignment: .leading)

            if qty > 0 {
                detailQtyStepper(qty: qty, variant: variant, isBusy: busy)
            } else {
                Button(action: viewModel.addToCart) {
                    HStack(spacing: 8) {
                        Text("Add to cart")
                            .font(.appFont(size: 16, weight: .semibold))
                        Image(systemName: "cart.fill")
                            .font(.appFont(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!variant.inStock || !cart.canIncrement(productId: viewModel.productId, variantId: variant.id, availableQty: variant.availableQty))
                .opacity(variant.inStock ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
    }

    private func detailQtyStepper(qty: Int, variant: ProductDetailVariant, isBusy: Bool) -> some View {
        HStack(spacing: 0) {
            Button(action: viewModel.decrementCart) {
                Image(systemName: qty <= 1 ? "trash" : "minus")
                    .font(.appFont(size: 15, weight: .bold))
                    .frame(width: 52, height: 52)
            }

            Text("\(qty)")
                .font(.appFont(size: 18, weight: .heavy))
                .frame(maxWidth: .infinity)

            Button(action: viewModel.addToCart) {
                Image(systemName: "plus")
                    .font(.appFont(size: 15, weight: .bold))
                    .frame(width: 52, height: 52)
            }
            .disabled(!cart.canIncrement(productId: viewModel.productId, variantId: variant.id, availableQty: variant.availableQty))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(AppTheme.ctaGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .buttonStyle(.plain)
    }

    private func heroBadge(_ title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.appFont(size: 11, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
