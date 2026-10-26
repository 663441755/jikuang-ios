import SwiftUI
import CoreMotion
import CoreLocation
import AVFoundation
import CoreImage.CIFilterBuiltins
import Security

// MARK: - 通用壳

struct ToolPage<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.t1)
                                .frame(width: 32, height: 32)
                                .background(Theme.surf)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.t1)
                        Spacer()
                        Color.clear.frame(width: 32, height: 32)
                    }

                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 触感反馈

struct HapticsToolView: View {
    var body: some View {
        ToolPage(title: "触感反馈") {
            GroupLabel(text: "冲击反馈")
            VStack(spacing: 0) {
                hapticRow("轻触 · Light") { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                hapticRow("中触 · Medium") { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                hapticRow("重触 · Heavy") { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
                hapticRow("软性 · Soft") { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                hapticRow("硬性 · Rigid") { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
            }
            .card()

            GroupLabel(text: "通知反馈")
            VStack(spacing: 0) {
                hapticRow("成功 · Success") { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                hapticRow("警告 · Warning") { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
                hapticRow("失败 · Error") { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            }
            .card()

            GroupLabel(text: "选择反馈")
            VStack(spacing: 0) {
                hapticRow("滴答 · Selection") { UISelectionFeedbackGenerator().selectionChanged() }
            }
            .card()
        }
    }

    private func hapticRow(_ name: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Text(name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Theme.t1)
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.purple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 多点触控

struct TouchToolView: View {
    var body: some View {
        ToolPage(title: "多点触控") {
            TouchTraceView()
                .frame(height: 420)
                .clipShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(Theme.line, lineWidth: 1)
                )
            Text("按下并滑动，圈点为触点轨迹，可测触控死区")
                .font(.system(size: 10))
                .foregroundColor(Theme.t3)
                .frame(maxWidth: .infinity)
        }
    }
}

struct TouchTraceView: UIViewRepresentable {
    func makeUIView(context: Context) -> TraceUIView { TraceUIView() }
    func updateUIView(_ view: TraceUIView, context: Context) {}
}

final class TraceUIView: UIView {
    private var traces: [[CGPoint]] = []
    private var touchCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.06, green: 0.08, blue: 0.1, alpha: 1)
        isMultipleTouchEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    private var touchMap: [ObjectIdentifier: Int] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { appendPoint(t.location(in: self), touch: t) }
        touchCount = max(touchCount, event?.allTouches?.count ?? 0)
        setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { appendPoint(t.location(in: self), touch: t) }
        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if event?.allTouches?.filter({ $0.phase != .ended && $0.phase != .cancelled }).isEmpty == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.traces.removeAll()
                self?.touchMap.removeAll()
                self?.touchCount = 0
                self?.setNeedsDisplay()
            }
        }
        setNeedsDisplay()
    }

    private func appendPoint(_ p: CGPoint, touch: UITouch) {
        let key = ObjectIdentifier(touch)
        if let idx = touchMap[key], traces.indices.contains(idx) {
            traces[idx].append(p)
        } else {
            traces.append([p])
            touchMap[key] = traces.count - 1
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        for (i, trace) in traces.enumerated() where trace.count > 1 {
            let hue = CGFloat(i) / 6
            ctx.setStrokeColor(UIColor(hue: hue, saturation: 0.65, brightness: 1, alpha: 0.9).cgColor)
            ctx.setLineWidth(2.5)
            ctx.beginPath()
            ctx.addLines(between: trace)
            ctx.strokePath()
        }
        for trace in traces {
            if let last = trace.last {
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8))
            }
        }
        let text = "触点数 \(touchCount) · 轨迹 \(traces.count)" as NSString
        (text as NSString).draw(
            at: CGPoint(x: 14, y: 14),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor(white: 1, alpha: 0.75)
            ]
        )
    }
}

// MARK: - 位置服务（指南针 / GPS / 足迹共用）

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var headingAccuracy: Double = 0
    @Published var location: CLLocation?
    @Published var track: [CLLocation] = []
    @Published var error: String?
    @Published var authorized = false

    var recordTrack = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1
    }

    func start(heading: Bool, track: Bool) {
        recordTrack = track
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if heading { manager.startUpdatingHeading() }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorized = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc
        if recordTrack { track.append(loc) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        heading = value
        headingAccuracy = newHeading.headingAccuracy
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
    }

    var trackDistance: Double {
        var total: Double = 0
        for i in 1..<track.count {
            total += track[i].distance(from: track[i - 1])
        }
        return total
    }
}

// MARK: - 指南针

struct CompassToolView: View {
    @StateObject private var service = LocationService()

    var body: some View {
        ToolPage(title: "指南针") {
            VStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 1).frame(width: 200, height: 200)
                    Circle().stroke(Theme.line.opacity(0.5), lineWidth: 1).frame(width: 150, height: 150)
                    ForEach(0..<8, id: \.self) { i in
                        Rectangle()
                            .fill(Theme.t3.opacity(0.6))
                            .frame(width: 1.5, height: i % 2 == 0 ? 12 : 7)
                            .offset(y: -92)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(Theme.pink)
                        .rotationEffect(.degrees(-service.heading))
                    Text("\(Int(service.heading < 0 ? service.heading + 360 : service.heading))°")
                        .font(Px.nb(30))
                        .foregroundColor(Theme.t1)
                        .monospacedDigit()
                        .offset(y: 100)
                }
                .frame(height: 240)

                card(label: "磁北方向", value: String(format: "%.1f°", service.heading))
                card(label: "精度", value: service.headingAccuracy > 0 ? String(format: "±%.0f°", service.headingAccuracy) : "--")
                if let error = service.error {
                    Text(error).font(.system(size: 10)).foregroundColor(Theme.orange)
                }
                if !service.authorized {
                    Text("需要定位权限用于磁北校准：设置 → 机况 → 位置 → 允许")
                        .font(.system(size: 10)).foregroundColor(Theme.t3)
                }
            }
        }
        .onAppear { service.start(heading: true, track: false) }
        .onDisappear { service.stop() }
    }

