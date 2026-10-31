import Foundation

final class SettingsManager {
    static let shared = SettingsManager()
    private var cachedKeys: [String]?

    private var configDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeepSeekBalance", isDirectory: true)
    }

    private var configFile: URL { configDir.appendingPathComponent("config") }

    // MARK: - API Key
    func saveAPIKeys(_ keys: [String]) -> Bool {
        let normalized = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        cachedKeys = normalized

        guard !normalized.isEmpty else {
            deleteAPIKeys()
            return true
        }

        do {
            let encodedData = try JSONEncoder().encode(normalized)
            let encoded = encodedData.base64EncodedString().data(using: .utf8)
            guard let encoded else { return false }
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
            try encoded.write(to: configFile, options: .atomic)
            return true
        } catch {
            NSLog("[DeepSeekBalance] 保存 API Key 失败: \(error)")
            return false
        }
    }

    func loadAPIKeys() -> [String] {
        if let cached = cachedKeys { return cached }
        do {
            let data = try Data(contentsOf: configFile)
            guard let base64 = String(data: data, encoding: .utf8),
                  let decodedData = Data(base64Encoded: base64),
                  let decoded = String(data: decodedData, encoding: .utf8) else { return [] }

            let keys: [String]
            if let storedKeys = try? JSONDecoder().decode([String].self, from: decodedData) {
                keys = storedKeys
            } else {
                // 兼容旧版单 Key 配置（Base64 后直接保存 Key 字符串）。
                keys = decoded.isEmpty ? [] : [decoded]
            }

            let normalized = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            cachedKeys = normalized
            return normalized
        } catch {
            return []
        }
    }

    func deleteAPIKeys() {
        cachedKeys = []
        try? FileManager.default.removeItem(at: configFile)
    }

    var hasAPIKey: Bool { !loadAPIKeys().isEmpty }
    func clearCache() { cachedKeys = nil }

    // MARK: - UserDefaults
    static var refreshInterval: TimeInterval {
        get { let v = UserDefaults.standard.double(forKey: "refresh_interval"); return v > 0 ? v : 300 }
        set { UserDefaults.standard.set(newValue, forKey: "refresh_interval") }
    }
    static var apiBaseURL: String {
        get { UserDefaults.standard.string(forKey: "api_base_url") ?? "https://api.deepseek.com" }
        set { UserDefaults.standard.set(newValue, forKey: "api_base_url") }
    }
    static var accountNames: [String] {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: "account_names") ?? []
            return (0..<2).map { index in
                normalizedAccountName(stored.indices.contains(index) ? stored[index] : "", index: index)
            }
        }
        set {
            let normalized = (0..<2).map { index in
                normalizedAccountName(newValue.indices.contains(index) ? newValue[index] : "", index: index)
            }
            UserDefaults.standard.set(normalized, forKey: "account_names")
        }
    }
    static var accountNameColors: [AccountNameColor] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "account_name_colors"),
                  let colors = try? JSONDecoder().decode([AccountNameColor].self, from: data) else {
                return AccountNameColor.defaults
            }
            return (0..<2).map { index in
                normalizedAccountColor(colors.indices.contains(index) ? colors[index] : nil, index: index)
            }
        }
        set {
            let normalized = (0..<2).map { index in
                normalizedAccountColor(newValue.indices.contains(index) ? newValue[index] : nil, index: index)
            }
            if let data = try? JSONEncoder().encode(normalized) {
                UserDefaults.standard.set(data, forKey: "account_name_colors")
            }
        }
    }
    static var secondaryAccountFirst: Bool {
        get { UserDefaults.standard.bool(forKey: "secondary_account_first") }
        set { UserDefaults.standard.set(newValue, forKey: "secondary_account_first") }
    }
    static var totalBudget: Double {
        get { UserDefaults.standard.double(forKey: "total_budget") }
        set { UserDefaults.standard.set(newValue, forKey: "total_budget") }
    }
    static var floatTextSize: Double {
        get { let v = UserDefaults.standard.double(forKey: "float_text_size"); return v >= 14 ? v : 24 }
        set { UserDefaults.standard.set(newValue, forKey: "float_text_size") }
    }
    static var panelWidth: Double {
        get { let v = UserDefaults.standard.double(forKey: "panel_width"); return v >= 160 ? v : 200 }
        set { UserDefaults.standard.set(newValue, forKey: "panel_width") }
    }
    static var panelHeight: Double {
        get { let v = UserDefaults.standard.double(forKey: "panel_height"); return v >= 100 ? v : 130 }
        set { UserDefaults.standard.set(newValue, forKey: "panel_height") }
    }

    // MARK: - 悬浮窗状态
    static var panelVisible: Bool {
        get { UserDefaults.standard.bool(forKey: "float_panel_visible") }
        set { UserDefaults.standard.set(newValue, forKey: "float_panel_visible") }
    }
    static var panelX: Double {
        get { UserDefaults.standard.double(forKey: "float_panel_x") }
        set { UserDefaults.standard.set(newValue, forKey: "float_panel_x") }
    }
    static var panelY: Double {
        get { UserDefaults.standard.double(forKey: "float_panel_y") }
        set { UserDefaults.standard.set(newValue, forKey: "float_panel_y") }
    }

    private static func normalizedAccountName(_ name: String, index: Int) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "账号 \(index + 1)" }
        return String(trimmed.prefix(12))
    }

    private static func normalizedAccountColor(_ color: AccountNameColor?, index: Int) -> AccountNameColor {
        guard let color else { return AccountNameColor.defaults[index] }
        return AccountNameColor(
            red: min(max(color.red, 0), 1),
            green: min(max(color.green, 0), 1),
            blue: min(max(color.blue, 0), 1),
            alpha: min(max(color.alpha, 0), 1)
        )
    }
}
