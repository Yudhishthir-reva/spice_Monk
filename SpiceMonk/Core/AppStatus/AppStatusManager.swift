//
//  AppStatusManager.swift
//  SpiceMonk
//
//

import Foundation
import Combine
import SwiftUI

struct AppStatusResponse: Decodable {
    let status: Bool?
    let code: String?
    let message: String?
    let data: AppStatusData?
}

struct AppStatusData: Decodable {
    let isMaintenance: Bool?
    let needsUpdate: Bool?
    let forceUpdate: Bool?
    let hasNewVersion: Bool?
    let currentVersion: String?
    let minVersion: String?
    let updateUrl: String?
    let updateMessage: String?
    let googleMapKey: String?
    let whatsappNumber: String?
    let codEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case isMaintenance = "is_maintenance"
        case needsUpdate = "needs_update"
        case forceUpdate = "force_update"
        case hasNewVersion = "has_new_version"
        case currentVersion = "current_version"
        case minVersion = "min_version"
        case updateUrl = "update_url"
        case updateMessage = "update_message"
        case googleMapKey = "google_map_key"
        case whatsappNumber = "whatsapp_number"
        case codEnabled = "cod_enabled"
    }
}

@MainActor
final class AppStatusManager: ObservableObject {

    static let shared = AppStatusManager()

    @Published private(set) var appStatus: AppStatusData?
    @Published var isCheckingStatus = false
    @Published var isMaintenance = false
    @Published var isForceUpdate = false
    @Published var isSoftUpdate = false
    @Published var updateUrl = ""
    @Published var updateMessage = ""

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let storedMapKey = UserDefaultManager.shared.googleMapKey
        if !storedMapKey.isEmptyString {
            GoogleMapsConfig.provideAPIKey(storedMapKey)
        }
    }

    var whatsappNumber: String {
        let live = appStatus?.whatsappNumber ?? UserDefaultManager.shared.whatsappNumber
        return live.isEmptyString ? "919999999999" : live
    }

    var whatsappURL: URL? {
        let cleaned = whatsappNumber
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return URL(string: "https://wa.me/\(cleaned)")
        }
        return URL(string: "https://wa.me/")
    }

    var isCodEnabled: Bool {
        appStatus?.codEnabled ?? UserDefaultManager.shared.isCodEnabled
    }

    var resolvedUpdateURL: URL? {
        if !updateUrl.isEmptyString, let url = URL(string: updateUrl.trim) {
            return url
        }
        return URL(string: "https://spicemonk.revateam.com")
    }

    func dismissSoftUpdate() {
        self.isSoftUpdate = false
    }

    func checkStatus() {
        guard !isCheckingStatus else { return }
        isCheckingStatus = true

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let params: RequestConstants.Param = [
            "app_version": appVersion,
            "device_type": "ios"
        ]

        let headers = UserDefaultManager.shared.authHeader

        NetworkServiceManager.shared.request(
            APIRouter.checkStatus,
            params: params,
            headers: headers
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            self?.isCheckingStatus = false
            if case .failure(let error) = completion {
                print("❌ [AppStatusManager] check-status error: \(error)")
            }
        }, receiveValue: { [weak self] (response: AppStatusResponse) in
            guard let self = self, let data = response.data else { return }
            self.handleStatusResponse(data)
        })
        .store(in: &cancellables)
    }

    private func handleStatusResponse(_ data: AppStatusData) {
        self.appStatus = data

        // 1. Dynamic Google Maps Key
        if let mapKey = data.googleMapKey, !mapKey.isEmptyString {
            UserDefaultManager.shared.setUserDefaultsString(value: mapKey, key: .googleMapKey)
            GoogleMapsConfig.provideAPIKey(mapKey)
        }

        // 2. Dynamic WhatsApp Number
        if let whatsapp = data.whatsappNumber, !whatsapp.isEmptyString {
            UserDefaultManager.shared.setUserDefaultsString(value: whatsapp, key: .whatsappNumber)
        }

        // 3. COD Enabled
        if let cod = data.codEnabled {
            UserDefaultManager.shared.setUserDefaultsBool(value: cod, key: .codEnabled)
        }

        // 4. Maintenance Mode
        self.isMaintenance = data.isMaintenance == true

        // 5. Force / Soft Update
        self.isForceUpdate = data.forceUpdate == true
        self.isSoftUpdate = (data.needsUpdate == true || data.hasNewVersion == true) && !self.isForceUpdate
        self.updateUrl = data.updateUrl ?? ""
        self.updateMessage = data.updateMessage ?? "A new version of the app is available."

        print("✅ [AppStatusManager] App Status Check Complete: Maintenance=\(isMaintenance), ForceUpdate=\(isForceUpdate), WhatsApp=\(whatsappNumber), COD=\(isCodEnabled)")
    }
}