    private func card(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundColor(Theme.t3)
            Spacer()
            Text(value).font(Px.n(13)).foregroundColor(Theme.t1).monospacedDigit()
        }
        .padding(13)
        .card(radius: 14)
    }
}

// MARK: - GPS

struct GpsToolView: View {
    @StateObject private var service = LocationService()

    var body: some View {
        ToolPage(title: "GPS 定位") {
            VStack(spacing: 10) {
                GroupLabel(text: "坐标")
                VStack(spacing: 0) {
                    gpsRow("纬度", value: service.location.map { String(format: "%.6f", $0.coordinate.latitude) } ?? "--")
                    Divider().overlay(Theme.line).padding(.leading, 14)
                    gpsRow("经度", value: service.location.map { String(format: "%.6f", $0.coordinate.longitude) } ?? "--")
                    Divider().overlay(Theme.line).padding(.leading, 14)
                    gpsRow("海拔", value: service.location.map { String(format: "%.1f m", $0.altitude) } ?? "--")
                    Divider().overlay(Theme.line).padding(.leading, 14)
                    gpsRow("速度", value: service.location.map { String(format: "%.1f m/s", max($0.speed, 0)) } ?? "--")
                    Divider().overlay(Theme.line).padding(.leading, 14)
                    gpsRow("精度", value: service.location.map { String(format: "±%.0f m", $0.horizontalAccuracy) } ?? "--")
                }
                .card()

                if let error = service.error {
                    Text(error).font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
                }
                Text("定位在室内可能漂移或不可用，建议到窗边或室外测试")
                    .font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)
            }
        }
        .onAppear { service.start(heading: false, track: false) }
        .onDisappear { service.stop() }
    }

    private func gpsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11.5)).foregroundColor(Theme.t3)
            Spacer()
            Text(value).font(Px.n(13)).foregroundColor(Theme.t1).monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - 足迹记录

struct FootprintToolView: View {
    @StateObject private var service = LocationService()
    @State private var recording = false

    var body: some View {
        ToolPage(title: "记录足迹") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    miniCard(label: "轨迹点", value: "\(service.track.count)", tint: Theme.blue)
                    miniCard(label: "累计距离", value: distanceText(service.trackDistance), tint: Theme.green)
                }

