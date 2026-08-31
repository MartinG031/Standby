import SwiftUI
import Combine
import AVFoundation
import UIKit

// 统一前景色（白色）
let standbyAccent = Color.white

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
    @AppStorage("standby.autoRotateFaces") private var autoRotateFaces = true
    @AppStorage("standby.selectedFace") private var selectedFaceRawValue = StandbyFaceStyle.classic.rawValue
    @AppStorage("standby.displayBrightness") private var displayBrightness = 1.0
    @State private var offset = CGSize.zero
    @State private var offsetStep = 0
    @State private var isScreenOff = false      // 00:00-06:00 时间段黑屏
    @State private var isUserPresent = true     // 前置摄像头检测用户存在
    @State private var faceStyleIndex = 0
    @State private var isShowingSettings = false
    private let schedule = StandbySchedule()

    // 轻微漂移：防烧屏
    private let driftTimer = Timer.publish(every: 60,
                                           on: .main,
                                           in: .common)
        .autoconnect()
    
    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let isCompact = totalWidth < 700
            
            ZStack {
                // 根据时间 + 摄像头决定是否显示时间
                Group {
                    if isScreenOff || !isUserPresent {
                        Color.black
                            .accessibilityIdentifier("standbyHiddenDisplay")
                    } else {
                        BigClockView(fontSize: isCompact ? 120 : 160,
                                     style: currentFaceStyle,
                                     isCompact: isCompact,
                                     driftOffset: burnInProtectionEnabled ? offset : .zero,
                                     showSeconds: showSeconds,
                                     showDate: showDate)
                            .opacity(displayBrightness)
                    }
                }
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity,
                       alignment: .center)
                .background(standbyBackground.ignoresSafeArea())
                .onAppear {
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

                if isShowingSettings {
                    StandbySettingsPanel(isPresented: $isShowingSettings,
                                         showSeconds: $showSeconds,
                                         showDate: $showDate,
                                         nightHideEnabled: $nightHideEnabled,
                                         presenceDetectionEnabled: $presenceDetectionEnabled,
                                         burnInProtectionEnabled: $burnInProtectionEnabled,
                                         autoRotateFaces: $autoRotateFaces,
                                         selectedFaceRawValue: $selectedFaceRawValue,
                                         displayBrightness: $displayBrightness)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .contentShape(Rectangle())
            .gesture(settingsSwipeGesture)
            .animation(.easeInOut(duration: 0.25), value: isShowingSettings)
        }
        .ignoresSafeArea(.all)
    }
    
    private var currentFaceStyle: StandbyFaceStyle {
        if !autoRotateFaces {
            return StandbyFaceStyle(rawValue: selectedFaceRawValue) ?? .classic
        }

        let styles = StandbyFaceStyle.allCases
        return styles[faceStyleIndex % styles.count]
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
        if present && !isUserPresent && autoRotateFaces {
            withAnimation(.easeInOut(duration: 0.45)) {
                faceStyleIndex = StandbyFaceStyle.index(after: faceStyleIndex)
            }
        }

        isUserPresent = present
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
    @Binding var autoRotateFaces: Bool
    @Binding var selectedFaceRawValue: String
    @Binding var displayBrightness: Double

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Capsule()
                            .fill(.white.opacity(0.28))
                            .frame(width: 42, height: 5)
                            .padding(.top, 10)

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
                            settingToggle(title: "自动换界面", systemImage: "rectangle.2.swap", isOn: $autoRotateFaces)
                            settingToggle(title: "防烧屏漂移", systemImage: "arrow.up.left.and.arrow.down.right", isOn: $burnInProtectionEnabled)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Label("界面样式", systemImage: "rectangle.on.rectangle")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))

                            Picker("界面样式", selection: $selectedFaceRawValue) {
                                ForEach(StandbyFaceStyle.allCases) { style in
                                    Text(style.name).tag(style.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(autoRotateFaces)
                            .opacity(autoRotateFaces ? 0.45 : 1)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("亮度", systemImage: "sun.max.fill")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))
                                Spacer()
                                Text("\(Int(displayBrightness * 100))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                            }

                            Slider(value: $displayBrightness, in: 0.35...1.0, step: 0.05)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
                .frame(maxHeight: max(260, proxy.size.height * 0.86))
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
        }
        .background(Color.black.opacity(0.32).ignoresSafeArea())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 48 {
                        isPresented = false
                    }
                }
        )
        .accessibilityIdentifier("standbySettingsPanel")
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

