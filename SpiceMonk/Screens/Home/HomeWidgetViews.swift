//
//  HomeWidgetViews.swift
//  SpiceMonk
//

import SwiftUI
import Combine

enum HomeMetrics {
    static let gutter: CGFloat = 16
    static let railSpacing: CGFloat = 10
    static let chipSpacing: CGFloat = 12
    static let cardWidth: CGFloat = 142

    static var screenWidth: CGFloat {
        (UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.bounds.width) ?? UIScreen.main.bounds.width
    }

    /// Dynamically scales columns (3 on phone portrait, 4-5 on larger screens/iPads) maintaining optimal card size.
    static var productColumns: Int {
        let width = screenWidth
        if width >= 1000 { return 6 }
        if width >= 700 { return 5 }
        if width >= 500 { return 4 }
        return 3
    }

    static var categoryColumns: Int {
        let width = screenWidth
        if width >= 1000 { return 8 }
        if width >= 700 { return 6 }
        if width >= 500 { return 5 }
        return 4
    }
}

// MARK: - Widget dispatch

/// Renders one server-driven section. The feed's order and composition come entirely from the API,
/// so this only decides how each known shape is drawn.
struct HomeWidgetBlock: View {

    let widget: HomeWidget

    var body: some View {
        switch widget {
        case .banner(_, let items):
            BannerCarousel(items: items)

        case .categories(_, let title, let layout, let items):
            CategorySectionPanel {
                section(title) {
                    if layout == .verticalGrid {
                        ChipGrid(items: items, destination: .categoryProducts)
                    } else {
                        ChipRow(items: items, destination: .categoryProducts)
                    }
                }
            }

        case .categoryGroups(_, let title, let layout, let groups):
            CategorySectionPanel {
                section(title) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            BrandCategoryBlock(group: group, layout: layout)
                        }
                    }
                }
            }

        case .brands(_, let title, let layout, let items):
            section(title) {
                if layout == .verticalGrid {
                    ChipGrid(items: items, destination: .brandProducts)
                } else {
                    ChipRow(items: items, destination: .brandProducts)
                }
            }

        case .products(let id, let title, let layout, let hasMore, let items):
            section(title, showsViewAll: hasMore, widgetId: id) {
                switch layout {
                case .verticalGrid:
                    ProductGrid(products: items)
                case .blackLazyRow:
                    BlackProductRow(products: items)
                case .lazyRow:
                    ProductRow(products: items)
                }
            }
        }
    }

    /// A null title means the backend wants no heading, so nothing is invented in its place. The
    /// "View all" affordance goes with the heading and disappears along with it.
    private func section<Content: View>(
        _ title: String?,
        showsViewAll: Bool = false,
        widgetId: Int = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title, !title.isEmptyString {
                SectionHeader(title: title, showsViewAll: showsViewAll, widgetId: widgetId)
            }
            content()
        }
    }
}

// MARK: - Category panel

/// Groups a category section off the cream canvas. Same tint and inset as Android's
/// `CategorySectionPanel`.
struct CategorySectionPanel<Content: View>: View {

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.categoryPanel)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
            }
            .padding(.horizontal, 8)
    }
}

// MARK: - Brand-grouped categories

/// One brand's heading followed by its categories. `category_list` repeats this per brand.
struct BrandCategoryBlock: View {

    let group: BrandCategoryGroup
    let layout: WidgetLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RemoteImage(url: group.brandImageUrl)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }

                Text(group.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, HomeMetrics.gutter)

            if layout == .verticalGrid {
                ChipGrid(items: group.categories, destination: .categoryProducts)
            } else {
                ChipRow(items: group.categories, destination: .categoryProducts)
            }
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {

    let title: String
    var showsViewAll: Bool = false
    var widgetId: Int = 0

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            if showsViewAll {
                NavigationLink {
                    WidgetProductsScreen(widgetId: widgetId, title: title)
                } label: {
                    HStack(spacing: 3) {
                        Text("View all")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(AppTheme.brandGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentSoft)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, HomeMetrics.gutter)
    }
}

// MARK: - Banner

/// Auto-advancing hero pager. Advancing pauses while the user is dragging so the carousel never
/// yanks a banner out from under a swipe.
struct BannerCarousel: View {

    let items: [BannerItem]

    @State private var selection = 0
    @State private var isInteracting = false

    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    WidgetProductsScreen(bannerId: item.id)
                } label: {
                    RemoteImage(url: item.imageUrl)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.04), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                        .padding(.horizontal, HomeMetrics.gutter)
                }
                .buttonStyle(.plain)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 180)
        .overlay(alignment: .bottom) {
            if items.count > 1 {
                pageIndicator
                    .padding(.bottom, 10)
            }
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in isInteracting = true }
                .onEnded { _ in isInteracting = false }
        )
        .onReceive(timer) { _ in
            guard items.count > 1, !isInteracting else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                selection = (selection + 1) % items.count
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(items.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index == selection ? 1 : 0.45))
                    .frame(width: index == selection ? 20 : 6, height: 5.5)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selection)
    }
}

