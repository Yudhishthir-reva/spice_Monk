//
//  HomeScreen.swift
//  SpiceMonk
//

import SwiftUI

struct HomeScreen: View {

    @StateObject var viewModel = HomeViewModel()
    @StateObject private var addressViewModel = AddressViewModel()
    @State private var selectedTab: HomeTab = .home
    @State private var scrollOffset: CGFloat = 0
    @State private var isConfirmingLogout = false
    @State private var isPickingAddress = false

    /// How far the feed travels before the header is fully collapsed.
    private let collapseDistance: CGFloat = 96

    private var collapseProgress: Double {
        min(max(scrollOffset / collapseDistance, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HomeTopBar(
                collapseProgress: collapseProgress,
                address: addressViewModel.defaultAddress,
                onAddressTap: { isPickingAddress = true },
                onProfileTap: { isConfirmingLogout = true }
            )

            Group {
                if viewModel.isLoading && !viewModel.hasContent {
                    ScrollView { HomeSkeleton() }
                } else if let error = viewModel.loadError, !viewModel.hasContent {
                    ScrollView {
                        HomeErrorState(message: error) {
                            viewModel.loadHome()
                        }
                        .padding(.top, 60)
                    }
                    .refreshable { await refreshFeed() }
                } else {
                    feed
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HomeBottomBar(selection: $selectedTab)
        }
        .background(AppTheme.homeCanvas)
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(.easeOut(duration: 0.2), value: collapseProgress == 1)
        .onAppear {
            if !viewModel.hasContent {
                viewModel.loadHome()
            }
            addressViewModel.load()
        }
        .sheet(isPresented: $isPickingAddress) {
            AddressPickerSheet(viewModel: addressViewModel)
        }
        .confirmationDialog("Log out of SpiceMonk?", isPresented: $isConfirmingLogout) {
            Button("Log out", role: .destructive) {
                viewModel.logout()
            }
            Button("Cancel", role: .cancel) {}
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
        .toast(isPresenting: $addressViewModel.isShowToastView, duration: 1.8, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: addressViewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    private var feed: some View {
        ScrollView {
            VStack(spacing: 22) {
                ForEach(viewModel.widgets) { widget in
                    HomeWidgetBlock(widget: widget)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: -proxy.frame(in: .named("feed")).minY
                    )
                }
            }
        }
        .coordinateSpace(name: "feed")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            scrollOffset = offset
        }
        .refreshable { await refreshFeed() }
    }

    /// `refreshable` keeps its spinner up until this returns, so the wait is tied to the request
    /// finishing rather than a fixed delay.
    private func refreshFeed() async {
        viewModel.refresh()
        while viewModel.isRefreshing {
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeScreen()
}
