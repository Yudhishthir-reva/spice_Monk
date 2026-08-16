//
//  HomeWidgetViews.swift
//  SpiceMonk
//

import SwiftUI
import Combine

private enum HomeMetrics {
    static let gutter: CGFloat = 16
    static let railSpacing: CGFloat = 12
    static let chipSpacing: CGFloat = 14
    static let cardWidth: CGFloat = 140
    static let productColumns = 3
    static let categoryColumns = 4
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
            section(title ?? "Categories") {
                if layout == .verticalGrid {
                    ChipGrid(items: items)
                } else {
                    ChipRow(items: items)
                }
            }

        case .brands(_, let title, let items):
            section(title ?? "Shop by Brand") {
                ChipRow(items: items)
            }

        case .products(_, let title, let layout, let hasMore, let items):
            section(title ?? "Products", showsViewAll: hasMore) {
                if layout == .verticalGrid {
                    ProductGrid(products: items)
                } else {
                    ProductRow(products: items)
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        showsViewAll: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, showsViewAll: showsViewAll)
            content()
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {

    let title: String
    var showsViewAll: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            if showsViewAll {
                HStack(spacing: 2) {
                    Text("View all")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(AppTheme.accentRed)
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .padding(.vertical, 4)
                .background(AppTheme.accentSoft)
                .clipShape(Capsule())
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
                RemoteImage(url: item.imageUrl)
                    .frame(maxWidth: .infinity)
                    .frame(height: 172)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, HomeMetrics.gutter)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 172)
        .overlay(alignment: .bottom) {
            if items.count > 1 {
                pageIndicator
                    .padding(.bottom, 12)
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
                    .fill(Color.white.opacity(index == selection ? 1 : 0.5))
                    .frame(width: index == selection ? 20 : 6, height: 6)
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
                .padding(6)
                .frame(width: 66, height: 66)
                .background(AppTheme.imageTile)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(item.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 74)
    }
}

struct ChipRow: View {

    let items: [CategoryItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: HomeMetrics.chipSpacing) {
                ForEach(items) { CategoryChip(item: $0) }
            }
            .padding(.horizontal, HomeMetrics.gutter)
        }
    }
}

/// Laid out as plain rows rather than a `LazyVGrid` because this sits inside the feed's own scroll
/// view, where a nested lazy grid cannot size itself.
struct ChipGrid: View {

    let items: [CategoryItem]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(items.chunked(into: HomeMetrics.categoryColumns).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { item in
                        CategoryChip(item: item)
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

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
