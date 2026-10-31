import Foundation

struct BalanceResponse: Codable {
    let isAvailable: Bool?
    let balanceInfos: [BalanceInfo]?
    let balance: String?
    let totalUsed: String?
    let totalGranted: String?

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
        case balance
        case totalUsed = "total_used"
        case totalGranted = "total_granted"
    }

    var effectiveBalance: Double? {
        if let b = balance { return Double(b) }
        if let infos = balanceInfos, let first = infos.first,
           let val = first.totalBalance { return Double(val) }
        return nil
    }

    var effectiveTotalGranted: Double? {
        if let g = totalGranted { return Double(g) }
        if let infos = balanceInfos, let first = infos.first,
           let val = first.grantedBalance { return Double(val) }
        return nil
    }

    var effectiveTotalUsed: Double? {
        if let u = totalUsed { return Double(u) }
        return nil
    }
}

struct BalanceInfo: Codable {
    let currency: String?
    let totalBalance: String?
    let grantedBalance: String?
    let toppedUpBalance: String?
    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

struct BalancesWrapper: Codable {
    let balances: [BalanceInfo]?
}

/// UI 展示模型
struct BalanceDisplayModel {
    let balance: Double
    let totalUsed: Double?
    let totalGranted: Double?

    var usagePercent: Double {
        guard let granted = totalGranted, granted > 0 else { return 0 }
        return min((granted - balance) / granted, 1.0)
    }

    var balanceText: String {
        String(format: "¥%.2f", balance)
    }
}

struct AccountNameColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    static let defaults = [
        AccountNameColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.00),
        AccountNameColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.00)
    ]
}

struct AccountBalanceState: Identifiable {
    let id: Int
    let name: String
    let nameColor: AccountNameColor
    var model: BalanceDisplayModel?
    var errorMessage: String?
    var isLoading: Bool
    var lastUpdated: Date?

    var label: String {
        name.isEmpty ? "账号 \(id + 1)" : name
    }
}
