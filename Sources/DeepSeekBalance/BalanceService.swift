import Foundation
import Combine

@MainActor
final class BalanceService: ObservableObject {
    static let shared = BalanceService()

    @Published private(set) var accountBalances: [AccountBalanceState] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var refreshSuccessMessage: String?  // 刷新成功提示

    var orderedAccountBalances: [AccountBalanceState] {
        guard SettingsManager.secondaryAccountFirst, accountBalances.count == 2 else {
            return accountBalances
        }
        return [accountBalances[1], accountBalances[0]]
    }

    private var timer: Timer?
    private var isFetching = false
    private var pendingRefresh = false
    private var refreshInterval: TimeInterval {
        let saved = SettingsManager.refreshInterval
        return saved > 0 ? saved : 300
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshNow()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.fetchBalances() }
        }
    }

    func stopAutoRefresh() { timer?.invalidate(); timer = nil }
    func refreshNow() {
        guard !isFetching else {
            pendingRefresh = true
            return
        }
        Task { await fetchBalances() }
    }
    func restartAutoRefresh() {
        applyAccountPreferences()
        stopAutoRefresh()
        startAutoRefresh()
    }

    private func applyAccountPreferences() {
        guard !accountBalances.isEmpty else { return }
        let names = SettingsManager.accountNames
        let colors = SettingsManager.accountNameColors
        accountBalances = accountBalances.map { account in
            AccountBalanceState(
                id: account.id,
                name: names.indices.contains(account.id) ? names[account.id] : account.label,
                nameColor: colors.indices.contains(account.id) ? colors[account.id] : AccountNameColor.defaults[account.id % 2],
                model: account.model,
                errorMessage: account.errorMessage,
                isLoading: account.isLoading,
                lastUpdated: account.lastUpdated
            )
        }
    }

    private func fetchBalances() async {
        guard !isFetching else { return }

        let apiKeys = SettingsManager.shared.loadAPIKeys()
        guard !apiKeys.isEmpty else {
            accountBalances = []
            isLoading = false
            lastUpdated = nil
            return
        }

        isFetching = true
        isLoading = true
        refreshSuccessMessage = nil

        let baseURL = SettingsManager.apiBaseURL
        let initialAccountNames = SettingsManager.accountNames
        let initialAccountColors = SettingsManager.accountNameColors
        let previousBalances = Dictionary(uniqueKeysWithValues: accountBalances.map { ($0.id, $0) })

        accountBalances = apiKeys.enumerated().map { index, _ in
            let previous = previousBalances[index]
            return AccountBalanceState(
                id: index,
                name: initialAccountNames.indices.contains(index) ? initialAccountNames[index] : "账号 \(index + 1)",
                nameColor: initialAccountColors.indices.contains(index) ? initialAccountColors[index] : AccountNameColor.defaults[index % 2],
                model: previous?.model,
                errorMessage: nil,
                isLoading: true,
                lastUpdated: previous?.lastUpdated
            )
        }

        let results = await withTaskGroup(of: (Int, BalanceDisplayModel?, String?).self) { group in
            for (index, apiKey) in apiKeys.enumerated() {
                group.addTask {
                    let result = await Self.fetchBalance(apiKey: apiKey, baseURL: baseURL)
                    return (index, result.model, result.errorMessage)
                }
            }

            var collected: [(Int, BalanceDisplayModel?, String?)] = []
            for await result in group {
                collected.append(result)
            }
            return collected.sorted { $0.0 < $1.0 }
        }

        let now = Date()
        let currentAccountNames = SettingsManager.accountNames
        let currentAccountColors = SettingsManager.accountNameColors
        var anySuccess = false
        accountBalances = results.map { index, model, error in
            let previous = previousBalances[index]
            let currentModel = model ?? previous?.model
            if model != nil { anySuccess = true }
            return AccountBalanceState(
                id: index,
                name: currentAccountNames.indices.contains(index) ? currentAccountNames[index] : "账号 \(index + 1)",
                nameColor: currentAccountColors.indices.contains(index) ? currentAccountColors[index] : AccountNameColor.defaults[index % 2],
                model: currentModel,
                errorMessage: model == nil ? (error ?? "获取余额失败") : nil,
                isLoading: false,
                lastUpdated: model == nil ? previous?.lastUpdated : now
            )
        }

        isLoading = false
        isFetching = false
        lastUpdated = accountBalances.compactMap(\.lastUpdated).max()

        if anySuccess {
            refreshSuccessMessage = "✓ 已刷新"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.refreshSuccessMessage = nil
            }
        }

        if pendingRefresh {
            pendingRefresh = false
            refreshNow()
        }
    }

    private nonisolated static func fetchBalance(
        apiKey: String,
        baseURL: String
    ) async -> (model: BalanceDisplayModel?, errorMessage: String?) {
        let endpoints = ["/user/balance", "/v1/dashboard/billing/available", "/v1/user/balance"]

        for endpoint in endpoints {
            if let model = try? await requestBalance(baseURL: baseURL, endpoint: endpoint, apiKey: apiKey) {
                let granted = model.totalGranted ?? (SettingsManager.totalBudget > 0 ? SettingsManager.totalBudget : nil)
                return (
                    BalanceDisplayModel(
                        balance: model.balance,
                        totalUsed: model.totalUsed,
                        totalGranted: granted
                    ),
                    nil
                )
            }
        }
        return (nil, "获取余额失败")
    }

    private nonisolated static func requestBalance(
        baseURL: String,
        endpoint: String,
        apiKey: String
    ) async throws -> BalanceDisplayModel? {
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