// MARK: - Category / brand chips

/// Categories and brands share one chip, since the API returns the same id/name/image triple for
/// both and Android draws them identically.
struct CategoryChip: View {

    let item: CategoryItem

    var body: some View {
        VStack(spacing: 6) {
            RemoteImage(url: item.imageUrl, contentMode: .fit)
                .padding(7)
                .frame(width: 68, height: 68)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                }

            Text(item.name)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 76)
    }
}

@ViewBuilder
private func categoryChip(
    _ item: CategoryItem,
    siblings: [CategoryItem],
    destination: ChipDestination
) -> some View {
    switch destination {
    case .none:
        CategoryChip(item: item)
    case .categoryProducts:
        NavigationLink {
            CategoryProductsScreen(categoryId: item.id, title: item.name, siblings: siblings)
        } label: {
            CategoryChip(item: item)
        }
        .buttonStyle(.plain)
    case .brandProducts:
        NavigationLink {
            WidgetProductsScreen(brandId: item.id, title: item.name)
        } label: {
            CategoryChip(item: item)
        }
        .buttonStyle(.plain)
    }
}

enum ChipDestination {
    case none
    case categoryProducts
    case brandProducts
}

struct ChipRow: View {

    let items: [CategoryItem]
    var destination: ChipDestination = .none

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: HomeMetrics.chipSpacing) {
                ForEach(items) { item in
                    categoryChip(item, siblings: items, destination: destination)
                }
            }
            .padding(.horizontal, HomeMetrics.gutter)
        }
    }
}

/// Laid out as plain rows rather than a `LazyVGrid` because this sits inside the feed's own scroll
/// view, where a nested lazy grid cannot size itself.
struct ChipGrid: View {

    let items: [CategoryItem]
    var destination: ChipDestination = .none

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(items.chunked(into: HomeMetrics.categoryColumns).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { item in
                        categoryChip(item, siblings: items, destination: destination)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<(HomeMetrics.categoryColumns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, HomeMetrics.gutter)
    }
}

// MARK: - Products

struct ProductRow: View {

    let products: [ProductItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: HomeMetrics.railSpacing) {
                ForEach(products) { product in
                    ProductCard(product: product)
                        .frame(width: HomeMetrics.cardWidth)
                }
            }
            .padding(.horizontal, HomeMetrics.gutter)
            .padding(.vertical, 2)
        }
    }
}

struct ProductGrid: View {

    let products: [ProductItem]

    var body: some View {
        VStack(spacing: HomeMetrics.railSpacing) {
            ForEach(Array(products.chunked(into: HomeMetrics.productColumns).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: HomeMetrics.railSpacing) {
                    ForEach(row) { product in
                        ProductCard(product: product)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<(HomeMetrics.productColumns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, HomeMetrics.gutter)
    }
}

/// `black_lazy_row`: the same products on a dark slab, used to make a section read as featured.
struct BlackProductRow: View {

    let products: [ProductItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: HomeMetrics.railSpacing) {
                ForEach(products) { product in
                    BlackProductCard(product: product)
                        .frame(width: HomeMetrics.cardWidth)
                }
            }
            .padding(16)
        }
        .background(AppTheme.blackCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, HomeMetrics.gutter)
    }
}

private struct BlackProductCard: View {

    let product: ProductItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                ProductDetailScreen(
                    productId: product.id,
                    seedName: product.name,
                    seedImageUrl: product.imageUrl
                )
            } label: {
                ZStack(alignment: .center) {
                    Color.white

                    RemoteImage(url: product.imageUrl, contentMode: .fit)
                        .padding(6)
                }
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .center) {
                    if !product.inStock {
                        outOfStockOverlay
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)

            HStack(alignment: .center, spacing: 6) {
                Text(product.weight.isEmptyString ? " " : product.weight)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                ProductCartControl(product: product)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            NavigationLink {
                ProductDetailScreen(
                    productId: product.id,
                    seedName: product.name,
                    seedImageUrl: product.imageUrl
                )
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("₹\(product.displayPrice)")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)

                        if product.hasDiscount {
                            Text("₹\(product.mrp)")
                                .font(.system(size: 12))
                                .strikethrough()
                                .foregroundStyle(AppTheme.blackCardMuted)
                        }
                    }
                    .lineLimit(1)

                    Text(product.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
