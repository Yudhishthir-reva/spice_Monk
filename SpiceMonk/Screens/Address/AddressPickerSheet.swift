//
//  AddressPickerSheet.swift
//  SpiceMonk
//

import SwiftUI

/// Lets the customer switch which saved address orders go to. Picking one writes through to
/// `POST customer/address/{id}/default`, so the choice survives a relaunch rather than living
/// only in this sheet.
struct AddressPickerSheet: View {

    @ObservedObject var viewModel: AddressViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingAddress = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasAddresses {
                    list
                } else {
                    emptyState
                }
            }
            .background(AppTheme.brandBackgroundMid)
            .navigationTitle("Delivery address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.brandRed)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $isAddingAddress) {
            AddressFormScreen { _ in
                // Refetch rather than trusting the local copy: saving with "default" ticked also
                // clears the flag on whichever address held it before.
                viewModel.load()
            }
        }
    }

    private var addButton: some View {
        Button {
            isAddingAddress = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add new address")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppTheme.brandRed)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.addresses) { address in
                    Button {
                        viewModel.makeDefault(address)
                        dismiss()
                    } label: {
                        row(for: address)
                    }
                    .buttonStyle(.plain)
                }

                addButton
                    .padding(.top, 4)
            }
            .padding(16)
        }
    }

    private func row(for address: Address) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: address.isDefault ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 19))
                .foregroundStyle(address.isDefault ? AppTheme.brandRed : AppTheme.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(address.fullName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if address.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(AppTheme.brandRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentSoft)
                            .clipShape(Capsule())
                    }
                }

                Text(address.fullLine)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(address.mobile)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(address.isDefault ? AppTheme.brandRed : AppTheme.fieldBorder, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.brandRed)
                .frame(width: 68, height: 68)
                .background(AppTheme.accentSoft)
                .clipShape(Circle())

            Text("No saved addresses")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Add a delivery address to see it here.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            addButton
                .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
