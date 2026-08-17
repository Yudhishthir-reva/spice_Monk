//
//  HomeModels.swift
//  SpiceMonk
//

import Foundation

/// How a widget's items are laid out. The API sends `normal_lazy_row`, `normal_vertical_grid`,
/// `black_lazy_row`, or nothing at all; anything unrecognised falls back to a horizontal rail so a
/// layout added server-side degrades instead of blanking the section.
enum WidgetLayout {
    case lazyRow
    case verticalGrid
    /// Dark "featured" rail. Only `product_list` uses it.
    case blackLazyRow

    init(apiValue: String?) {
        switch apiValue {
        case "normal_vertical_grid":
            self = .verticalGrid
        case "black_lazy_row":
            self = .blackLazyRow
        default:
            self = .lazyRow
        }
    }
}

/// The home feed is server-driven: the backend decides which sections appear and in what order,
/// and each `type` carries a differently shaped `data` array. Modelling that as an enum keeps the
/// mismatched payloads apart instead of collapsing them into one struct full of optionals.
enum HomeWidget: Identifiable {
    case banner(id: Int, items: [BannerItem])
    case categories(id: Int, title: String?, layout: WidgetLayout, items: [CategoryItem])
    /// `category_list` — the same categories, but grouped under the brand they belong to.
    case categoryGroups(id: Int, title: String?, layout: WidgetLayout, groups: [BrandCategoryGroup])
    case brands(id: Int, title: String?, layout: WidgetLayout, items: [BrandItem])
    case products(id: Int, title: String?, layout: WidgetLayout, hasMore: Bool, items: [ProductItem])

    var id: Int {
        switch self {
        case .banner(let id, _),
             .categories(let id, _, _, _),
             .categoryGroups(let id, _, _, _),
             .brands(let id, _, _, _),
             .products(let id, _, _, _, _):
            return id
        }
    }
}

// MARK: - Items

struct BannerItem: Decodable, Identifiable {
    let id: Int
    let imageUrl: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, image
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        imageUrl = container.decodeStringLeniently(forKey: .image)
        sortOrder = container.decodeIntLeniently(forKey: .sortOrder) ?? 0
    }
}

/// Categories and brands arrive with identical fields and are rendered by the same chip.
struct CategoryItem: Decodable, Identifiable {
    let id: Int
    let name: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        imageUrl = container.decodeStringLeniently(forKey: .image)
    }
}

typealias BrandItem = CategoryItem

/// One brand and the categories filed under it, as sent by `category_list`. The brand's own key is
/// `brand_id` here rather than `id`, and its label is `title` rather than `name`.
struct BrandCategoryGroup: Decodable, Identifiable {
    let id: Int
    let title: String
    let brandImageUrl: String?
    let categories: [CategoryItem]

    enum CodingKeys: String, CodingKey {
        case title, categories
        case id = "brand_id"
        case brandImageUrl = "brand_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        // Backend titles often arrive as "Spice Monk Categories" / "… Categorys". Android strips
        // those suffixes so the heading is just the brand name.
        var raw = container.decodeStringLeniently(forKey: .title) ?? ""
        if raw.hasSuffix(" Categorys") { raw.removeLast(" Categorys".count) }
        if raw.hasSuffix(" Categories") { raw.removeLast(" Categories".count) }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        title = cleaned.isEmptyString ? "Brand" : cleaned
        brandImageUrl = container.decodeStringLeniently(forKey: .brandImageUrl)
        categories = (try? container.decode([CategoryItem].self, forKey: .categories)) ?? []
    }
}

struct ProductVariant: Decodable, Identifiable {
    let id: Int
    let weight: String
    let mrp: String
    let customerPrice: String
    let discountPercent: Int
    let availableQty: Int

    enum CodingKeys: String, CodingKey {
        case weight, mrp
        case id = "variant_id"
        case customerPrice = "customer_price"
        case discountPercent = "discount_percent"
        case availableQty = "avl_qty"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        weight = container.decodeStringLeniently(forKey: .weight) ?? ""
        mrp = container.decodeStringLeniently(forKey: .mrp) ?? ""
        customerPrice = container.decodeStringLeniently(forKey: .customerPrice) ?? ""
        discountPercent = ProductItem.wholePercent(from: container, key: .discountPercent)
        availableQty = container.decodeIntLeniently(forKey: .availableQty) ?? 0
    }
}

struct ProductItem: Decodable, Identifiable {
    let id: Int
    let name: String
    let imageUrl: String?
    let isNew: Bool
    let mrp: String
    let customerPrice: String
    let saveAmount: Int
    let discountPercent: Int
    let weight: String
    let availableQty: Int
    let variantsCount: Int
    let variants: [ProductVariant]

