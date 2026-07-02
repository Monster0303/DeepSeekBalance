import Foundation

final class SettingsManager {
    static let shared = SettingsManager()
    private var cachedKey: String?

    private var configDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeepSeekBalance", isDirectory: true)
    }

    private var configFile: URL { configDir.appendingPathComponent("config") }

    // MARK: - API Key
    func saveAPIKey(_ key: String) -> Bool {
        cachedKey = key
        guard let encoded = key.data(using: .utf8)?.base64EncodedString().data(using: .utf8) else { return false }
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
            try encoded.write(to: configFile, options: .atomic)
            return true
        } catch {
            NSLog("[DeepSeekBalance] 保存 API Key 失败: \(error)")
            return false
        }
    }

    func loadAPIKey() -> String? {
        if let cached = cachedKey { return cached }
        do {
            let data = try Data(contentsOf: configFile)
            guard let base64 = String(data: data, encoding: .utf8),
                  let decodedData = Data(base64Encoded: base64),
                  let key = String(data: decodedData, encoding: .utf8) else { return nil }
            cachedKey = key; return key
        } catch { return nil }
    }

    func deleteAPIKey() { cachedKey = nil; try? FileManager.default.removeItem(at: configFile) }
    var hasAPIKey: Bool { cachedKey != nil || loadAPIKey() != nil }
    func clearCache() { cachedKey = nil }

    // MARK: - UserDefaults
    static var refreshInterval: TimeInterval {
        get { let v = UserDefaults.standard.double(forKey: "refresh_interval"); return v > 0 ? v : 300 }
        set { UserDefaults.standard.set(newValue, forKey: "refresh_interval") }
    }
    static var apiBaseURL: String {
        get { UserDefaults.standard.string(forKey: "api_base_url") ?? "https://api.deepseek.com" }
        set { UserDefaults.standard.set(newValue, forKey: "api_base_url") }
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
}
