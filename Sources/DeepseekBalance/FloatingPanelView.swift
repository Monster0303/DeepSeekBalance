import SwiftUI
import Combine

struct FloatingPanelView: View {
    @StateObject private var balanceService = BalanceService.shared
    @State private var countdownSeconds: Int = 0
    @State private var countdownTimer: AnyCancellable?

    private var scale: CGFloat { CGFloat(SettingsManager.floatTextSize) / 24.0 }
    private var pw: CGFloat { CGFloat(SettingsManager.panelWidth) }
    private var ph: CGFloat { CGFloat(SettingsManager.panelHeight) }

    var body: some View {
        ZStack {
            // 毛玻璃基底
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)

            // 顶部渐变光晕
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [
                    .blue.opacity(0.08),
                    .blue.opacity(0.02),
                    .clear
                ], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

            VStack(spacing: 0) {
                // ── 顶部状态栏 ──
                HStack(spacing: 4) {
                    // 状态指示灯
                    Circle()
                        .fill(balanceService.balanceModel != nil ? Color.green : .secondary)
                        .frame(width: 6, height: 6)

                    Text("DeepSeek")
                        .font(.system(size: 11 * scale, weight: .medium))
                        .foregroundColor(.primary)

                    if balanceService.isLoading {
                        ProgressView()
                            .scaleEffect(0.35)
                            .frame(width: 10, height: 10)
                    }

                    Spacer()

                    // 倒计时
                    if let _ = balanceService.lastUpdated {
                        Text(formatCountdown(countdownSeconds))
                            .font(.system(size: 10 * scale, weight: .regular, design: .monospaced))
                            .foregroundColor(countdownSeconds <= 5 ? .orange : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(countdownSeconds <= 5 ? Color.orange.opacity(0.1) : Color.gray.opacity(0.06))
                            )
                    }

                    Button(action: { balanceService.refreshNow() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10 * scale, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10 * scale, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                // ── 余额主区 ──
                if let model = balanceService.balanceModel {
                    VStack(spacing: 6) {
                        // 余额数字
                        Text(model.balanceText)
                            .font(.system(size: CGFloat(SettingsManager.floatTextSize) * 1.1, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .animation(.easeInOut(duration: 0.3), value: model.balanceText)
                            .padding(.top, 2)

                        // 总额 / 已用 / 比例
                        HStack(spacing: 0) {
                            if let granted = model.totalGranted {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("总额")
                                        .font(.system(size: 9 * scale, weight: .regular))
                                        .foregroundColor(.secondary)
                                    Text(short(granted))
                                        .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                            }
                            if let used = model.totalUsed {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("已用")
                                        .font(.system(size: 9 * scale, weight: .regular))
                                        .foregroundColor(.secondary)
                                    Text(short(used))
                                        .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                            }
                            if model.totalGranted != nil {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("占比")
                                        .font(.system(size: 9 * scale, weight: .regular))
                                        .foregroundColor(.secondary)
                                    Text("\(Int(model.usagePercent * 100))%")
                                        .font(.system(size: 11 * scale, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                            }
                        }

                        // 进度条
                        if let granted = model.totalGranted, granted > 0 {
                            VStack(spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(height: 4)
                                        Capsule()
                                            .fill(
                                                LinearGradient(colors: [
                                                    Color(red: 0.3, green: 0.6, blue: 1.0),
                                                    Color(red: 0, green: 0.8, blue: 0.6)
                                                ], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .frame(
                                                width: geo.size.width * min(max(model.usagePercent, 0), 1),
                                                height: 4
                                            )
                                            .animation(.easeInOut(duration: 0.5), value: model.usagePercent)
                                    }
                                }
                                .frame(height: 4)

                                HStack {
                                    Text("已用 \(Int(model.usagePercent * 100))%")
                                        .font(.system(size: 9 * scale))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("剩余 \(short(max(0, granted - model.balance)))")
                                        .font(.system(size: 9 * scale))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                } else if balanceService.isLoading {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                } else if !SettingsManager.shared.hasAPIKey {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        Text("未设置 API Key")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    Spacer()
                    Text("等待首次刷新...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)
        }
        .frame(width: pw, height: ph)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            if let msg = balanceService.refreshSuccessMessage {
                Text(msg)
                    .font(.system(size: 8 * scale, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.bottom, 6)
                    .transition(.opacity)
                    .animation(.easeInOut, value: msg)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: scale)
        .onAppear(perform: startCountdown)
        .onDisappear(perform: stopCountdown)
        .onReceive(balanceService.$lastUpdated) { _ in resetCountdown() }
        .onReceive(balanceService.$balanceModel) { _ in resetCountdown() }
    }

    private var intervalLabel: String {
        let sec = SettingsManager.refreshInterval
        return sec < 60 ? "每\(Int(sec))秒" : "每\(Int(sec / 60))分钟"
    }

    // MARK: - 倒计时
    private func startCountdown() {
        resetCountdown()
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                guard let last = balanceService.lastUpdated else { return }
                let elapsed = Int(Date().timeIntervalSince(last))
                let total = Int(SettingsManager.refreshInterval)
                countdownSeconds = max(0, total - elapsed)
            }
    }

    private func stopCountdown() { countdownTimer?.cancel(); countdownTimer = nil }

    private func resetCountdown() {
        guard let last = balanceService.lastUpdated else { countdownSeconds = 0; return }
        let elapsed = Int(Date().timeIntervalSince(last))
        countdownSeconds = max(0, Int(SettingsManager.refreshInterval) - elapsed)
    }

    private func formatCountdown(_ sec: Int) -> String {
        if sec < 60 { return "\(sec)s" }
        let m = sec / 60
        let s = sec % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private func short(_ n: Double) -> String {
        n >= 10000 ? String(format: "%.1f万", n / 10000) : n >= 1 ? String(format: "%.2f", n) : String(format: "%.4f", n)
    }
}
