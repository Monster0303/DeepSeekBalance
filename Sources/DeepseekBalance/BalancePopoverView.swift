import SwiftUI

struct BalancePopoverView: View {
    @StateObject private var balanceService = BalanceService.shared
    @State private var floatPanelOn = false

    private var intervalLabel: String {
        let sec = SettingsManager.refreshInterval
        if sec < 60 { return "每\(Int(sec))秒" }
        return "每\(Int(sec / 60))分钟"
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 底层背景材质
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            // 顶部渐变装饰条
            LinearGradient(colors: [.blue.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 60)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ═══ 层 1: 标题栏 ═══
                headerSection

                // ═══ 层 2: 余额卡片 ═══
                contentSection
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                // ═══ 层 3: 工具栏 ═══
                toolbarSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)

                // ═══ 层 4: 退出按钮 ═══
                exitSection
            }
        }
        .frame(width: 250)
        .onAppear { floatPanelOn = UserDefaults.standard.bool(forKey: "float_panel_visible") }
        .onChange(of: floatPanelOn) { UserDefaults.standard.set($0, forKey: "float_panel_visible") }
    }

    // MARK: - 标题栏

    private var headerSection: some View {
        HStack(spacing: 8) {
            // 图标 + 波形装饰
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("DeepSeek 余额")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if let msg = balanceService.refreshSuccessMessage {
                Text(msg)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(4)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Button(action: { NotificationCenter.default.post(name: .openSettings, object: nil) }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - 内容卡片容器

    private var contentSection: some View {
        VStack(spacing: 6) {
            if !SettingsManager.shared.hasAPIKey {
                noKeyView
            } else if balanceService.isLoading && balanceService.balanceModel == nil {
                loadingView
            } else if let err = balanceService.errorMessage, balanceService.balanceModel == nil {
                errorView(err)
            } else if let model = balanceService.balanceModel {
                balanceCardView(model)
            } else {
                waitingView
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.controlBackgroundColor))

                // 顶部光泽高光
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
                    )
                    .blendMode(.overlay)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // MARK: - 各种状态视图

    private var noKeyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .background(
                    Circle().fill(Color.orange.opacity(0.1)).frame(width: 40, height: 40)
                )
            Text("未设置 API Key")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text("点击右上角 ⚙ 进行设置")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .controlSize(.small)
            Text("正在获取余额...")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(.orange)
                .background(
                    Circle().fill(Color.orange.opacity(0.1)).frame(width: 36, height: 36)
                )
            Text("获取失败")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(msg)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
    }

    private var waitingView: some View {
        Text("等待首次刷新...")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .frame(height: 80)
    }

    // MARK: - 余额主卡片

    private func balanceCardView(_ model: BalanceDisplayModel) -> some View {
        VStack(spacing: 10) {
            // 余额主数字
            VStack(spacing: 2) {
                Text("可用余额")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(1)

                Text(model.balanceText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .animation(.easeInOut(duration: 0.3), value: model.balanceText)
            }

            // 分隔点
            Capsule()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 40, height: 2)

            // 统计小卡片行
            HStack(spacing: 10) {
                if let used = model.totalUsed {
                    statCard(label: "已使用", value: "¥\(short(used))", color: .orange)
                }
                if let granted = model.totalGranted {
                    statCard(label: "总额度", value: "¥\(short(granted))", color: .blue)
                }
                if model.totalGranted != nil {
                    statCard(label: "已用比例", value: "\(Int(model.usagePercent * 100))%", color: .purple)
                }
            }

            // 进度条
            if let granted = model.totalGranted, granted > 0 {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // 底层轨道
                            Capsule()
                                .fill(Color.gray.opacity(0.08))
                                .frame(height: 6)

                            // 渐变填充
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, Color(red: 0, green: 0.7, blue: 0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geo.size.width * min(max(model.usagePercent, 0), 1),
                                    height: 6
                                )
                                .animation(.easeInOut(duration: 0.5), value: model.usagePercent)

                            // 光泽高光
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    width: geo.size.width * min(max(model.usagePercent, 0), 1),
                                    height: 3
                                )
                                .blendMode(.overlay)
                        }
                    }
                    .frame(height: 6)

                    // 进度底部标注
                    HStack {
                        Text("0%")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 统计小卡片

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - 工具栏

    private var toolbarSection: some View {
        HStack(spacing: 8) {
            // 浮动窗按钮
            HStack(spacing: 4) {
                Image(systemName: floatPanelOn ? "pin.fill" : "pin")
                    .font(.system(size: 9))
                Text("浮动窗")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(floatPanelOn ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(floatPanelOn ? Color.blue.opacity(0.2) : Color.gray.opacity(0.08), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                floatPanelOn.toggle()
                NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil)
            }

            // 刷新按钮
            Button(action: { balanceService.refreshNow() }) {
                HStack(spacing: 4) {
                    if balanceService.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 8, height: 8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .medium))
                    }
                    Text("刷新")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            // 刷新频率
            Text(intervalLabel)
                .font(.system(size: 8))
                .foregroundColor(.secondary)

            Spacer()

            // 最后更新时间
            if let last = balanceService.lastUpdated {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 7))
                    Text(last, style: .time)
                        .font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.03))
        )
    }

    // MARK: - 退出

    private var exitSection: some View {
        HStack {
            Spacer()
            Button(action: { NSApp.terminate(nil) }) {
                HStack(spacing: 3) {
                    Image(systemName: "power")
                        .font(.system(size: 8))
                    Text("退出  (⌘Q)")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.bottom, 6)
        }
    }

    // MARK: - 工具方法

    private func short(_ n: Double) -> String {
        n >= 10000
            ? String(format: "%.1f万", n / 10000)
            : n >= 1
                ? String(format: "%.2f", n)
                : String(format: "%.4f", n)
    }
}