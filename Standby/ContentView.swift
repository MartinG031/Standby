import SwiftUI
import Combine
import AVFoundation
import UIKit
import CoreText

// MARK: - 根视图

struct ContentView: View {
    var body: some View {
        StandbyMainView()
            .preferredColorScheme(.dark)   // 始终深色
    }
}

#Preview {
    ContentView()
}

// MARK: - 待机主界面（只显示时间 + 摄像头检测）

struct StandbyMainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("standby.showSeconds") private var showSeconds = true
    @AppStorage("standby.showDate") private var showDate = true
    @AppStorage("standby.nightHideEnabled") private var nightHideEnabled = true
    @AppStorage("standby.presenceDetectionEnabled") private var presenceDetectionEnabled = true
    @AppStorage("standby.burnInProtectionEnabled") private var burnInProtectionEnabled = true
    @AppStorage("standby.autoRotateFaces") private var randomBackgroundEnabled = true
    @AppStorage("standby.selectedFace") private var selectedBackgroundRawValue = StandbyBackgroundStyle.seaMist.rawValue
    @AppStorage("standby.animatedBackgroundEnabled") private var animatedBackgroundEnabled = true
    @AppStorage("standby.backgroundWidthScale") private var backgroundWidthScale = 0.88
    @AppStorage("standby.backgroundHeightScale") private var backgroundHeightScale = 1.0
    @AppStorage("standby.backgroundFlowSpeed") private var backgroundFlowSpeed = 1.0
    @AppStorage("standby.backgroundContrast") private var backgroundContrast = 1.0
    @AppStorage("standby.backgroundBrightness") private var backgroundBrightness = 1.0
    @AppStorage("standby.backgroundFeather") private var backgroundFeather = 7.0
    @State private var offset = CGSize.zero
    @State private var offsetStep = 0
    @State private var isScreenOff = false      // 00:00-06:00 时间段黑屏
    @State private var isUserPresent = true     // 前置摄像头检测用户存在
    @State private var backgroundStyleIndex = Int.random(in: 0..<StandbyBackgroundStyle.allCases.count)
    @State private var visualSeed = Int.random(in: 0..<10_000)
    @State private var isShowingSettings = false
    private let schedule = StandbySchedule()

    // 轻微漂移：防烧屏
    private let driftTimer = Timer.publish(every: 60,
                                           on: .main,
                                           in: .common)
        .autoconnect()
    
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                let isCompact = totalWidth < 700

                ZStack {
                    // 根据时间 + 摄像头决定是否显示时间
                    Group {
                        if (isScreenOff || !isUserPresent) && !isShowingSettings {
                            Color.black
                                .accessibilityIdentifier("standbyHiddenDisplay")
                        } else {
                            BigClockView(fontSize: isCompact ? 120 : 160,
                                         backgroundStyle: currentBackgroundStyle,
                                         isCompact: isCompact,
                                         visualSeed: randomBackgroundEnabled ? visualSeed : 0,
                                         animatedBackgroundEnabled: animatedBackgroundEnabled,
                                         backgroundWidthScale: backgroundWidthScale,
                                         backgroundHeightScale: backgroundHeightScale,
                                         backgroundFlowSpeed: backgroundFlowSpeed,
                                         backgroundContrast: backgroundContrast,
                                         backgroundBrightness: backgroundBrightness,
                                         backgroundFeather: backgroundFeather,
                                         driftOffset: burnInProtectionEnabled ? offset : .zero,
                                         showSeconds: showSeconds,
                                         showDate: showDate)
                        }
                    }
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .center)
                    .background(standbyBackground.ignoresSafeArea())
                    .onAppear {
                        if StandbyBackgroundStyle(rawValue: selectedBackgroundRawValue) == nil {
                            selectedBackgroundRawValue = StandbyBackgroundStyle.seaMist.rawValue
                        }
                        updateScreenOff()
                        setIdleTimerDisabled(true)
                    }
                    .onDisappear {
                        setIdleTimerDisabled(false)
                    }
                    .onChange(of: scenePhase) { _, phase in
                        setIdleTimerDisabled(phase == .active)
                    }
                    .onReceive(driftTimer) { _ in
                        updateScreenOff() // 时间段判断
                        guard burnInProtectionEnabled else {
                            offset = .zero
                            return
                        }

                        offsetStep = (offsetStep + 1) % 4
                        withAnimation(.easeInOut(duration: 1)) {
                            switch offsetStep {
                            case 0: offset = .zero
                            case 1: offset = CGSize(width: 8, height: 4)
                            case 2: offset = CGSize(width: -6, height: -5)
                            case 3: offset = CGSize(width: 4, height: -6)
                            default: offset = .zero
                            }
                        }
                    }
                    .onChange(of: nightHideEnabled) { _, _ in
                        updateScreenOff()
                    }
                    .onChange(of: presenceDetectionEnabled) { _, enabled in
                        if !enabled {
                            isUserPresent = true
                        }
                    }
                    .onChange(of: burnInProtectionEnabled) { _, enabled in
                        if !enabled {
                            offset = .zero
                        }
                    }
                    .onChange(of: randomBackgroundEnabled) { _, enabled in
                        if enabled {
                            randomizeVisual()
                        }
                    }

                    if presenceDetectionEnabled {
                        // 隐藏的前置摄像头检测视图（只负责更新 isUserPresent）
                        CameraPresenceView(isUserPresent: Binding(
                            get: { isUserPresent },
                            set: { present in
                                updateUserPresence(present)
                            }
                        ))
                            .frame(width: 1, height: 1)
                            .opacity(0.001)   // 几乎不可见，只用于驱动摄像头
                            .accessibilityHidden(true)
                    }

                }
                .contentShape(Rectangle())
                .gesture(settingsSwipeGesture)
                .animation(.easeInOut(duration: 0.25), value: isShowingSettings)
            }
            .ignoresSafeArea(.all)
            if isShowingSettings {
                StandbySettingsPanel(isPresented: $isShowingSettings,
                                     showSeconds: $showSeconds,
                                     showDate: $showDate,
                                     nightHideEnabled: $nightHideEnabled,
                                     presenceDetectionEnabled: $presenceDetectionEnabled,
                                     burnInProtectionEnabled: $burnInProtectionEnabled,
                                     randomBackgroundEnabled: $randomBackgroundEnabled,
                                     animatedBackgroundEnabled: $animatedBackgroundEnabled,
                                     selectedBackgroundRawValue: $selectedBackgroundRawValue,
                                     backgroundWidthScale: $backgroundWidthScale,
                                     backgroundHeightScale: $backgroundHeightScale,
                                     backgroundFlowSpeed: $backgroundFlowSpeed,
                                     backgroundContrast: $backgroundContrast,
                                     backgroundBrightness: $backgroundBrightness,
                                     backgroundFeather: $backgroundFeather)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingSettings)
    }
    
    private var currentBackgroundStyle: StandbyBackgroundStyle {
        if !randomBackgroundEnabled {
            return StandbyBackgroundStyle(rawValue: selectedBackgroundRawValue) ?? .seaMist
        }

        let styles = StandbyBackgroundStyle.allCases
        return styles[backgroundStyleIndex % styles.count]
    }

    private var standbyBackground: some View {
        Color.black
    }
    
    private func updateScreenOff() {
        isScreenOff = nightHideEnabled
            && !ProcessInfo.processInfo.environment.keys.contains("STANDBY_DISABLE_NIGHT_HIDE")
            && schedule.shouldHideDisplay(at: Date())
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    private func updateUserPresence(_ present: Bool) {
        if present && !isUserPresent && randomBackgroundEnabled {
            withAnimation(.easeInOut(duration: 0.45)) {
                randomizeVisual()
            }
        }

        isUserPresent = present
    }

    private func randomizeVisual() {
        backgroundStyleIndex = StandbyBackgroundStyle.randomIndex(excluding: backgroundStyleIndex)
        visualSeed = Int.random(in: 0..<10_000)
    }

    private var settingsSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 34)
            .onEnded { value in
                if value.translation.height < -54 {
                    isShowingSettings = true
                } else if value.translation.height > 54 {
                    isShowingSettings = false
                }
            }
    }
}

