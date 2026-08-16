//
//  ProductCard.swift
//  SpiceMonk
//

import SwiftUI

struct ProductCard: View {

    let product: ProductItem

    var body: some View {
        VStack(spacing: 0) {
            imageArea
            textBlock
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }

    private var imageArea: some View {
        RemoteImage(url: product.imageUrl, contentMode: .fit)
            .padding(6)
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
                leadingBadge
                    .padding(6)
            }
            .overlay(alignment: .topTrailing) {
                if product.variantsCount > 1 {
                    badge("\(product.variantsCount) sizes", fill: .white, text: AppTheme.textSecondary)
                        .padding(6)
                }
            }
            .padding(8)
    }

    /// Discount wins over NEW: a shopper scanning a rail cares more about the saving than the age
    /// of the listing, and stacking both badges crowds a 140pt card.
    @ViewBuilder
    private var leadingBadge: some View {
        if product.hasDiscount && product.discountPercent > 0 {
            badge("\(product.discountPercent)% OFF", fill: AppTheme.discountBadge, text: .white)
        } else if product.isNew {
            badge("NEW", fill: AppTheme.newBadgeBackground, text: AppTheme.newBadgeText)
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

    /// A fixed height here is what lets cards in a rail or grid line their prices up, regardless of
    /// whether a name wraps to one line or two.
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(product.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !product.weight.isEmpty {
                Text(product.weight)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 78, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private func badge(_ text: String, fill: Color, text textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Remote image

/// `AsyncImage` with the states the feed actually needs: a tinted placeholder while loading and a
/// neutral glyph when a URL is missing or fails, so a broken image never collapses a card's layout.
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