enum StandbyFaceStyle: String, CaseIterable, Identifiable {
    case classic
    case orbit
    case horizon
    case focus
    case zenith

    var id: String { rawValue }

    static func index(after index: Int) -> Int {
        (index + 1) % allCases.count
    }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .orbit: "Orbit"
        case .horizon: "Horizon"
        case .focus: "Focus"
        case .zenith: "Zenith"
        }
    }

    var accent: Color {
        switch self {
        case .classic: .white
        case .orbit: Color(red: 0.16, green: 0.98, blue: 0.87)
        case .horizon: Color(red: 1.0, green: 0.81, blue: 0.44)
        case .focus: Color(red: 0.51, green: 1.0, blue: 0.94)
        case .zenith: Color(red: 0.81, green: 0.62, blue: 0.99)
        }
    }

    var secondary: Color {
        switch self {
        case .classic: Color.white.opacity(0.72)
        case .orbit: Color(red: 0.30, green: 0.51, blue: 1.0)
        case .horizon: Color(red: 0.14, green: 0.46, blue: 0.87)
        case .focus: Color(red: 0.94, green: 0.40, blue: 0.71)
        case .zenith: Color(red: 0.45, green: 0.40, blue: 0.94)
        }
    }
}

struct BigClockView : View {
    var fontSize: CGFloat = 140
    var style: StandbyFaceStyle = .classic
    var isCompact: Bool = false
    var driftOffset: CGSize = .zero
    var showSeconds: Bool = true
    var showDate: Bool = true
    
    @State private var now = Date()
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

