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
    @State private var offset = CGSize.zero
    @State private var offsetStep = 0
    @State private var isScreenOff = false      // 00:00-06:00 时间段黑屏
    @State private var isUserPresent = true     // 前置摄像头检测用户存在
    @State private var faceStyleIndex = 0
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
                                     driftOffset: offset)
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
    }
    
    private var currentFaceStyle: StandbyFaceStyle {
        let styles = StandbyFaceStyle.allCases
        return styles[faceStyleIndex % styles.count]
    }

    private var standbyBackground: some View {
        Color.black
    }
    
    private func updateScreenOff() {
        isScreenOff = !ProcessInfo.processInfo.environment.keys.contains("STANDBY_DISABLE_NIGHT_HIDE")
            && schedule.shouldHideDisplay(at: Date())
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    private func updateUserPresence(_ present: Bool) {
        if present && !isUserPresent {
            withAnimation(.easeInOut(duration: 0.45)) {
                faceStyleIndex = StandbyFaceStyle.index(after: faceStyleIndex)
            }
        }

        isUserPresent = present
    }
}

// MARK: - 大号时钟（带秒）

enum StandbyFaceStyle: CaseIterable {
    case classic
    case orbit
    case horizon
    case focus

    static func index(after index: Int) -> Int {
        (index + 1) % allCases.count
    }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .orbit: "Orbit"
        case .horizon: "Horizon"
        case .focus: "Focus"
        }
    }

    var accent: Color {
        switch self {
        case .classic: .white
        case .orbit: Color(red: 0.53, green: 0.90, blue: 1.0)
        case .horizon: Color(red: 1.0, green: 0.72, blue: 0.36)
        case .focus: Color(red: 0.66, green: 1.0, blue: 0.68)
        }
    }

    var secondary: Color {
        switch self {
        case .classic: Color.white.opacity(0.72)
        case .orbit: Color(red: 0.72, green: 0.78, blue: 1.0)
        case .horizon: Color(red: 1.0, green: 0.44, blue: 0.56)
        case .focus: Color(red: 0.70, green: 0.88, blue: 1.0)
        }
    }
}

struct BigClockView : View {
    var fontSize: CGFloat = 140
    var style: StandbyFaceStyle = .classic
    var isCompact: Bool = false
    var driftOffset: CGSize = .zero
    
    @State private var now = Date()
    private let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()
    
    // HH:mm:ss 格式
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
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
                }
            }
            .offset(driftOffset)
        }
        .onReceive(timer) { value in
            now = value
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var timeText: String {
        Self.timeFormatter.string(from: now)
    }

    private var dateText: String {
        Self.dateFormatter.string(from: now)
    }

    private var background: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                moodGradient
                centerWash
                notchEdgeShade
                verticalEdgeShade
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
                Color(red: 0.02, green: 0.03, blue: 0.10),
                Color(red: 0.03, green: 0.22, blue: 0.27),
                Color(red: 0.09, green: 0.05, blue: 0.17),
                Color.black
            ]
        case .horizon:
            [
                Color(red: 0.04, green: 0.02, blue: 0.06),
                Color(red: 0.22, green: 0.07, blue: 0.13),
                Color(red: 0.44, green: 0.17, blue: 0.11),
                Color.black
            ]
        case .focus:
            [
                Color(red: 0.01, green: 0.04, blue: 0.04),
                Color(red: 0.03, green: 0.16, blue: 0.13),
                Color(red: 0.02, green: 0.06, blue: 0.10),
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
            dateLabel(size: 30, color: style.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var orbitFace: some View {
        ZStack {
            orbitRings
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(spacing: 10) {
                Text(style.name.uppercased())
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(style.secondary.opacity(0.9))
                timeLabel(size: fontSize * 0.84, weight: .heavy, color: style.accent)
                dateLabel(size: 26, color: .white.opacity(0.80))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
        .offset(y: isCompact ? -46 : -58)
    }

    private var orbitRings: some View {
        let innerSize: CGFloat = isCompact ? 270 : 400
        let outerSize: CGFloat = isCompact ? 318 : 474
        let rotation = Double(Calendar.current.component(.second, from: now)) * 6

        return ZStack {
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

    private var horizonFace: some View {
        VStack(spacing: 18) {
            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 20) {
                timeLabel(size: fontSize * 0.76, weight: .black, color: .white)

                VStack(alignment: .leading, spacing: 8) {
                    Text(style.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(style.accent)
                    dateLabel(size: 24, color: .white.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(LinearGradient(colors: [
                    .clear,
                    style.accent.opacity(0.86),
                    style.secondary.opacity(0.76),
                    .clear
                ], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
                .padding(.horizontal, isCompact ? 44 : 110)

            Spacer()
        }
        .padding(.horizontal, 34)
    }

    private var focusFace: some View {
        HStack(spacing: isCompact ? 20 : 38) {
            VStack(alignment: .leading, spacing: 14) {
                Text("NOW")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(style.secondary)
                dateLabel(size: isCompact ? 22 : 28, color: .white.opacity(0.72))
            }
            .frame(width: isCompact ? 190 : 250, alignment: .leading)

            Divider()
                .frame(height: isCompact ? 135 : 180)
                .overlay(style.accent.opacity(0.55))

            timeLabel(size: fontSize * 0.84, weight: .semibold, color: style.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
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
