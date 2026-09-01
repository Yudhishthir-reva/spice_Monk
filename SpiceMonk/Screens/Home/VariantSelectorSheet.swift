//
//  VariantSelectorSheet.swift
//  SpiceMonk
//

import SwiftUI

struct VariantSelectorSheet: View {

    let product: ProductItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cart = CartStore.shared

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(product.variants) { variant in
                        variantRow(variant)
                    }
                }
                .padding(16)
            }
        }
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RemoteImage(url: product.imageUrl, contentMode: .fit)
                .padding(4)
                .frame(width: 48, height: 48)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text("Select size / variant")
                    .font(.appFont(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.appFont(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func variantRow(_ variant: ProductVariant) -> some View {
        let qty = cart.quantity(productId: product.id, variantId: variant.id)
        let busy = cart.isBusy(productId: product.id, variantId: variant.id)
        let stock = variant.availableQty > 0 ? variant.availableQty : product.availableQty
        let inCart = qty > 0

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(variant.weight.isEmptyString ? "Standard" : variant.weight)
                    .font(.appFont(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("₹\(variant.displayPrice)")
                        .font(.appFont(size: 15, weight: .heavy))
                        .foregroundStyle(AppTheme.textPrimary)

                    if variant.hasDiscount {
                        Text("₹\(variant.mrp)")
                            .font(.appFont(size: 12))
                            .strikethrough()
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    if variant.saveAmount > 0 {
                        Text("Save ₹\(variant.saveAmount)")
                            .font(.appFont(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accentGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }

            Spacer()

            CartQtyStepper(
                qty: qty,
                inStock: variant.inStock,
                canIncrement: cart.canIncrement(productId: product.id, variantId: variant.id, availableQty: stock),
                isBusy: busy,
                compact: true,
                onIncrement: {
                    let maxQty = cart.line(productId: product.id, variantId: variant.id)?.maxOrderQty
                    cart.incrementOrAdd(
                        productId: product.id,
                        variantId: variant.id,
                        availableQty: stock,
                        maxOrderQty: maxQty
                    )
                },
                onDecrement: {
                    cart.decrement(productId: product.id, variantId: variant.id)
                }
            )
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(inCart ? AppTheme.accentGreen : AppTheme.fieldBorder, lineWidth: inCart ? 1.5 : 1)
        }
    }
}

struct VariantSheetActionKey: EnvironmentKey {
    static let defaultValue: ((ProductItem) -> Void)? = nil
}

extension EnvironmentValues {
    var onSelectVariantSheet: ((ProductItem) -> Void)? {
        get { self[VariantSheetActionKey.self] }
        set { self[VariantSheetActionKey.self] = newValue }
    }
}
