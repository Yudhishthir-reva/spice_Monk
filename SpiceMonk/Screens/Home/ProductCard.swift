//
//  ProductCard.swift
//  SpiceMonk
//

import SwiftUI

/// Catalog cell: image, then name, weight & options, price + savings, then ADD / qty stepper.
struct ProductCard: View {

    let product: ProductItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea

            VStack(alignment: .leading, spacing: 6) {
                NavigationLink {
                    ProductDetailScreen(
                        productId: product.id,
                        seedName: product.name,
                        seedImageUrl: product.imageUrl
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

                        HStack(spacing: 4) {
                            if !product.weight.isEmptyString {
                                Text(product.weight)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            if product.variantsCount > 1 {
                                HStack(spacing: 2) {
                                    Text("\(product.variantsCount) options")
                                        .font(.system(size: 9.5, weight: .bold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 6.5, weight: .bold))
                                }
                                .foregroundStyle(AppTheme.brandGreen)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1.5)
                                .background(AppTheme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }
                        .frame(height: 18, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("₹\(product.displayPrice)")
                                .font(.system(size: 14.5, weight: .heavy))
                                .foregroundStyle(AppTheme.textPrimary)

                            if product.hasDiscount {
                                Text("₹\(product.mrp)")
                                    .font(.system(size: 10.5))
                                    .strikethrough()
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                        }
                        .frame(height: 18, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                        Group {
                            if product.effectiveSaveAmount > 0 {
                                Text("Save ₹\(product.effectiveSaveAmount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.brandGreen)
                            } else {
                                Text(" ")
                                    .font(.system(size: 10))
                            }
                        }
                        .frame(height: 14, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                ProductCartControl(product: product)
            }
            .padding(.horizontal, 7)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var imageArea: some View {
        NavigationLink {
            ProductDetailScreen(
                productId: product.id,
                seedName: product.name,
                seedImageUrl: product.imageUrl
            )
        } label: {
            ZStack(alignment: .center) {
                AppTheme.imageTile

                RemoteImage(url: product.imageUrl, contentMode: .fit)
                    .padding(6)
            }
            .frame(height: 104)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .center) {
                if !product.inStock {
                    outOfStockOverlay
                }
            }
            .overlay(alignment: .topLeading) {
                leadingBadges
                    .padding(5)
            }
            .padding(5)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingBadges: some View {
        VStack(alignment: .leading, spacing: 3) {
            if product.hasDiscount && product.effectiveDiscountPercent > 0 {
                badge("\(product.effectiveDiscountPercent)% OFF", fill: AppTheme.brandGreen, text: .white)
            }
            if product.isNew {
                badge("NEW", fill: AppTheme.newBadgeBackground, text: AppTheme.newBadgeText)
            }
        }
    }

    private var outOfStockOverlay: some View {
        ZStack {
            Color.white.opacity(0.7)
            Text("Out of stock")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
        }
    }

    private func badge(_ text: String, fill: Color, text textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

#Preview {
    HStack(spacing: 12) {
        ProductCard(product: .preview)
            .frame(width: 140)
    }
    .padding()
    .background(AppTheme.imageTile)
}

extension ProductItem {
    /// Mirrors a real "Kasuri Methi" entry from `customer/home` so previews exercise the badge and
    /// strikethrough paths rather than idealised data.
    static var preview: ProductItem {
        let json = """
        {
            "id": 21,
            "name": "Kasuri Methi",
            "image": null,
            "is_new": true,
            "mrp": "32",
            "customer_price": "20",
            "save_amount": 12,
            "discount_percent": 37.5,
            "weight": "25 gms",
            "avl_qty": 100,
            "variants_count": 5,
            "variants": []
        }
        """
        return try! JSONDecoder().decode(ProductItem.self, from: Data(json.utf8))
    }
}

extension View {

    func productDetailDestination(_ product: ProductItem) -> some View {
        NavigationLink {
            ProductDetailScreen(
                productId: product.id,
                seedName: product.name,
                seedImageUrl: product.imageUrl
            )
        } label: {
            self
        }
        .buttonStyle(.plain)
    }
}

/// ADD / qty stepper on listing cards. Lives outside the image `NavigationLink` so taps do not
/// open product detail. Hidden when the payload has no `variant_id` to send.
struct ProductCartControl: View {

    let product: ProductItem
    @Environment(\EnvironmentValues.onSelectVariantSheet) private var onSelectVariantSheet
    @ObservedObject private var cart = CartStore.shared

    var body: some View {
        if !product.inStock && cartTotalQuantity == 0 {
            Text("Sold out")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color(hex: "71717A"))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(Color(hex: "E4E4E7").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if (product.variantsCount > 1 || product.variants.count > 1), let onSelectVariantSheet {
            let totalQty = cartTotalQuantity
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelectVariantSheet(product)
            } label: {
                HStack(spacing: 3) {
                    Text(totalQty > 0 ? "\(totalQty) IN CART" : "ADD +")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.4)
                }
                .foregroundStyle(AppTheme.brandGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.brandGreen, lineWidth: 1.4)
                }
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            }
            .buttonStyle(.borderless)
        } else if let variant = product.defaultCartVariant, variant.id > 0 {
            let qty = cart.quantity(productId: product.id, variantId: variant.id)
            let busy = cart.isBusy(productId: product.id, variantId: variant.id)
            let stock = variant.availableQty > 0 ? variant.availableQty : product.availableQty
            CartQtyStepper(
                qty: qty,
                inStock: product.inStock,
                canIncrement: stock <= 0 || qty < stock,
                isBusy: busy,
                listing: true,
                fullWidth: true,
                onIncrement: {
                    cart.addOrIncrement(productId: product.id, variantId: variant.id, availableQty: stock)
                },
                onDecrement: {
                    cart.decrement(productId: product.id, variantId: variant.id)
                }
            )
        }
    }

    private var cartTotalQuantity: Int {
        if product.variants.isEmpty {
            if let variant = product.defaultCartVariant {
                return cart.quantity(productId: product.id, variantId: variant.id)
            }
            return 0
        }
        return product.variants.reduce(0) { $0 + cart.quantity(productId: product.id, variantId: $1.id) }
    }
}
