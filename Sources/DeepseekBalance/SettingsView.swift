import SwiftUI

// MARK: - 卡片分组容器

struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))

                // 左侧色条
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.08))
                        .frame(width: 3)
                    Spacer()
                }

                // 顶部光泽
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    .blendMode(.overlay)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        .shadow(color: .black.opacity(0.02), radius: 6, x: 0, y: 2)
    }
}

// MARK: - 设置视图

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var refreshInterval: Double = 300
    @State private var apiBaseURL: String = "https://api.deepseek.com"
    @State private var totalBudget: String = ""
    @State private var floatTextSize: Double = 24
    @State private var panelWidth: Double = 200
    @State private var panelHeight: Double = 130
    @State private var saveSuccess = false
    @State private var copiedAlert = false
    @State private var pastedAlert = false

    private let intervalOptions: [(label: String, value: Double)] = [
        ("30秒", 30), ("1分", 60), ("2分", 120),
        ("5分", 300), ("10分", 600), ("30分", 1800)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // ═══ 标题区 ═══
                titleSection

                // ═══ 各设置卡片 ═══
                SettingsCard(title: "API Key", systemImage: "key.fill", color: .orange) {
                    apiKeySection
                }

                SettingsCard(title: "API 地址", systemImage: "link", color: .blue) {
                    apiBaseSection
                }

                SettingsCard(title: "刷新频率", systemImage: "timer", color: .green) {
                    intervalSection
                }

                SettingsCard(title: "总额度", systemImage: "chart.pie", color: .purple) {
                    budgetSection
                }

                SettingsCard(title: "悬浮窗样式", systemImage: "rectangle.expand.vertical", color: .cyan) {
                    floatingStyleSection
                }

                // ═══ 底部操作栏 ═══
                bottomBarSection
            }
            .padding(20)
        }
        .frame(width: 440).frame(minHeight: 560)
        .background(Color(.windowBackgroundColor))
        .onAppear(perform: loadSettings)
    }

    // MARK: - 标题区

    private var titleSection: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("DeepSeek 余额监控")
                    .font(.system(size: 17, weight: .semibold))
                Text("菜单栏余额小工具 · 配置你的 API")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                TextField("sk-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(10)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12), lineWidth: 0.5))

                HStack(spacing: 2) {
                    Button(action: pasteFromClipboard) {
                        Image(systemName: "clipboard")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .background(pastedAlert ? Color.green.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(pastedAlert ? .green : .secondary)

                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .background(copiedAlert ? Color.green.opacity(0.1) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(copiedAlert ? .green : .secondary)
                }
            }

            if copiedAlert {
                Label("已复制到剪贴板!", systemImage: "checkmark")
                    .font(.system(size: 9)).foregroundColor(.green)
            } else if pastedAlert {
                Label("已粘贴!", systemImage: "checkmark")
                    .font(.system(size: 9)).foregroundColor(.green)
            } else {
                Text("支持 Cmd+C/V · 亦可用粘贴/复制按钮")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - API 地址

    private var apiBaseSection: some View {
        TextField("https://api.deepseek.com", text: $apiBaseURL)
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .padding(10)
            .background(Color.gray.opacity(0.06))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12), lineWidth: 0.5))
    }

    // MARK: - 刷新频率

    private var intervalSection: some View {
        Picker("", selection: $refreshInterval) {
            ForEach(intervalOptions, id: \.value) { t in Text(t.label).tag(t.value) }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    // MARK: - 总额度

    private var budgetSection: some View {
        HStack {
            TextField("例如: 300", text: $totalBudget)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(10)
                .background(Color.gray.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12), lineWidth: 0.5))
                .frame(width: 120)

            Text("CNY")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Text("可选，用于进度条比例计算")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 悬浮窗样式

    private var floatingStyleSection: some View {
        VStack(spacing: 10) {
            sliderRow(label: "字体大小", value: $floatTextSize, range: 14...48, step: 1, postAction: {
                SettingsManager.floatTextSize = floatTextSize
                NotificationCenter.default.post(name: .fontSizeChanged, object: nil)
            })

            sliderRow(label: "宽度", value: $panelWidth, range: 160...400, step: 10, postAction: {
                SettingsManager.panelWidth = panelWidth
                NotificationCenter.default.post(name: .fontSizeChanged, object: nil)
            })

            sliderRow(label: "高度", value: $panelHeight, range: 100...400, step: 10, postAction: {
                SettingsManager.panelHeight = panelHeight
                NotificationCenter.default.post(name: .fontSizeChanged, object: nil)
            })
        }
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, postAction: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Slider(value: value, in: range, step: step, onEditingChanged: { editing in
                if !editing { postAction() }
            })
            .frame(maxWidth: .infinity)

            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - 底部操作栏

    private var bottomBarSection: some View {
        HStack {
            if saveSuccess {
                Label("已保存 ✓ 自动刷新", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(Color.green.opacity(0.06))
                    .cornerRadius(6)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer()

            Button("保存并应用") { Task { await saveSettings() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.return)
        }
        .padding(.top, 4)
    }

    // MARK: - 功能方法

    private func copyToClipboard() {
        guard !apiKey.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(apiKey, forType: .string)
        withAnimation { copiedAlert = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copiedAlert = false } }
    }

    private func pasteFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else { return }
        apiKey = str
        withAnimation { pastedAlert = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { pastedAlert = false } }
    }

    private func loadSettings() {
        if let saved = SettingsManager.shared.loadAPIKey() { apiKey = saved }
        refreshInterval = SettingsManager.refreshInterval
        if refreshInterval <= 0 { refreshInterval = 300 }
        apiBaseURL = SettingsManager.apiBaseURL
        let budget = SettingsManager.totalBudget
        totalBudget = budget > 0 ? "\(Int(budget))" : ""
        floatTextSize = SettingsManager.floatTextSize
        panelWidth = SettingsManager.panelWidth
        panelHeight = SettingsManager.panelHeight
    }

    @MainActor private func saveSettings() {
        if !apiKey.isEmpty { _ = SettingsManager.shared.saveAPIKey(apiKey) }
        SettingsManager.refreshInterval = refreshInterval
        SettingsManager.apiBaseURL = apiBaseURL
        if let budget = Double(totalBudget), budget > 0 { SettingsManager.totalBudget = budget }
        else { SettingsManager.totalBudget = 0 }
        BalanceService.shared.restartAutoRefresh()
        withAnimation { saveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { saveSuccess = false } }
    }
}