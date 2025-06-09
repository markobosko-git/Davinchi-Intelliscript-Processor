//
//  ConnectivityManager.swift
//  DaVinci Resolve Transcript Processor
//
//  Created for markobosko-git on 2025-06-09
//  Current UTC: 2025-06-09 22:48:36
//

import Foundation
import Network

class ConnectivityManager: ObservableObject {
    @Published var isConnected = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let dnsServers = ["8.8.8.8", "1.1.1.1", "8.8.4.4"] // Google, Cloudflare, Google Alt
    
    init() {
        startMonitoring()
        pingDNSServers()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    func pingDNSServers() {
        // Schedule periodic ping checks
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.performPingCheck()
        }
        
        // Do an initial check
        performPingCheck()
    }
    
    private func performPingCheck() {
        Task {
            var reachable = false
            
            for server in dnsServers {
                do {
                    let reachabilityURL = URL(string: "https://\(server)")!
                    let request = URLRequest(url: reachabilityURL, timeoutInterval: 5)
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        reachable = (200...299).contains(httpResponse.statusCode)
                        if reachable {
                            break // Exit loop if we found a responding server
                        }
                    }
                } catch {
                    // Try the next server
                    continue
                }
            }
            
            await MainActor.run {
                self.isConnected = reachable
            }
        }
    }
}