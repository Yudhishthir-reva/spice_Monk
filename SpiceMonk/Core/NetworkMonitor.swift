//
//  NetworkMonitor.swift
//  SpiceMonk
//

import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.SpiceMonk.NetworkMonitor")
    private var hasStarted = false

    @Published private(set) var isConnected: Bool = true

    private init() {
        start()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        isConnected = monitor.currentPath.status == .satisfied

        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
