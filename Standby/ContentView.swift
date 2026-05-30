import SwiftUI
import Combine
import AVFoundation

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
    @State private var offset = CGSize.zero
    @State private var offsetStep = 0
    @State private var isScreenOff = false      // 00:00-06:00 时间段黑屏
    @State private var isUserPresent = true     // 前置摄像头检测用户存在
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
                    } else {
                    BigClockView(fontSize: isCompact ? 120 : 160)
                    }
                }
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity,
                       alignment: .center)
                .background(standbyBackground.ignoresSafeArea())
                .offset(offset)
                .onAppear {
                    updateScreenOff()
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
                CameraPresenceView(isUserPresent: $isUserPresent)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)   // 几乎不可见，只用于驱动摄像头
            }
        }
    }
    
    private var standbyBackground: some View {
        Color.black
    }
    
    private func updateScreenOff() {
        isScreenOff = schedule.shouldHideDisplay(at: Date())
    }
}

// MARK: - 大号时钟（带秒）

struct BigClockView : View {
    var fontSize: CGFloat = 140
    
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
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                // 时间：时分秒
                Text(Self.timeFormatter.string(from: now))
                    .font(.system(size: fontSize,
                                  weight: .bold,
                                  design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(standbyAccent)
                
                // 日期 + 星期
                Text(Self.dateFormatter.string(from: now))
                    .font(.system(size: 30,
                                  weight: .bold,
                                  design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(standbyAccent.opacity(0.8))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .onReceive(timer) { value in
            now = value
        }
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

final class CameraPresenceController: UIViewController,
                                      AVCaptureMetadataOutputObjectsDelegate {
    var onPresenceChanged: ((Bool) -> Void)?

    private let session = AVCaptureSession()
    private var lastPresence: Bool = true
    private var pendingOffWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        configureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        // 前置摄像头
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .medium

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self,
                                                      queue: DispatchQueue.main)
            if metadataOutput.availableMetadataObjectTypes.contains(.face) {
                metadataOutput.metadataObjectTypes = [.face]
            }
        }

        session.commitConfiguration()
        session.startRunning()   // 小项目直接主线程启动，简单稳定
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        let hasFace = metadataObjects.contains { $0 is AVMetadataFaceObject }
        
        // 如果状态没变化，直接返回
        if hasFace == lastPresence {
            return
        }
        
        if hasFace {
            // 检测到人脸：取消任何正在等待关闭的任务，立即标记有人
            pendingOffWorkItem?.cancel()
            pendingOffWorkItem = nil
            
            lastPresence = true
            onPresenceChanged?(true)
        } else {
            // 没有人脸：延迟 5 秒再关闭，如果中途重新检测到人脸则取消
            pendingOffWorkItem?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // 再检查一次，如果期间已经有人脸就不再关闭
                if self.lastPresence == false {
                    self.onPresenceChanged?(false)
                }
            }
            pendingOffWorkItem = workItem
            lastPresence = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5,
                                          execute: workItem)
        }
    }
}