                Button {
                    recording.toggle()
                    if recording {
                        service.track.removeAll()
                        service.start(heading: false, track: true)
                    } else {
                        service.stop()
                    }
                } label: {
                    Text(recording ? "停止记录" : "开始记录")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(recording ? Theme.pink : Theme.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background((recording ? Theme.pink : Theme.green).opacity(0.12))
                        .clipShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(recording ? "记录中，移动后此处会累计距离" : "开始后随移动累计距离与轨迹点数")
                    .font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)

                if let error = service.error {
                    Text(error).font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
                }
            }
        }
        .onDisappear { service.stop() }
    }

    private func distanceText(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.2f km", meters / 1000) : String(format: "%.1f m", meters)
    }

    private func miniCard(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9.5)).foregroundColor(Theme.t3)
            Text(value).font(Px.nb(17)).foregroundColor(tint).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .card(radius: 14)
    }
}

// MARK: - 运动传感器（陀螺仪 / 磁力计 / 气压 / 海拔共用）

final class MotionService: ObservableObject {
    @Published var gyro = (x: 0.0, y: 0.0, z: 0.0)
    @Published var accel = (x: 0.0, y: 0.0, z: 0.0)
    @Published var mag = (x: 0.0, y: 0.0, z: 0.0)
    @Published var pressure: Double = 0          // kPa
    @Published var relativeAltitude: Double = 0  // m
    @Published var unavailable = false

    private let manager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var active = false

    func start(kind: String) {
        active = true
        switch kind {
        case "gyro", "accel":
            guard manager.isDeviceMotionAvailable else { unavailable = true; return }
            manager.deviceMotionUpdateInterval = 1.0 / 20.0
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let m = motion, let self, self.active else { return }
                self.gyro = (m.rotationRate.x, m.rotationRate.y, m.rotationRate.z)
                self.accel = (m.userAcceleration.x, m.userAcceleration.y, m.userAcceleration.z)
            }
        case "mag":
            guard manager.isMagnetometerAvailable else { unavailable = true; return }
            manager.magnetometerUpdateInterval = 1.0 / 10.0
            manager.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                guard let d = data, let self, self.active else { return }
                self.mag = (d.magneticField.x, d.magneticField.y, d.magneticField.z)
            }
        case "pressure", "altitude":
            guard CMAltimeter.isRelativeAltitudeAvailable() else { unavailable = true; return }
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let d = data, let self, self.active else { return }
                self.pressure = d.pressure.doubleValue
                self.relativeAltitude = d.relativeAltitude.doubleValue
            }
        default:
            break
        }
    }

    func stop() {
        active = false
        manager.stopDeviceMotionUpdates()
        manager.stopMagnetometerUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
}

struct GyroToolView: View {
    @StateObject private var motion = MotionService()

    var body: some View {
        ToolPage(title: "陀螺仪") {
            sensorBody(
                rows: [
                    ("X 轴角速度", motion.gyro.x, "rad/s"),
                    ("Y 轴角速度", motion.gyro.y, "rad/s"),
                    ("Z 轴角速度", motion.gyro.z, "rad/s")
                ],
                bars: [motion.gyro.x, motion.gyro.y, motion.gyro.z],
                note: "转动手机，数值应随之变化"
            )
        }
        .onAppear { motion.start(kind: "gyro") }
        .onDisappear { motion.stop() }
    }

    private func sensorBody(rows: [(String, Double, String)], bars: [Double], note: String) -> some View {
        VStack(spacing: 10) {
            GroupLabel(text: "实时读数")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row.0).font(.system(size: 11.5)).foregroundColor(Theme.t3)
                        Spacer()
                        Text(String(format: "%+.3f %@", row.1, row.2))
                            .font(Px.n(13))
                            .foregroundColor(Theme.t1)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if i < rows.count - 1 {
                        Divider().overlay(Theme.line).padding(.leading, 14)
                    }
                }
            }
            .card()

            GroupLabel(text: "幅度")
            VStack(spacing: 8) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.07))
                            Rectangle()
                                .fill(Theme.purple)
                                .frame(width: min(1, abs(v) / 2.0) * geo.size.width)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(13)
            .card()

            if motion.unavailable {
                Text("本机此传感器不可用").font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
            }
            Text(note).font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)
        }
    }
}

