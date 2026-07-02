import Foundation
import Combine

@MainActor
final class BalanceService: ObservableObject {
    static let shared = BalanceService()

    @Published var balanceModel: BalanceDisplayModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var refreshSuccessMessage: String?  // 刷新成功提示

    private var timer: Timer?
    private var refreshInterval: TimeInterval {
        let saved = SettingsManager.refreshInterval
        return saved > 0 ? saved : 300
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshNow()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.fetchBalance() }
        }
    }

    func stopAutoRefresh() { timer?.invalidate(); timer = nil }
    func refreshNow() { Task { await fetchBalance() } }
    func restartAutoRefresh() { stopAutoRefresh(); startAutoRefresh() }

    private func fetchBalance() async {
        guard let apiKey = SettingsManager.shared.loadAPIKey() else {
            errorMessage = "请先设置 API Key"
            return
        }

        isLoading = true
        errorMessage = nil

        let baseURL = SettingsManager.apiBaseURL
        let endpoints = ["/user/balance", "/v1/dashboard/billing/available", "/v1/user/balance"]
        var lastError: String?

        for endpoint in endpoints {
            if let result = try? await requestBalance(baseURL: baseURL, endpoint: endpoint, apiKey: apiKey) {
                let granted = result.totalGranted ?? (SettingsManager.totalBudget > 0 ? SettingsManager.totalBudget : nil)
                balanceModel = BalanceDisplayModel(
                    balance: result.balance,
                    totalUsed: result.totalUsed,
                    totalGranted: granted
                )
                isLoading = false
                lastUpdated = Date()
                errorMessage = nil
                // 刷新成功提示
                refreshSuccessMessage = "✓ 刷新成功"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.refreshSuccessMessage = nil
                }
                return
            } else {
                lastError = "获取余额失败"
            }
        }

        isLoading = false
        errorMessage = lastError
    }

    private func requestBalance(baseURL: String, endpoint: String, apiKey: String) async throws -> BalanceDisplayModel? {
        guard let url = URL(string: baseURL + endpoint) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

        if let r = try? JSONDecoder().decode(BalanceResponse.self, from: data) {
            return BalanceDisplayModel(balance: r.effectiveBalance ?? 0,
                                      totalUsed: r.effectiveTotalUsed,
                                      totalGranted: r.effectiveTotalGranted)
        }
        if let w = try? JSONDecoder().decode(BalancesWrapper.self, from: data),
           let f = w.balances?.first, let b = f.totalBalance.flatMap(Double.init) {
            return BalanceDisplayModel(balance: b, totalUsed: nil,
                                      totalGranted: f.grantedBalance.flatMap(Double.init))
        }
        if let s = try? JSONDecoder().decode([String: Double].self, from: data), let b = s["balance"] {
            return BalanceDisplayModel(balance: b, totalUsed: nil, totalGranted: nil)
        }
        return nil
    }
}