struct StandbySettingsPanel: View {
    @Binding var isPresented: Bool
    @Binding var showSeconds: Bool
    @Binding var showDate: Bool
    @Binding var nightHideEnabled: Bool
    @Binding var presenceDetectionEnabled: Bool
    @Binding var burnInProtectionEnabled: Bool
    @Binding var randomBackgroundEnabled: Bool
    @Binding var animatedBackgroundEnabled: Bool
    @Binding var selectedBackgroundRawValue: String
    @Binding var backgroundWidthScale: Double
    @Binding var backgroundHeightScale: Double
    @Binding var backgroundFlowSpeed: Double
    @Binding var backgroundContrast: Double
    @Binding var backgroundBrightness: Double
    @Binding var backgroundFeather: Double

    private struct Adjustment {
        let title: String
        let value: Binding<Double>
        let range: ClosedRange<Double>
        let step: Double
        let percent: Bool
    }

    @State private var activeAdjustment: Adjustment?
    @State private var isOriginalDrag = false
    @State private var restoreTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
            VStack {
                Spacer()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Capsule()
                            .fill(.white.opacity(0.28))
                            .frame(width: 42, height: 5)
                            .padding(.top, 10)
                            .padding(.horizontal, 40)
                            .contentShape(Rectangle())
                            .gesture(DragGesture().onEnded { value in
                                if value.translation.height > 48 { isPresented = false }
                            })

                        HStack {
                            Text("设置")
                                .font(.system(size: 22, weight: .bold, design: .rounded))

                            Spacer()

                            Button {
                                isPresented = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("关闭设置")
                        }

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ], spacing: 12) {
                            settingToggle(title: "显示秒数", systemImage: "timer", isOn: $showSeconds)
                            settingToggle(title: "显示日期", systemImage: "calendar", isOn: $showDate)
                            settingToggle(title: "夜间隐藏", systemImage: "moon.fill", isOn: $nightHideEnabled)
                            settingToggle(title: "人脸点亮", systemImage: "faceid", isOn: $presenceDetectionEnabled)
                            settingToggle(title: "人脸随机背景", systemImage: "shuffle", isOn: $randomBackgroundEnabled)
                            settingToggle(title: "防烧屏漂移", systemImage: "arrow.up.left.and.arrow.down.right", isOn: $burnInProtectionEnabled)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("固定背景", systemImage: "paintpalette.fill")
                                Spacer()
                                Toggle("流动", isOn: $animatedBackgroundEnabled)
                                    .fixedSize()
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))

                            Picker("固定背景", selection: $selectedBackgroundRawValue) {
                                ForEach(StandbyBackgroundStyle.allCases) { style in
                                    Text(style.name).tag(style.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(randomBackgroundEnabled)
                            .opacity(randomBackgroundEnabled ? 0.45 : 1)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Label("背景范围", systemImage: "aspectratio")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))

                            dimensionSlider(title: "宽度", value: $backgroundWidthScale)
                            dimensionSlider(title: "高度", value: $backgroundHeightScale)
                        }

                        backgroundSlider(title: "流动速度", value: $backgroundFlowSpeed,
                                         range: 0.25...2.0)
                            .disabled(!animatedBackgroundEnabled)
                        backgroundSlider(title: "背景对比度", value: $backgroundContrast,
                                         range: 0.5...1.5)
                        backgroundSlider(title: "背景亮度", value: $backgroundBrightness,
                                         range: 0.3...1.5)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("边缘羽化", systemImage: "drop.halffull")
                                Spacer()
                                Text("\(Int(backgroundFeather))")
                                    .monospacedDigit()
                            }
                            Slider(value: $backgroundFeather, in: 0...40, step: 1,
                                   onEditingChanged: { editing in
                                       editAdjustment(editing, adjustment: Adjustment(
                                           title: "边缘羽化", value: $backgroundFeather,
                                           range: 0...40, step: 1, percent: false))
                                   })
                                .accessibilityLabel("边缘羽化")
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
                .frame(maxHeight: max(0, proxy.size.height - 36))
                .foregroundStyle(.white)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            // Keep the original slider mounted until its drag finishes.
            .opacity(activeAdjustment == nil ? 1 : 0.001)
            .allowsHitTesting(activeAdjustment == nil || isOriginalDrag)
            .accessibilityHidden(activeAdjustment != nil)

            if let adjustment = activeAdjustment {
                VStack(spacing: 8) {
                    HStack {
                        Text(adjustment.title)
                        Spacer()
                        Text(adjustment.percent
                             ? "\(Int((adjustment.value.wrappedValue * 100).rounded()))%"
                             : "\(Int(adjustment.value.wrappedValue))")
                            .monospacedDigit()
                    }
                    Slider(value: adjustment.value, in: adjustment.range, step: adjustment.step,
                           onEditingChanged: { editing in
                               editAdjustment(editing, adjustment: adjustment, fromPreview: true)
                           })
                        .accessibilityLabel(adjustment.title)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .allowsHitTesting(!isOriginalDrag)
                .accessibilityIdentifier("standbyAdjustmentPreview")
            }
            }
        }
        .background(Color.black.opacity(activeAdjustment == nil ? 0.32 : 0).ignoresSafeArea())
        .onDisappear {
            restoreTask?.cancel()
        }
        .accessibilityIdentifier("standbySettingsPanel")
    }

    private func editAdjustment(_ editing: Bool, adjustment: Adjustment,
                                fromPreview: Bool = false) {
        restoreTask?.cancel()
        if editing {
            isOriginalDrag = !fromPreview
            activeAdjustment = adjustment
        } else {
            isOriginalDrag = false
            restoreTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                activeAdjustment = nil
            }
        }
    }

    private func backgroundSlider(title: String, value: Binding<Double>,
                                  range: ClosedRange<Double>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.65))
            }
            Slider(value: value, in: range, step: 0.05,
                   onEditingChanged: { editing in
                       editAdjustment(editing, adjustment: Adjustment(
                           title: title, value: value, range: range, step: 0.05, percent: true))
                   })
                .accessibilityLabel(title)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
    }

    private func dimensionSlider(title: String,
                                 value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .font(.system(size: 14, design: .rounded))

            Slider(value: value, in: 0.70...1.0, step: 0.01,
                   onEditingChanged: { editing in
                       editAdjustment(editing, adjustment: Adjustment(
                           title: "背景\(title)", value: value, range: 0.70...1.0,
                           step: 0.01, percent: true))
                   })
                .accessibilityLabel("背景\(title)")
        }
    }

    private func settingToggle(title: String,
                               systemImage: String,
                               isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 大号时钟（带秒）

enum StandbyBackgroundStyle: String, CaseIterable, Identifiable {
    case seaMist
    case spring
    case clearSky
    case dawn
    case deepForest
    case ocean
    case graphite

    var id: String { rawValue }

    static func randomIndex(excluding index: Int) -> Int {
        guard allCases.count > 1 else { return 0 }
        guard allCases.indices.contains(index) else {
            return Int.random(in: allCases.indices)
        }

        let candidate = Int.random(in: 0..<(allCases.count - 1))
        return candidate >= index ? candidate + 1 : candidate
    }

    var name: String {
        switch self {
        case .seaMist: "海雾"
        case .spring: "春绿"
        case .clearSky: "晴空"
        case .dawn: "晨曦"
        case .deepForest: "深林"
        case .ocean: "海洋"
        case .graphite: "石墨"
        }
    }

    var accent: Color {
        switch self {
        case .seaMist: Color(red: 0.82, green: 0.98, blue: 0.93)
        case .spring: Color(red: 0.88, green: 1.00, blue: 0.78)
        case .clearSky: Color(red: 0.82, green: 0.95, blue: 1.00)
        case .dawn: Color(red: 1.00, green: 0.92, blue: 0.76)
        case .deepForest: Color(red: 0.86, green: 0.97, blue: 0.87)
        case .ocean: Color(red: 0.84, green: 0.95, blue: 1.00)
        case .graphite: .white
        }
    }

    var secondary: Color {
        switch self {
        case .graphite: Color.white.opacity(0.72)
        case .seaMist: Color(red: 0.66, green: 0.88, blue: 0.86)
        case .spring: Color(red: 0.67, green: 0.88, blue: 0.67)
        case .clearSky: Color(red: 0.66, green: 0.84, blue: 0.94)
        case .dawn: Color(red: 0.93, green: 0.73, blue: 0.66)
        case .deepForest: Color(red: 0.61, green: 0.80, blue: 0.66)
        case .ocean: Color(red: 0.61, green: 0.80, blue: 0.91)
        }
    }

    var flowColors: [Color] {
        switch self {
        case .seaMist:
            [
                Color(red: 0.02, green: 0.18, blue: 0.30),
                Color(red: 0.02, green: 0.52, blue: 0.47),
                Color(red: 0.29, green: 0.72, blue: 0.58),
                Color(red: 0.08, green: 0.34, blue: 0.53)
            ]
        case .spring:
            [
                Color(red: 0.02, green: 0.25, blue: 0.22),
                Color(red: 0.12, green: 0.62, blue: 0.37),
                Color(red: 0.57, green: 0.72, blue: 0.18),
                Color(red: 0.08, green: 0.46, blue: 0.55)
            ]
        case .clearSky:
            [
                Color(red: 0.04, green: 0.20, blue: 0.52),
                Color(red: 0.08, green: 0.52, blue: 0.85),
                Color(red: 0.20, green: 0.76, blue: 0.69),
                Color(red: 0.34, green: 0.43, blue: 0.82)
            ]
        case .dawn:
            [
                Color(red: 0.34, green: 0.10, blue: 0.36),
                Color(red: 0.76, green: 0.21, blue: 0.42),
                Color(red: 0.95, green: 0.48, blue: 0.25),
                Color(red: 0.45, green: 0.31, blue: 0.65)
            ]
        case .deepForest:
            [
                Color(red: 0.02, green: 0.17, blue: 0.20),
                Color(red: 0.04, green: 0.42, blue: 0.30),
                Color(red: 0.34, green: 0.66, blue: 0.39),
                Color(red: 0.07, green: 0.37, blue: 0.56)
            ]
        case .ocean:
            [
                Color(red: 0.01, green: 0.07, blue: 0.25),
                Color(red: 0.03, green: 0.28, blue: 0.60),
                Color(red: 0.02, green: 0.57, blue: 0.62),
                Color(red: 0.20, green: 0.31, blue: 0.68)
            ]
        case .graphite:
            [
                Color(red: 0.04, green: 0.05, blue: 0.08),
                Color(red: 0.18, green: 0.21, blue: 0.28),
                Color(red: 0.35, green: 0.39, blue: 0.43),
                Color(red: 0.12, green: 0.25, blue: 0.28)
            ]
        }
    }


}

struct BigClockView : View {
    var fontSize: CGFloat = 140
    var backgroundStyle: StandbyBackgroundStyle = .seaMist
    var isCompact: Bool = false
    var visualSeed: Int = 0
    var animatedBackgroundEnabled: Bool = true
    var backgroundWidthScale: Double = 0.88
    var backgroundHeightScale: Double = 1.0
    var backgroundFlowSpeed: Double = 1.0
    var backgroundContrast: Double = 1.0
    var backgroundBrightness: Double = 1.0
    var backgroundFeather: Double = 7.0
    var driftOffset: CGSize = .zero
    var showSeconds: Bool = true
    var showDate: Bool = true
    
    @State private var now = Date()
    @State private var flowAnchor = Date()
    @State private var flowElapsed = 0.0
    private let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()
    
    // HH:mm:ss 格式
    private static let timeWithSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let timeWithoutSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // yyyy年MM月dd日 EEEE（例如：2025年12月03日 星期三）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")   // 确保星期是中文
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            background
            clockFace
                .offset(driftOffset)
                .opacity(0.8)
        }
        .onReceive(timer) { value in
            now = value
        }
        .onChange(of: backgroundFlowSpeed) { oldSpeed, _ in
            updateFlowAnchor(speed: oldSpeed, running: animatedBackgroundEnabled)
        }
        .onChange(of: animatedBackgroundEnabled) { wasRunning, _ in
            updateFlowAnchor(speed: backgroundFlowSpeed, running: wasRunning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .transition(.opacity)
    }

    private var timeText: String {
        let formatter = showSeconds ? Self.timeWithSecondsFormatter : Self.timeWithoutSecondsFormatter
        return formatter.string(from: now)
    }

    private var dateText: String {
        Self.dateFormatter.string(from: now)
    }

    private var background: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                Group {
                    featheredBackground
                        .overlay {
                            Color.black.opacity(0.25)
                                .mask {
                                    Rectangle()
                                        .fill(.white)
                                        .overlay {
                                            // A broad feather avoids refracting a hard glyph-shaped boundary.
                                            RoundedRectangle(cornerRadius: fontSize * 0.45)
                                                .fill(.white)
                                                .frame(width: proxy.size.width * 0.94,
                                                       height: fontSize * 1.35)
                                                .blur(radius: fontSize * 0.24)
                                                .position(
                                                    x: proxy.size.width / 2,
                                                    y: proxy.size.height / 2 - (isCompact ? 20 : 28)
                                                )
                                                .offset(driftOffset)
                                                .blendMode(.destinationOut)
                                        }
                                        .compositingGroup()
                                }
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }

    private var featheredBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                paused: !animatedBackgroundEnabled)) { timeline in
            GeometryReader { proxy in
                let shortEdge = min(proxy.size.width, proxy.size.height)
                let featherRadius = min(max(backgroundFeather, 0), 40)

                flowingBackground(at: timeline.date, size: proxy.size)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .mask {
                        RoundedRectangle(
                            cornerRadius: shortEdge * 0.1,
                            style: .continuous
                        )
                        .fill(.white)
                        .frame(width: proxy.size.width * CGFloat(backgroundWidthScale),
                               height: proxy.size.height * CGFloat(backgroundHeightScale))
                        .blur(radius: featherRadius)
                    }
            }
        }
    }

    private func flowingBackground(at date: Date, size: CGSize) -> some View {
        let colors = backgroundStyle.flowColors
        let phase = flowPhase(at: date)
        let glowCenter = flowPoint(phase: -phase * 0.82 + 1.7)
        let glowRadius = max(size.width, size.height) * 0.58
        let meshBlurRadius = min(size.width, size.height) * 0.03

        return ZStack {
            MeshGradient(width: 4,
                         height: 3,
                         points: meshPoints(phase: phase),
                         colors: meshColors(colors),
                         background: colors[0],
                         smoothsColors: true,
                         colorSpace: .perceptual)
                .scaleEffect(1.12)
                .blur(radius: meshBlurRadius)

            RadialGradient(colors: [colors[2].opacity(0.72), .clear],
                           center: glowCenter,
                           startRadius: 0,
                           endRadius: glowRadius)
                .blendMode(.screen)
        }
        .saturation(1.14)
        .contrast(backgroundContrast)
        .colorMultiply(Color(white: min(backgroundBrightness, 1)))
        .brightness(max(0, backgroundBrightness - 1) * 0.3)
    }

    private func updateFlowAnchor(speed: Double, running: Bool) {
        let date = Date()
        if running {
            flowElapsed += date.timeIntervalSince(flowAnchor) * speed
        }
        flowAnchor = date
    }

    private func flowPhase(at date: Date) -> Double {
        let seedPhase = Double(visualSeed % 997) / 997.0 * .pi * 2
        let duration = 10.0 + Double(visualSeed % 4) * 3.0
        let direction = visualSeed.isMultiple(of: 2) ? 1.0 : -1.0
        let elapsed = flowElapsed + (animatedBackgroundEnabled
            ? date.timeIntervalSince(flowAnchor) * backgroundFlowSpeed : 0)
        return elapsed / duration * .pi * 2 * direction + seedPhase
    }

    private func meshPoints(phase: Double) -> [SIMD2<Float>] {
        let seedOffset = Double(visualSeed % 37) * 0.17

        return [
            SIMD2(0.00, 0.00), SIMD2(0.33, 0.00), SIMD2(0.67, 0.00), SIMD2(1.00, 0.00),
            SIMD2(0.00, 0.50),
            meshPoint(x: 0.34 + sin(phase + seedOffset) * 0.10,
                      y: 0.48 + cos(phase * 1.21 + 0.8) * 0.24),
            meshPoint(x: 0.67 + cos(phase * 0.91 + seedOffset) * 0.10,
                      y: 0.52 + sin(phase * 1.13 + 2.1) * 0.23),
            SIMD2(1.00, 0.50),
            SIMD2(0.00, 1.00), SIMD2(0.33, 1.00), SIMD2(0.67, 1.00), SIMD2(1.00, 1.00)
        ]
    }

    private func meshPoint(x: Double, y: Double) -> SIMD2<Float> {
        SIMD2(Float(x), Float(y))
    }

    private func meshColors(_ colors: [Color]) -> [Color] {
        let offset = abs(visualSeed) % colors.count
        let first = colors[offset]
        let second = colors[(offset + 1) % colors.count]
        let third = colors[(offset + 2) % colors.count]
        let fourth = colors[(offset + 3) % colors.count]

        return [
            first, first, second, second,
            first, fourth, third, second,
            fourth, fourth, third, third
        ]
    }

    private func flowPoint(phase: Double) -> UnitPoint {
        UnitPoint(
            x: CGFloat(0.5 + sin(phase) * 0.70),
            y: CGFloat(0.5 + cos(phase * 0.83) * 0.60)
        )
    }

    private var clockFace: some View {
        GeometryReader { proxy in
            let contentCenterY = proxy.size.height / 2 - (isCompact ? 20 : 28)

            ZStack {
                frostedTimeLabel(size: fontSize,
                                     weight: UIFont.Weight.bold.rawValue)
                    .frame(width: proxy.size.width * 0.90)
                    .shadow(color: Color.black.opacity(0.28),
                            radius: 12,
                            x: 0,
                            y: 4)
                    .position(x: proxy.size.width / 2,
                              y: contentCenterY)

                if showDate {
                    dateLabel(size: isCompact ? 24 : 30,
                              color: backgroundStyle.secondary)
                        .frame(width: proxy.size.width * 0.90)
                        .position(x: proxy.size.width / 2,
                                  y: contentCenterY + (isCompact ? 92 : 118))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func frostedTimeLabel(size: CGFloat,
                                  weight: CGFloat) -> some View {
        let outline = ClockNumeralShape(text: timeText, fontSize: size, weight: UIFont.Weight.bold.rawValue)

        return numeralGlyph(size: size, weight: weight)
            .hidden()
            .overlay {
                outline.fill(.thinMaterial)
                    .overlay {
                        outline.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.78), .white.opacity(0.62)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timeText)
            .accessibilityIdentifier("standbyClockTime")
    }

    private func numeralGlyph(size: CGFloat,
                              weight: CGFloat) -> some View {
        Text(timeText)
            .font(Font(ClockNumeralShape.font(size: size, weight: weight)))
            .monospacedDigit()
            .minimumScaleFactor(0.45)
            .lineLimit(1)
    }

    private func dateLabel(size: CGFloat, color: Color) -> some View {
        Text(dateText)
            .font(.system(size: size,
                          weight: .bold,
                          design: .rounded))
            .monospacedDigit()
            .foregroundColor(color)
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .accessibilityIdentifier("standbyClockDate")
    }
}

private struct ClockNumeralShape: Shape {
    let outline: Path

    init(text: String, fontSize: CGFloat, weight: CGFloat) {
        let font = Self.font(size: fontSize, weight: weight)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font])
        )
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as! CTFont
            for index in glyphs.indices {
                if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) {
                    path.addPath(glyph, transform: CGAffineTransform(
                        translationX: positions[index].x, y: positions[index].y
                    ))
                }
            }
        }
        outline = Path(path)
    }

    static func font(size: CGFloat, weight: CGFloat) -> UIFont {
        let base = UIFont.monospacedDigitSystemFont(ofSize: size, weight: UIFont.Weight(rawValue: weight))
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }

    nonisolated func path(in rect: CGRect) -> Path {
        let bounds = outline.boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        let scale = min(1, rect.width / bounds.width, rect.height / bounds.height)
        // Core Text uses an upward Y axis; center the visible glyph bounds.
        return outline.applying(CGAffineTransform(
            a: scale, b: 0, c: 0, d: -scale,
            tx: rect.midX - bounds.midX * scale,
            ty: rect.midY + bounds.midY * scale
        ))
    }
}