    enum CodingKeys: String, CodingKey {
        case id, name, image, mrp, weight, variants
        case isNew = "is_new"
        case customerPrice = "customer_price"
        case saveAmount = "save_amount"
        case discountPercent = "discount_percent"
        case availableQty = "avl_qty"
        case variantsCount = "variants_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        imageUrl = container.decodeStringLeniently(forKey: .image)
        isNew = container.decodeBoolLeniently(forKey: .isNew) ?? false
        mrp = container.decodeStringLeniently(forKey: .mrp) ?? ""
        customerPrice = container.decodeStringLeniently(forKey: .customerPrice) ?? ""
        saveAmount = Self.wholePercent(from: container, key: .saveAmount)
        discountPercent = Self.wholePercent(from: container, key: .discountPercent)
        weight = container.decodeStringLeniently(forKey: .weight) ?? ""
        availableQty = container.decodeIntLeniently(forKey: .availableQty) ?? 0
        variantsCount = container.decodeIntLeniently(forKey: .variantsCount) ?? 0
        variants = (try? container.decode([ProductVariant].self, forKey: .variants)) ?? []
    }

    /// The backend returns percentages as raw float artifacts — `32.20000000000000284…` for what is
    /// really 32.2 — so they are truncated to a whole number before they ever reach the UI. Android
    /// truncates the same way, which keeps both apps showing an identical badge.
    static func wholePercent<K: CodingKey>(from container: KeyedDecodingContainer<K>, key: K) -> Int {
        if let double = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(double)
        }
        if let string = try? container.decodeIfPresent(String.self, forKey: key), let value = Double(string) {
            return Int(value)
        }
        return 0
    }

    /// Products without a customer price fall back to MRP so the card never shows a blank price.
    var displayPrice: String {
        customerPrice.isEmpty ? mrp : customerPrice
    }

    /// Server value when present, otherwise derived from MRP − selling price — matching Android.
    var effectiveSaveAmount: Int {
        saveAmount > 0 ? saveAmount : Self.priceGap(mrp: mrp, price: displayPrice)
    }

    /// Server value when present, otherwise derived (rounded) from the two prices.
    var effectiveDiscountPercent: Int {
        discountPercent > 0 ? discountPercent : Self.percentGap(mrp: mrp, price: displayPrice)
    }

    /// True when the selling price undercuts MRP. No longer waits for the server to send save fields.
    var hasDiscount: Bool {
        !customerPrice.isEmpty && Self.parsePrice(displayPrice) < Self.parsePrice(mrp)
    }

    var inStock: Bool {
        availableQty > 0
    }

    static func parsePrice(_ raw: String) -> Double {
        Double(raw.trim.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    static func priceGap(mrp: String, price: String) -> Int {
        max(Int(parsePrice(mrp) - parsePrice(price)), 0)
    }

    static func percentGap(mrp: String, price: String) -> Int {
        let mrpValue = parsePrice(mrp)
        guard mrpValue > 0 else { return 0 }
        let saved = max(mrpValue - parsePrice(price), 0)
        return Int((saved / mrpValue * 100).rounded())
    }
}

// MARK: - Response

struct HomeResponse: Decodable {
    let status: Bool?
    let message: String?
    let widgets: [HomeWidget]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)

        let decoded = (try? container.decode([DecodedWidget].self, forKey: .data)) ?? []
        widgets = decoded.compactMap(\.widget)
    }
}

/// Wraps a single widget so a section the app does not understand — a new `type` shipped by the
/// backend, or one whose items fail to parse — drops out on its own instead of failing the whole
/// feed. Empty sections are dropped too, since a header with nothing under it is just a gap.
private struct DecodedWidget: Decodable {

    let widget: HomeWidget?

    enum CodingKeys: String, CodingKey {
        case type, layout, title, data
        case widgetId = "widget_id"
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = container.decodeIntLeniently(forKey: .widgetId) ?? 0
        let title = container.decodeStringLeniently(forKey: .title)
        let layout = WidgetLayout(apiValue: container.decodeStringLeniently(forKey: .layout))

