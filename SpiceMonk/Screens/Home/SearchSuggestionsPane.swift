//
//  SearchSuggestionsPane.swift
//  SpiceMonk
//

import SwiftUI

/// Body of home search mode: type-ahead rows, plus the hint / loading / empty states.
struct SearchSuggestionsPane: View {

    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        Group {
            if viewModel.trimmedQuery.count < SearchViewModel.minQueryLength {
                hint("Type at least 3 letters to search")
            } else if viewModel.isSuggesting && viewModel.suggestions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if let error = viewModel.suggestionError, viewModel.suggestions.isEmpty {
                hint(error)
            } else if viewModel.suggestions.isEmpty {
                emptyState
            } else {
                suggestionList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.homeCanvas)
        .scrollDismissesKeyboard(.immediately)
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(viewModel.suggestions) { suggestion in
                    suggestionLink(suggestion)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func suggestionLink(_ suggestion: SearchSuggestion) -> some View {
        switch suggestion.kind {
        case .category:
            NavigationLink {
                WidgetProductsScreen(
                    searchQuery: "",
                    title: suggestion.name,
                    categoryId: suggestion.entityId
                )
            } label: {
                SuggestionRow(suggestion: suggestion)
            }
            .buttonStyle(.plain)
        case .brand:
            NavigationLink {
                WidgetProductsScreen(
                    searchQuery: "",
                    title: suggestion.name,
                    brandId: suggestion.entityId
                )
            } label: {
                SuggestionRow(suggestion: suggestion)
            }
            .buttonStyle(.plain)
        case .product, .variant:
            NavigationLink {
                WidgetProductsScreen(
                    searchQuery: "",
                    title: suggestion.name,
                    productId: suggestion.entityId
                )
            } label: {
                SuggestionRow(suggestion: suggestion)
            }
            .buttonStyle(.plain)
        case .unknown:
            Button {
                viewModel.openResults(query: suggestion.name)
            } label: {
                SuggestionRow(suggestion: suggestion)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        Button {
            viewModel.submit()
        } label: {
            VStack(spacing: 8) {
                Text("No matches")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Press search to look up “\(viewModel.trimmedQuery)” anyway.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
    }
}

private struct SuggestionRow: View {

    let suggestion: SearchSuggestion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.kindIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accentRed)
                .frame(width: 36, height: 36)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(suggestion.kindTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
