//
//  HomeModels.swift
//  SpiceMonk
//

import Foundation

/// How a widget's items are laid out. The API sends `normal_lazy_row`, `normal_vertical_grid`, or
/// nothing at all; anything unrecognised falls back to a horizontal rail, as on Android.
enum WidgetLayout {
    case lazyRow
    case verticalGrid

    init(apiValue: String?) {
        self = apiValue == "normal_vertical_grid" ? .verticalGrid : .lazyRow
    }
}

/// The home feed is server-driven: the backend decides which sections appear and in what order,
/// and each `type` carries a differently shaped `data` array. Modelling that as an enum keeps the
/// mismatched payloads apart instead of collapsing them into one struct full of optionals.
enum HomeWidget: Identifiable {
    case banner(id: Int, items: [BannerItem])
    case categories(id: Int, title: String?, layout: WidgetLayout, items: [CategoryItem])
    case brands(id: Int, title: String?, items: [BrandItem])
    case products(id: Int, title: String?, layout: WidgetLayout, hasMore: Bool, items: [ProductItem])

    var id: Int {
        switch self {
        case .banner(let id, _),
             .categories(let id, _, _, _),
             .brands(let id, _, _),
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

    var hasDiscount: Bool {
        !customerPrice.isEmpty && customerPrice != mrp && (discountPercent > 0 || saveAmount > 0)
    }

    var inStock: Bool {
        availableQty > 0
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

        case "brand_list":
            let items = (try? container.decode([BrandItem].self, forKey: .data)) ?? []
            widget = items.isEmpty ? nil : .brands(id: id, title: title, items: items)

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
