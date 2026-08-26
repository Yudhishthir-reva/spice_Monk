//
//  AddressFormScreen.swift
//  SpiceMonk
//

import SwiftUI

/// New delivery address. City and state are not typed — the PIN code resolves them, since the API
/// wants ids the customer has no way of knowing.
struct AddressFormScreen: View {

    @StateObject private var viewModel = AddressFormViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showMapPicker: Bool = false

    let onSaved: (Address?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    mapPickerButton

                    field("Full name", text: $viewModel.fullName, placeholder: "John Doe")

                    field(
                        "Mobile number",
                        text: $viewModel.mobile,
                        placeholder: "98765 43210",
                        keyboard: .numberPad
                    )
                    .onChange(of: viewModel.mobile) { _, newValue in
                        viewModel.mobile = String(newValue.filter(\.isNumber).prefix(10))
                    }

                    field(
                        "Alternate mobile (optional)",
                        text: $viewModel.alternateMobile,
                        placeholder: "Optional",
                        keyboard: .numberPad
                    )
                    .onChange(of: viewModel.alternateMobile) { _, newValue in
                        viewModel.alternateMobile = String(newValue.filter(\.isNumber).prefix(10))
                    }

                    pinCodeField

                    field("City / district", text: $viewModel.district, placeholder: "Mumbai")
                    field("State", text: $viewModel.state, placeholder: "Maharashtra")

                    field("House / flat no.", text: $viewModel.houseFlatNo, placeholder: "Flat 101, Sunrise Apts")
                    field("Area", text: $viewModel.area, placeholder: "Fort")
                    field("Landmark (optional)", text: $viewModel.landmark, placeholder: "Near Metro Station")

                    defaultToggle

                    PrimaryActionButton(
                        title: "Save address",
                        icon: "checkmark",
                        isLoading: viewModel.isSaving
                    ) {
                        viewModel.save { address in
                            onSaved(address)
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(AppTheme.brandBackgroundMid)
            .navigationTitle("Add address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                LocationPickerScreen { location in
                    viewModel.applyPickedLocation(location)
                }
            }
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 2, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }

    // MARK: - Map Picker Button

    private var mapPickerButton: some View {
        Button {
            showMapPicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSoft)
                        .frame(width: 40, height: 40)

                    Image(systemName: "map.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.brandGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Select location on Google Map")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Auto-fills area, district, state & PIN code")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(12)
            .background(AppTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fields

    private func field(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(AppTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                }
        }
    }

    private var pinCodeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("PIN code")

            HStack(spacing: 10) {
                TextField("400001", text: $viewModel.pinCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textPrimary)
                    .onChange(of: viewModel.pinCode) { _, _ in
                        viewModel.pinCodeChanged()
                    }

                if viewModel.isLookingUpPincode {
                    ProgressView()
                } else if viewModel.didResolvePincode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.badgeSuccess)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(AppTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        viewModel.pincodeError == nil ? AppTheme.fieldBorder : AppTheme.brandRed,
                        lineWidth: 1
                    )
            }

            if viewModel.didResolvePincode {
                Label("\(viewModel.district), \(viewModel.state)", systemImage: "mappin.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.badgeSuccess)
            } else if let error = viewModel.pincodeError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.brandRed)
            } else {
                Text("We'll fill in your city and state from the PIN code.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private var defaultToggle: some View {
        Toggle(isOn: $viewModel.isDefault) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Make this my default address")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Orders will be delivered here unless you change it.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .tint(AppTheme.brandRed)
        .padding(14)
        .background(AppTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.fieldBorder, lineWidth: 1)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(AppTheme.brandRed)
                .frame(width: 3, height: 12)
            Text(text.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(0.6)
        }
    }
}