        switch container.decodeStringLeniently(forKey: .type) {
        case "banner":
            let items = (try? container.decode([BannerItem].self, forKey: .data)) ?? []
            let ordered = items.sorted { $0.sortOrder < $1.sortOrder }
            widget = ordered.isEmpty ? nil : .banner(id: id, items: ordered)

        case "only_category_list":
            let items = (try? container.decode([CategoryItem].self, forKey: .data)) ?? []
            widget = items.isEmpty ? nil : .categories(id: id, title: title, layout: layout, items: items)

        case "category_list":
            // A brand with no categories draws an empty heading, so those groups go first and the
            // widget disappears if nothing is left.
            let groups = ((try? container.decode([BrandCategoryGroup].self, forKey: .data)) ?? [])
                .filter { !$0.categories.isEmpty }
            widget = groups.isEmpty
                ? nil
                : .categoryGroups(id: id, title: title, layout: layout, groups: groups)

        case "brand_list":
            let items = (try? container.decode([BrandItem].self, forKey: .data)) ?? []
            widget = items.isEmpty ? nil : .brands(id: id, title: title, layout: layout, items: items)

        case "product_list":
            let items = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
            let hasMore = container.decodeBoolLeniently(forKey: .hasMore) ?? false
            widget = items.isEmpty
                ? nil
                : .products(id: id, title: title, layout: layout, hasMore: hasMore, items: items)

        default:
            widget = nil
        }
    }
}

// MARK: - Widget products (See all)