struct MagnetToolView: View {
    @StateObject private var motion = MotionService()

    var body: some View {
        ToolPage(title: "磁力计") {
            let magnitude = (motion.mag.x * motion.mag.x + motion.mag.y * motion.mag.y + motion.mag.z * motion.mag.z).squareRoot()
            sensorBody(
                rows: [
                    ("X", motion.mag.x, "μT"),
                    ("Y", motion.mag.y, "μT"),
                    ("Z", motion.mag.z, "μT"),
                    ("合场强", magnitude, "μT")
                ],
                bars: [motion.mag.x / 100, motion.mag.y / 100, motion.mag.z / 100],
                note: "拿磁铁靠近手机，合场强应明显上升（地球磁场约 25~65 μT）"
            )
        }
        .onAppear { motion.start(kind: "mag") }
        .onDisappear { motion.stop() }
    }

    private func sensorBody(rows: [(String, Double, String)], bars: [Double], note: String) -> some View {
        GyroHelper.sensorBody(motion: motion, rows: rows, bars: bars, note: note, tint: Theme.orange)
    }
}

struct PressureToolView: View {
    @StateObject private var motion = MotionService()

    var body: some View {
        ToolPage(title: "气压计") {
            VStack(spacing: 10) {
                GroupLabel(text: "实时气压")
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", motion.pressure))
                        .font(Px.nb(42))
                        .foregroundColor(Theme.green)
                        .monospacedDigit()
                    Text("kPa（≈ \(String(format: "%.0f", motion.pressure * 10)) hPa）")
                        .font(.system(size: 10.5)).foregroundColor(Theme.t3).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .card()

                Text("标准大气压 101.325 kPa；上楼/乘电梯时数值会下降")
                    .font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)

                if motion.unavailable {
                    Text("本机气压计不可用").font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { motion.start(kind: "pressure") }
        .onDisappear { motion.stop() }
    }
}

struct AltitudeToolView: View {
    @StateObject private var motion = MotionService()
    @State private var baseAltitude: Double?

    var body: some View {
        ToolPage(title: "海拔计") {
            VStack(spacing: 10) {
                GroupLabel(text: "相对海拔变化")
                VStack(spacing: 4) {
                    Text(String(format: "%+.1f m", motion.relativeAltitude - (baseAltitude ?? motion.relativeAltitude)))
                        .font(Px.nb(42))
                        .foregroundColor(Theme.amber)
                        .monospacedDigit()
                    Text("气压推算 · 相对启动点")
                        .font(.system(size: 10.5)).foregroundColor(Theme.t3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .card()

                HStack(spacing: 10) {
                    Button {
                        baseAltitude = motion.relativeAltitude
                    } label: {
                        Text("归零")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Theme.blue.opacity(0.12))
                            .clipShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("电梯是最佳测试场景：上行数值增大，下行减小")
                    .font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)

                if motion.unavailable {
                    Text("本机气压计不可用").font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { motion.start(kind: "altitude") }
        .onDisappear { motion.stop() }
    }
}

// 传感器壳的公共实现（避免重复代码）
enum GyroHelper {
    @MainActor
    static func sensorBody(motion: MotionService, rows: [(String, Double, String)], bars: [Double], note: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            GroupLabel(text: "实时读数")
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row.0).font(.system(size: 11.5)).foregroundColor(Theme.t3)
                        Spacer()
                        Text(String(format: "%+.2f %@", row.1, row.2))
                            .font(Px.n(13))
                            .foregroundColor(Theme.t1)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if i < rows.count - 1 {
                        Divider().overlay(Theme.line).padding(.leading, 14)
                    }
                }
            }
            .card()

            GroupLabel(text: "幅度")
            VStack(spacing: 8) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.07))
                            Rectangle()
                                .fill(tint)
                                .frame(width: min(1, abs(CGFloat(v))) * geo.size.width)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(13)
            .card()

            if motion.unavailable {
                Text("本机此传感器不可用").font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
            }
            Text(note).font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 距离感应

struct ProximityToolView: View {
    @StateObject private var model = ProximityModel()

    var body: some View {
        ToolPage(title: "距离感应") {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(model.near ? Theme.green.opacity(0.15) : Theme.t3.opacity(0.1))
                        .frame(width: 130, height: 130)
                    Image(systemName: model.near ? "person.fill" : "wave.3.right")
                        .font(.system(size: 42))
                        .foregroundColor(model.near ? Theme.green : Theme.t2)
                }
                .frame(height: 160)

                Text(model.near ? "有物体靠近" : "等待靠近")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(model.near ? Theme.green : Theme.t2)

                Text("用手掌挡住手机顶部听筒区域，图标应切换；同时屏幕会自动熄灭（系统行为）")
                    .font(.system(size: 10)).foregroundColor(Theme.t3)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)

                if !model.supported {
                    Text("本机不支持接近传感器").font(.system(size: 10)).foregroundColor(Theme.orange).frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

final class ProximityModel: ObservableObject {
    @Published var near = false
    @Published var supported = true
    private var observer: NSObjectProtocol?

    func start() {
        supported = UIDevice.current.isProximityMonitoringEnabled
        guard supported else { return }
        UIDevice.current.isProximityMonitoringEnabled = true
        near = UIDevice.current.proximityState
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.near = UIDevice.current.proximityState
        }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        UIDevice.current.isProximityMonitoringEnabled = false
    }
}

// MARK: - 屏幕检测（坏点 / 色彩）

struct ScreenToolView: View {
    @State private var index = 0
    private let colors: [Color] = [.red, .green, .blue, .white, .black, .gray, .yellow, .cyan]

    var body: some View {
        ZStack {
            colors[index].ignoresSafeArea()
            VStack {
                HStack {
                    Text("\(index + 1)/\(colors.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(colors[index] == .white || colors[index] == .yellow || colors[index] == .cyan ? .black : .white)
                        .padding(8)
                    Spacer()
                    Button {
                        index = (index + 1) % colors.count
                    } label: {
                        Text("下一屏")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                Spacer()
                Text("全屏查看是否有亮点 / 暗斑 / 色斑，点按切换颜色")
                    .font(.system(size: 10))
                    .foregroundColor(colors[index] == .white ? .black.opacity(0.6) : .white.opacity(0.7))
                    .padding(.bottom, 24)
            }
        }
        .onTapGesture { index = (index + 1) % colors.count }
    }
}

// MARK: - 二维码生成

struct QRToolView: View {
    @State private var text = "https://"
    @State private var image: UIImage?
    @State private var copied = false

    var body: some View {
        ToolPage(title: "二维码生成") {
            VStack(spacing: 12) {
                GroupLabel(text: "内容")
                TextField("输入文字或链接", text: $text)
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.t1)
                    .padding(12)
                    .background(Theme.surf)
                    .clipShape(Rectangle())
                    .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    generate()
                } label: {
                    Text("生成二维码")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.amber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.amber.opacity(0.12))
                        .clipShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let image {
                    GroupLabel(text: "结果")
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .clipShape(Rectangle())

                    Button {
                        UIPasteboard.general.image = image
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                    } label: {
                        Text(copied ? "已复制到相册剪贴板" : "复制图片")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.green)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Theme.green.opacity(0.12))
                            .clipShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { generate() }
    }

    private func generate() {
        guard !text.isEmpty else { image = nil; return }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else {
            image = nil
            return
        }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { image = nil; return }
        image = UIImage(cgImage: cg)
    }
}

// MARK: - 分贝仪

struct DecibelToolView: View {
    @StateObject private var model = DecibelModel()
    @State private var history: [Double] = Array(repeating: 0, count: 48)
    @State private var chartTimer: Timer?

    var body: some View {
        ToolPage(title: "分贝仪") {
            VStack(spacing: 10) {
                GroupLabel(text: "实时声级")
                VStack(spacing: 4) {
                    Text(model.error ?? String(format: "%.0f", model.db))
                        .font(Px.nb(46))
                        .foregroundColor(color)
                        .monospacedDigit()
                    Text(model.error != nil ? "无法启动麦克风" : "dB · 近似声级（未校准）")
                        .font(.system(size: 10.5)).foregroundColor(Theme.t3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .card()

                HStack(spacing: 10) {
                    miniCard(label: "峰值", value: String(format: "%.0f dB", model.peak), tint: Theme.pink)
                    miniCard(label: "平均", value: String(format: "%.0f dB", model.average), tint: Theme.blue)
                }

                if model.error == nil {
                    GeometryReader { geo in
                        Path { p in
                            let step = geo.size.width / CGFloat(history.count - 1)
                            for (i, v) in history.enumerated() {
                                let x = CGFloat(i) * step
                                let y = geo.size.height * (1 - CGFloat(v / 110))
                                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    }
                    .frame(height: 80)
                    .padding(13)
                    .card()
                }

                Text("对着麦克风说话，曲线应起伏；数值未经声级计校准，仅供相对比较")
                    .font(.system(size: 10)).foregroundColor(Theme.t3).frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            model.start()
            chartTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                history.removeFirst()
                history.append(model.db)
            }
        }
        .onDisappear {
            chartTimer?.invalidate()
            chartTimer = nil
            model.stop()
        }
    }

    private var color: Color {
        switch model.db {
        case ..<45: return Theme.green
        case ..<75: return Theme.amber
        default: return Theme.pink
        }
    }

    private func miniCard(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9.5)).foregroundColor(Theme.t3)
            Text(value).font(Px.nb(16)).foregroundColor(tint).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .card(radius: 14)
    }
}

final class DecibelModel: NSObject, ObservableObject {
    @Published var db: Double = 0
    @Published var peak: Double = 0
    @Published var error: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var sum: Double = 0
    private var count: Int = 0

    var average: Double { count > 0 ? sum / Double(count) : 0 }

    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("jikuang-db.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            guard rec.record(forDuration: 3600) else {
                error = "录音启动失败"
                return
            }
            recorder = rec
            timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                guard let self, let r = self.recorder else { return }
                r.updateMeters()
                let value = Double(max(0, min(110, r.averagePower(forChannel: 0) + 100)))
                self.db = value
                self.peak = max(self.peak, value)
                self.sum += value
                self.count += 1
            }
        } catch {
            self.error = "麦克风权限被拒绝或占用"
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - 密码生成

struct PasswordToolView: View {
    @State private var length: Double = 16
    @State private var useUpper = true
    @State private var useDigits = true
    @State private var useSymbols = true
    @State private var password = ""
    @State private var copied = false

    var body: some View {
        ToolPage(title: "密码生成") {
            VStack(spacing: 12) {
                GroupLabel(text: "结果")
                Text(password.isEmpty ? "点击生成" : password)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundColor(password.isEmpty ? Theme.t3 : Theme.t1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .card()

                HStack(spacing: 10) {
                    actionButton("生成", tint: Theme.green) { generate() }
                    actionButton(copied ? "已复制" : "复制", tint: Theme.blue) {
                        guard !password.isEmpty else { return }
                        UIPasteboard.general.string = password
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                    }
                }

                GroupLabel(text: "规则")
                VStack(spacing: 0) {
                    HStack {
                        Text("长度 \(Int(length))").font(.system(size: 12)).foregroundColor(Theme.t1).monospacedDigit()
                        Spacer()
                        Slider(value: $length, in: 8...32, step: 1)
                            .frame(width: 170)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().overlay(Theme.line).padding(.leading, 14)
                    toggleRow("大写字母 A-Z", $useUpper)
                    Divider().overlay(Theme.line).padding(.leading, 14)
                    toggleRow("数字 0-9", $useDigits)
                    Divider().overlay(Theme.line).padding(.leading, 14)
                    toggleRow("符号 !@#$", $useSymbols)
                }
                .card()
            }
        }
        .onAppear { generate() }
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundColor(Theme.t1)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(Theme.amber)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(tint.opacity(0.12))
                .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func generate() {
        var pool = "abcdefghijklmnopqrstuvwxyz"
        if useUpper { pool += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if useDigits { pool += "0123456789" }
        if useSymbols { pool += "!@#$%^&*-_=+?" }
        guard !pool.isEmpty else { password = ""; return }

        var bytes = [UInt8](repeating: 0, count: Int(length))
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if result != errSecSuccess {
            for i in 0..<bytes.count { bytes[i] = UInt8.random(in: 0...255) }
        }
        let chars = Array(pool)
        password = String(bytes.map { chars[Int($0) % chars.count] })
    }
}