            Group {
                switch style {
                case .classic:
                    classicFace
                case .orbit:
                    orbitFace
                case .horizon:
                    horizonFace
                case .focus:
                    focusFace
                case .zenith:
                    zenithFace
                }
            }
            .offset(driftOffset)
        }
        .onReceive(timer) { value in
            now = value
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

                if style != .classic {
                    moodGradient
                    centerWash
                    artLineField
                    notchEdgeShade
                    verticalEdgeShade
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }

    private var moodGradient: some View {
        LinearGradient(colors: backgroundPalette,
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
            .opacity(0.78)
    }

    private var backgroundPalette: [Color] {
        switch style {
        case .classic:
            [
                Color(red: 0.02, green: 0.02, blue: 0.04),
                Color(red: 0.12, green: 0.13, blue: 0.17),
                Color.black
            ]
        case .orbit:
            [
                Color(red: 0.01, green: 0.02, blue: 0.08),
                Color(red: 0.02, green: 0.21, blue: 0.24),
                Color(red: 0.10, green: 0.18, blue: 0.43),
                Color.black
            ]
        case .horizon:
            [
                Color(red: 0.04, green: 0.02, blue: 0.04),
                Color(red: 0.30, green: 0.16, blue: 0.08),
                Color(red: 0.03, green: 0.15, blue: 0.34),
                Color.black
            ]
        case .focus:
            [
                Color(red: 0.01, green: 0.04, blue: 0.04),
                Color(red: 0.02, green: 0.20, blue: 0.18),
                Color(red: 0.24, green: 0.07, blue: 0.18),
                Color.black
            ]
        case .zenith:
            [
                Color(red: 0.03, green: 0.02, blue: 0.09),
                Color(red: 0.16, green: 0.08, blue: 0.30),
                Color(red: 0.07, green: 0.06, blue: 0.35),
                Color.black
            ]
        }
    }

    private var centerWash: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.00),
            .init(color: style.secondary.opacity(0.18), location: 0.38),
            .init(color: style.accent.opacity(0.16), location: 0.52),
            .init(color: style.secondary.opacity(0.12), location: 0.66),
            .init(color: .clear, location: 1.00)
        ], startPoint: .leading, endPoint: .trailing)
            .blur(radius: 28)
            .opacity(0.72)
    }

    private var artLineField: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<7, id: \.self) { index in
                    Rectangle()
                        .fill(style.secondary.opacity(index.isMultiple(of: 2) ? 0.08 : 0.04))
                        .frame(width: proxy.size.width * 0.42, height: 1)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : 18))
                        .offset(x: CGFloat(index - 3) * proxy.size.width * 0.16,
                                y: CGFloat(index % 3 - 1) * proxy.size.height * 0.18)
                }

                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(style.accent.opacity(0.05))
                        .frame(width: 1, height: proxy.size.height * 0.56)
                        .offset(x: CGFloat(index - 2) * proxy.size.width * 0.18)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var notchEdgeShade: some View {
        LinearGradient(stops: [
            .init(color: Color.black.opacity(0.98), location: 0.00),
            .init(color: Color.black.opacity(0.76), location: 0.07),
            .init(color: Color.black.opacity(0.18), location: 0.18),
            .init(color: .clear, location: 0.33),
            .init(color: .clear, location: 0.67),
            .init(color: Color.black.opacity(0.18), location: 0.82),
            .init(color: Color.black.opacity(0.76), location: 0.93),
            .init(color: Color.black.opacity(0.98), location: 1.00)
        ], startPoint: .leading, endPoint: .trailing)
    }

    private var verticalEdgeShade: some View {
        LinearGradient(stops: [
            .init(color: Color.black.opacity(0.88), location: 0.00),
            .init(color: Color.black.opacity(0.30), location: 0.14),
            .init(color: .clear, location: 0.34),
            .init(color: .clear, location: 0.66),
            .init(color: Color.black.opacity(0.30), location: 0.86),
            .init(color: Color.black.opacity(0.88), location: 1.00)
        ], startPoint: .top, endPoint: .bottom)
    }

    private var classicFace: some View {
        VStack(spacing: 12) {
            timeLabel(size: fontSize, weight: .bold, color: style.accent)
            if showDate {
                dateLabel(size: 30, color: style.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var orbitFace: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerSize = min(proxy.size.width * 0.58, proxy.size.height * 0.78)
            let innerSize = outerSize * 0.84

            ZStack {
                TimelineView(.animation) { timeline in
                    orbitRings(innerSize: innerSize,
                               outerSize: outerSize,
                               rotation: orbitRotation(for: timeline.date))
                }
                .position(center)

                VStack(spacing: 12) {
                    timeLabel(size: fontSize * 0.84,
                              weight: .heavy,
                              color: style.accent)
                    if showDate {
                        dateLabel(size: 26, color: .white.opacity(0.80))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .position(center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func orbitRings(innerSize: CGFloat,
                            outerSize: CGFloat,
                            rotation: Double) -> some View {
        ZStack {
            Circle()
                .stroke(style.accent.opacity(0.20), lineWidth: 2)
                .frame(width: innerSize, height: innerSize)

            Circle()
                .stroke(style.secondary.opacity(0.12), lineWidth: 1)
                .frame(width: outerSize, height: outerSize)

            Circle()
                .trim(from: 0.04, to: 0.32)
                .stroke(style.accent.opacity(0.68),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: outerSize, height: outerSize)
                .rotationEffect(.degrees(rotation))

            Circle()
                .trim(from: 0.54, to: 0.82)
                .stroke(style.secondary.opacity(0.52),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: outerSize, height: outerSize)
                .rotationEffect(.degrees(rotation))
        }
    }

    private func orbitRotation(for date: Date) -> Double {
        let components = Calendar.current.dateComponents([.second, .nanosecond], from: date)
        let seconds = Double(components.second ?? 0)
        let fractionalSecond = Double(components.nanosecond ?? 0) / 1_000_000_000
        return (seconds + fractionalSecond) * 6
    }

    private var horizonFace: some View {
        ZStack {
            horizonGlowLine(width: isCompact ? 500 : 720)
                .offset(y: horizonLineOffset)

            VStack(spacing: 14) {
                timeLabel(size: fontSize * 0.78, weight: .black, color: .white)

                if showDate {
                    dateLabel(size: isCompact ? 23 : 27, color: .white.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 34)
    }

    private var horizonLineOffset: CGFloat {
        if showDate {
            isCompact ? 118 : 148
        } else {
            isCompact ? 82 : 102
        }
    }

    private var focusFace: some View {
        ZStack {
            HStack(spacing: isCompact ? 260 : 360) {
                focusDivider
                focusDivider
            }

            VStack(spacing: 14) {
                timeLabel(size: fontSize * 0.86, weight: .semibold, color: style.accent)
                if showDate {
                    dateLabel(size: isCompact ? 22 : 27, color: .white.opacity(0.72))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
    }

    private func horizonGlowLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [
                .clear,
                style.secondary.opacity(0.82),
                style.accent.opacity(0.90),
                style.secondary.opacity(0.82),
                .clear
            ], startPoint: .leading, endPoint: .trailing))
            .frame(width: width, height: 3)
            .blur(radius: 0.3)
    }

    private var focusDivider: some View {
        Rectangle()
            .fill(LinearGradient(colors: [
                .clear,
                style.secondary.opacity(0.42),
                style.accent.opacity(0.62),
                .clear
            ], startPoint: .top, endPoint: .bottom))
            .frame(width: 2, height: isCompact ? 130 : 176)
    }

    private var zenithFace: some View {
        ZStack {
            HStack(spacing: isCompact ? 38 : 64) {
                zenithRail(height: isCompact ? 150 : 196, flipped: false)

                VStack(spacing: 12) {
                    timeLabel(size: fontSize * 0.82, weight: .heavy, color: style.accent)
                        .shadow(color: style.secondary.opacity(0.36), radius: 18, x: 0, y: 0)

                    if showDate {
                        dateLabel(size: isCompact ? 23 : 28, color: .white.opacity(0.74))
                    }
                }
                .frame(minWidth: isCompact ? 430 : 560)

                zenithRail(height: isCompact ? 150 : 196, flipped: true)
            }

            Rectangle()
                .fill(LinearGradient(colors: [
                    .clear,
                    style.secondary.opacity(0.42),
                    .clear
                ], startPoint: .leading, endPoint: .trailing))
                .frame(width: isCompact ? 540 : 740, height: 2)
                .offset(y: isCompact ? 74 : 98)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 38)
    }

    private func zenithRail(height: CGFloat, flipped: Bool) -> some View {
        VStack(spacing: 9) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(LinearGradient(colors: [
                        style.secondary.opacity(0.15),
                        style.accent.opacity(0.56),
                        style.secondary.opacity(0.15)
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(width: CGFloat(2 + index % 2), height: height / CGFloat(8 - index))
            }
        }
        .frame(width: 22, height: height)
        .scaleEffect(x: flipped ? -1 : 1, y: 1)
        .opacity(0.92)
    }

    private func timeLabel(size: CGFloat, weight: Font.Weight, color: Color) -> some View {
        Text(timeText)
            .font(.system(size: size,
                          weight: weight,
                          design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.45)
            .lineLimit(1)
            .foregroundColor(color)
            .accessibilityIdentifier("standbyClockTime")
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
