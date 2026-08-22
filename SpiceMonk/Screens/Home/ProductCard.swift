//
//  ProductCard.swift
//  SpiceMonk
//

import SwiftUI

/// Catalog cell: image, then weight + ADD, then price, then name — Blinkit-style stacking,
/// SpiceMonk red for the add control.
struct ProductCard: View {

    let product: ProductItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea

            VStack(alignment: .leading, spacing: 5) {
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
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            if product.variantsCount > 1 {
                                Text("\(product.variantsCount) options")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.accentGreen)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(AppTheme.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("₹\(product.displayPrice)")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(AppTheme.textPrimary)

                            if product.hasDiscount {
                                Text("₹\(product.mrp)")
                                    .font(.system(size: 11))
                                    .strikethrough()
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                        }
                        .lineLimit(1)

                        if product.effectiveSaveAmount > 0 {
                            Text("Save ₹\(product.effectiveSaveAmount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.accentGreen)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                ProductCartControl(product: product)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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
            RemoteImage(url: product.imageUrl, contentMode: .fit)
                .padding(8)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .center) {
                    if !product.inStock {
                        outOfStockOverlay
                    }
                }
                .overlay(alignment: .topLeading) {
                    leadingBadges
                        .padding(6)
                }
                .padding(6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var leadingBadges: some View {
        VStack(alignment: .leading, spacing: 3) {
            if product.hasDiscount && product.effectiveDiscountPercent > 0 {
                badge("\(product.effectiveDiscountPercent)% OFF", fill: AppTheme.discountBadge, text: .white)
            }
            if product.isNew {
                badge("NEW", fill: AppTheme.newBadgeBackground, text: AppTheme.newBadgeText)
            }
        }
    }

    private var outOfStockOverlay: some View {
        ZStack {
            Color.white.opacity(0.6)
            Text("Out of stock")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func badge(_ text: String, fill: Color, text textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        if (product.variantsCount > 1 || product.variants.count > 1), let onSelectVariantSheet {
            let totalQty = product.variants.reduce(0) { $0 + cart.quantity(productId: product.id, variantId: $1.id) }
            Button {
                onSelectVariantSheet(product)
            } label: {
                HStack(spacing: 3) {
                    Text(totalQty > 0 ? "\(totalQty) IN CART" : "ADD +")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.4)
                }
                .foregroundStyle(AppTheme.accentRed)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.accentRed, lineWidth: 1.4)
                }
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            }
            .buttonStyle(.borderless)
        } else if let variant = product.defaultCartVariant, variant.id > 0 {
            let qty = cart.quantity(productId: product.id, variantId: variant.id)
            let busy = cart.isBusy(productId: product.id, variantId: variant.id)
            let stock = variant.availableQty > 0 ? variant.availableQty : product.availableQty
            if qty > 0 || product.inStock {
                CartQtyStepper(
                    qty: qty,
                    inStock: true,
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
    }
}
