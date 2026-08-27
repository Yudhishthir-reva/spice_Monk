//
//  OrdersScreen.swift
//  SpiceMonk
//

import SwiftUI

struct OrdersScreen: View {
    
    @StateObject private var viewModel = OrdersViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCart = false
    
    private let statusFilters = [
        ("", "All"),
        ("0", "Pending"),
        ("1", "Confirmed"),
        ("2", "Processing"),
        ("3", "Shipped"),
        ("4", "Delivered"),
        ("5", "Cancelled")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Scrollable Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusFilters, id: \.0) { filter in
                        let isSelected = viewModel.selectedStatusFilter == filter.0
                        
                        Button {
                            viewModel.selectedStatusFilter = filter.0
                        } label: {
                            Text(filter.1)
                                .font(.appFont(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? AppTheme.brandGreen : Color.white)
                                .clipShape(Capsule())
                                .overlay {
                                    if !isSelected {
                                        Capsule()
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.white)
            .shadow(color: .black.opacity(0.03), radius: 3, y: 2)
            
            // Orders list
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.loadError, viewModel.orders.isEmpty {
                    VStack(spacing: 16) {
                        Text(error)
                            .font(.appFont(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.loadFirstPage()
                        }
                        .font(.appFont(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.orders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bag.badge.questionmark")
                            .font(.appFont(size: 40))
                            .foregroundStyle(AppTheme.textMuted)
                        Text("No Orders Found")
                            .font(.appFont(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("You haven't placed any orders matching this filter yet.")
                            .font(.appFont(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.orders) { order in
                                orderCard(order)
                                    .onAppear {
                                        viewModel.loadNextPageIfNeeded(currentOrder: order)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "F5F5F5"))

            FloatingCartBar {
                showCart = true
            }
        }
        .spiceNavigationBar(title: "Your orders")
        .navigationDestination(isPresented: $showCart) {
            CartScreen()
        }
        .onAppear {
            viewModel.loadFirstPage()
        }
    }
    
    private func orderCard(_ order: OrderItem) -> some View {
        let statusColor = Color(hex: order.status.color)
        
        return NavigationLink {
            OrderDetailScreen(orderId: order.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Card Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.orderNo)
                            .font(.appFont(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(order.date)
                            .font(.appFont(size: 11))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    Text(order.status.label)
                        .font(.appFont(size: 11, weight: .bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Products list row
                HStack(alignment: .center, spacing: 12) {
                    // Images
                    HStack(spacing: -12) {
                        ForEach(Array(order.productImages.prefix(3).enumerated()), id: \.element) { index, url in
                            RemoteImage(url: url, contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.05), radius: 2)
                                .zIndex(Double(3 - index))
                        }
                        
                        if order.productImages.count > 3 {
                            Text("+\(order.productImages.count - 3)")
                                .font(.appFont(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: "E4E4E7"))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                }
                                .zIndex(0)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Prices
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(order.totalAmountLabel)
                            .font(.appFont(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("\(order.itemsCount) \(order.itemsCount == 1 ? "item" : "items") · \(order.paymentLabel)")
                            .font(.appFont(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                
                // Timeline View
                OrderTimelineView(timeline: order.timeline)
                
                // Expected Date Box
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text("\(order.expectedDate.label) \(order.expectedDate.date)")
                        .font(.appFont(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(statusColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Footer Link
                HStack {
                    Text("View details")
                        .font(.appFont(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                    Image(systemName: "chevron.right")
                        .font(.appFont(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.02), radius: 3, y: 1)
            .buttonStyle(.plain)
        }
    }
    
    struct OrderTimelineView: View {
        let timeline: [OrderTimelineStep]
        
        var body: some View {
            VStack(spacing: 6) {
                // Line with dots
                HStack(spacing: 0) {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, step in
                        let isActive = step.completed
                        
                        // Connecting Line
                        if index > 0 {
                            let prevActive = timeline[index - 1].completed
                            Rectangle()
                                .fill(prevActive && isActive ? AppTheme.brandGreen : Color(hex: "E4E4E7"))
                                .frame(height: 3)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Dot
                        ZStack {
                            Circle()
                                .fill(isActive ? AppTheme.brandGreen : Color.white)
                                .frame(width: 14, height: 14)
                                .overlay {
                                    Circle()
                                        .stroke(isActive ? AppTheme.brandGreen : Color(hex: "D4D4D8"), lineWidth: 2)
                                }
                            
                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.appFont(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                // Labels
                HStack(spacing: 0) {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, step in
                        Text(step.label)
                            .font(.appFont(size: 10, weight: step.completed ? .bold : .medium))
                            .foregroundStyle(step.completed ? AppTheme.textPrimary : AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : (index == timeline.count - 1 ? .trailing : .center))
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