/// `customer/widget/products` puts `widget_title` / `layout` / `pagination` next to `data`, not
/// nested the way `customer/home` does.
struct WidgetProductsResponse: Decodable {
    let status: Bool?
    let message: String?
    let widgetTitle: String?
    let layout: WidgetLayout
    let products: [ProductItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, layout, data, pagination
        case widgetTitle = "widget_title"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        widgetTitle = container.decodeStringLeniently(forKey: .widgetTitle)
        layout = WidgetLayout(apiValue: container.decodeStringLeniently(forKey: .layout))
        products = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

/// `customer/category/products` — same product + pagination shape as widget products, with
/// `category_name` as the screen title instead of `widget_title`.
struct CategoryProductsResponse: Decodable {
    let status: Bool?
    let message: String?
    let categoryName: String?
    let products: [ProductItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
        case categoryName = "category_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        categoryName = container.decodeStringLeniently(forKey: .categoryName)
        products = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

/// `customer/brand/products` — same catalog envelope as category products, keyed by `brand_name`.
struct BrandProductsResponse: Decodable {
    let status: Bool?
    let message: String?
    let brandName: String?
    let products: [ProductItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
        case brandName = "brand_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        brandName = container.decodeStringLeniently(forKey: .brandName)
        products = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

/// `customer/banner/products` has no title field — the screen falls back to "Offers", matching Android.
struct BannerProductsResponse: Decodable {
    let status: Bool?
    let message: String?
    let products: [ProductItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        products = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

/// `customer/product/related` — same product-array + pagination envelope as banner products.
struct RelatedProductsResponse: Decodable {
    let status: Bool?
    let message: String?
    let products: [ProductItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        products = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

/// `customer/product/search` — same envelope; optional `query` / category / brand / product filters.
struct SearchProductsResponse: Decodable {
    let status: Bool?
    let message: String?
    let products: [ProductItem]
    let pagination: PageInfo

    enum CodingKeys: String, CodingKey {
        case status, message, data, pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        products = (try? container.decode([ProductItem].self, forKey: .data)) ?? []
        pagination = (try? container.decode(PageInfo.self, forKey: .pagination)) ?? .empty
    }
}

struct PageInfo: Decodable {
    let currentPage: Int
    let lastPage: Int
    let perPage: Int
    let total: Int
    let hasMore: Bool

    static let empty = PageInfo(currentPage: 1, lastPage: 1, perPage: 10, total: 0, hasMore: false)

    enum CodingKeys: String, CodingKey {
        case total
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case hasMore = "has_more"
    }

    init(currentPage: Int, lastPage: Int, perPage: Int, total: Int, hasMore: Bool) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.perPage = perPage
        self.total = total
        self.hasMore = hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 1
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 10
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        hasMore = container.decodeBoolLeniently(forKey: .hasMore)
            ?? (currentPage < lastPage)
    }
}

// MARK: - Product detail

/// Envelope for `customer/product/detail`. `data` is a single object, not an array.
struct ProductDetailResponse: Decodable {
    let status: Bool?
    let message: String?
    let product: ProductDetail?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        let decoded = try? container.decode(ProductDetail.self, forKey: .data)
        product = (decoded?.id ?? 0) > 0 ? decoded : nil
    }
}

struct ProductDetail: Decodable, Identifiable {
    let id: Int
    let name: String
    let images: [String]
    let description: String?
    let isNew: Bool
    let category: ProductNamedRef?
    let brand: ProductNamedRef?
    let variants: [ProductDetailVariant]

    enum CodingKeys: String, CodingKey {
        case id, name, images, description, category, brand, variants
        case isNew = "is_new"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        description = container.decodeStringLeniently(forKey: .description)
        isNew = container.decodeBoolLeniently(forKey: .isNew) ?? false
        category = ProductNamedRef.decodeIfPresent(container, forKey: .category)
        brand = ProductNamedRef.decodeIfPresent(container, forKey: .brand)
        variants = (try? container.decode([ProductDetailVariant].self, forKey: .variants)) ?? []

        if let urls = try? container.decode([String?].self, forKey: .images) {
            images = urls.compactMap { url in
                let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
        } else {
            images = []
        }
    }

    var defaultVariantIndex: Int {
        variants.firstIndex(where: \.inStock) ?? 0
    }
}

struct ProductNamedRef: Decodable, Identifiable {
    let id: Int
    let name: String

    static func decodeIfPresent<K: CodingKey>(
        _ container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> ProductNamedRef? {
        guard let ref = try? container.decode(ProductNamedRef.self, forKey: key) else { return nil }
        guard ref.id > 0, !ref.name.isEmptyString else { return nil }
        return ref
    }
}

struct ProductDetailVariant: Decodable, Identifiable {
    let id: Int
    let weight: String
    let mrp: String
    let customerPrice: String
    let saveAmount: Int
    let discountPercent: Double
    let availableQty: Int
    let gst: String

    enum CodingKeys: String, CodingKey {
        case weight, mrp, gst
        case id = "variant_id"
        case customerPrice = "customer_price"
        case saveAmount = "save_amount"
        case discountPercent = "discount_percent"
        case availableQty = "avl_qty"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        weight = container.decodeStringLeniently(forKey: .weight) ?? ""
        mrp = container.decodeStringLeniently(forKey: .mrp) ?? ""
        customerPrice = container.decodeStringLeniently(forKey: .customerPrice) ?? ""
        saveAmount = ProductItem.wholePercent(from: container, key: .saveAmount)
        discountPercent = container.decodeDoubleLeniently(forKey: .discountPercent) ?? 0
        availableQty = container.decodeIntLeniently(forKey: .availableQty) ?? 0
        gst = container.decodeStringLeniently(forKey: .gst) ?? ""
    }

    var displayPrice: String {
        customerPrice.isEmpty ? mrp : customerPrice
    }

    var effectiveSaveAmount: Int {
        saveAmount > 0 ? saveAmount : ProductItem.priceGap(mrp: mrp, price: displayPrice)
    }

    var hasDiscount: Bool {
        !customerPrice.isEmpty && ProductItem.parsePrice(displayPrice) < ProductItem.parsePrice(mrp)
    }

    var inStock: Bool {
        availableQty > 0
    }

    /// Android rounds the detail badge; home cards still truncate.
    var discountPercentRounded: Int {
        if discountPercent > 0 {
            return Int(discountPercent.rounded())
        }
        return ProductItem.percentGap(mrp: mrp, price: displayPrice)
    }
}

// MARK: - Search suggestions

/// What a `customer/product/suggestions` row points at — decides which screen a tap opens.
enum SuggestionKind {
    case category
    case brand
    case product
    case variant
    case unknown
}

/// Type-ahead row. `id` is reused across variants of the same product (Hing 25 gms / 50 gms), so
/// `Identifiable.id` is a composite of label + entity + display name.
struct SearchSuggestion: Decodable, Identifiable {
    let label: String
    let entityId: Int
    let name: String
    let variantName: String?

    var id: String {
        "\(label)_\(entityId)_\(name)_\(variantName ?? "")"
    }

    var kind: SuggestionKind {
        switch label.trim.lowercased() {
        case "category": return .category
        case "brand": return .brand
        case "product": return .product
        case "variant": return .variant
        default: return .unknown
        }
    }

    var kindTitle: String {
        switch kind {
        case .category: return "Category"
        case .brand: return "Brand"
        case .product: return "Product"
        case .variant: return "Variant"
        case .unknown: return "Search"
        }
    }

    var kindIcon: String {
        switch kind {
        case .category: return "square.grid.2x2.fill"
        case .brand: return "storefront.fill"
        case .product: return "bag.fill"
        case .variant: return "scalemass.fill"
        case .unknown: return "magnifyingglass"
        }
    }

    enum CodingKeys: String, CodingKey {
        case label, id, name
        case variantName = "variant_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = container.decodeStringLeniently(forKey: .label) ?? ""
        entityId = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        variantName = container.decodeStringLeniently(forKey: .variantName)
    }
}

struct SearchSuggestionsResponse: Decodable {
    let status: Bool?
    let message: String?
    let suggestions: [SearchSuggestion]

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        message = container.decodeStringLeniently(forKey: .message)
        suggestions = (try? container.decode([SearchSuggestion].self, forKey: .data)) ?? []
    }
}