// MARK: - 前置摄像头存在检测（仅用于判断是否有人）

struct CameraPresenceView: UIViewControllerRepresentable {
    @Binding var isUserPresent: Bool

    func makeUIViewController(context: Context) -> CameraPresenceController {
        let controller = CameraPresenceController()
        controller.onPresenceChanged = { present in
            // 回调到 SwiftUI
            DispatchQueue.main.async {
                self.isUserPresent = present
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPresenceController,
                                context: Context) {
        // 不需要更新任何东西
    }
}

// MARK: - 使用 AVFoundation 做人脸检测

final class CameraPresenceController: UIViewController {
    var onPresenceChanged: ((Bool) -> Void)?

    private lazy var sessionCoordinator = CameraPresenceSessionCoordinator { [weak self] present in
        self?.onPresenceChanged?(present)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionCoordinator.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionCoordinator.stop()
    }

}

// MARK: - 摄像头会话管理

final class CameraPresenceSessionCoordinator: NSObject,
                                              AVCaptureMetadataOutputObjectsDelegate,
                                              @unchecked Sendable {
    private let onPresenceChanged: @MainActor (Bool) -> Void
    nonisolated(unsafe) private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "Martin.Standby.cameraPresenceSession")
    nonisolated(unsafe) private var isConfigured = false
    nonisolated(unsafe) private var shouldRunSession = false
    nonisolated(unsafe) private var lastPresence: Bool = true
    nonisolated(unsafe) private var pendingOffWorkItem: DispatchWorkItem?

    init(onPresenceChanged: @escaping @MainActor (Bool) -> Void) {
        self.onPresenceChanged = onPresenceChanged
        super.init()
    }

    nonisolated func start() {
        sessionQueue.async { [self] in
            shouldRunSession = true
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startAuthorizedSession()
                } else {
                    self?.emitPresence(true)
                }
            }
        case .denied, .restricted:
            emitPresence(true)
        @unknown default:
            emitPresence(true)
        }
    }

    nonisolated private func startAuthorizedSession() {
        sessionQueue.async { [self] in
            guard shouldRunSession else { return }
            configureSessionIfNeeded()

            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    nonisolated func stop() {
        DispatchQueue.main.async { [self] in
            pendingOffWorkItem?.cancel()
            pendingOffWorkItem = nil
            lastPresence = true
        }

        sessionQueue.async { [self] in
            shouldRunSession = false
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    nonisolated private func configureSessionIfNeeded() {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            emitPresence(true)
            return
        }

        guard session.canAddInput(input) else {
            emitPresence(true)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            emitPresence(true)
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .medium
        session.addInput(input)
        session.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        if metadataOutput.availableMetadataObjectTypes.contains(.face) {
            metadataOutput.metadataObjectTypes = [.face]
        }
        session.commitConfiguration()
        isConfigured = true
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        let hasFace = metadataObjects.contains { $0 is AVMetadataFaceObject }

        if hasFace == lastPresence {
            return
        }

        if hasFace {
            pendingOffWorkItem?.cancel()
            pendingOffWorkItem = nil

            lastPresence = true
            emitPresence(true)
        } else {
            pendingOffWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.lastPresence == false else { return }
                self.emitPresence(false)
            }
            pendingOffWorkItem = workItem
            lastPresence = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 5,
                                          execute: workItem)
        }
    }

    nonisolated private func emitPresence(_ present: Bool) {
        Task { @MainActor in
            onPresenceChanged(present)
        }
    }
}
