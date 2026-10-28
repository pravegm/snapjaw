import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit bog underneath (full-bleed, aspect-filled), the SwiftUI screens on top, the pose cards
/// above all (Swoop's structure, landscape play).
///
/// Safe areas: the content ignores the safe area (the scene is full-bleed), so the insets are read from an outer
/// GeometryReader that does NOT ignore it and from the key window (whichever is larger), and handed to every screen in
/// `AppCanvas.insets`. The hinge is read here, once, for the whole app (HingeReader → GameController.hingeSample →
/// HingeTrapSource).
struct RootView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    @ObservedObject var settings: SettingsStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var launched = false
    @State private var windowInsets = EdgeInsets()
    /// The `.division` reserved region (iOS 27.1: present while the Duo is partly folded) has been seen.
    @State private var divisionSeen = false
    /// A phone's pose card shows only if the canvas is still portrait 0.6 s later (the landscape mask usually turns
    /// the UI first, so it never flashes).
    @State private var phoneCardReady = false

    static let phoneCardDelay: Double = 0.6

    var body: some View {
        GeometryReader { safeGeo in
            let safe = safeGeo.safeAreaInsets
            GeometryReader { geo in
                let division = Self.activeDivision(in: geo)
                content(canvas: geo.size, safe: merged(safe, windowInsets))
                    .onChange(of: division ?? .zero) { _, frame in
                        logFold(frame)
                        if frame != .zero && !divisionSeen {
                            divisionSeen = true
                            handleCanvas(geo.size)
                        }
                    }
            }
            .ignoresSafeArea()
        }
        .background(SnapTheme.bogDeep.ignoresSafeArea())
        .modifier(HingeReader(onUpdate: { angle, time in
            controller.hingeSample(angle: angle, time: time)
        }, onUnavailable: {
            controller.hingeUnavailable()
        }))
        .onChange(of: scenePhase) { _, phase in
            controller.setScenePhase(phase)
            if phase == .active { refreshWindowInsets() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            refreshWindowInsets()
        }
        .onChange(of: systemReduceMotion) { _, on in controller.setSystemReduceMotion(on) }
        .onChange(of: settings.reduceMotion) { _, _ in controller.refreshMotion() }
        .onChange(of: settings.hudOnLeft) { _, _ in controller.refreshLayout() }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private func content(canvas: CGSize, safe: EdgeInsets) -> some View {
        let pose = currentPose(canvas)
        let fold = currentFold(canvas)
        ZStack {
            SnapTheme.bogDeep
            // The bog is live behind Home too (an attract session the hinge can chomp).
            gameLayer(canvas, visible: pose == .play && (controller.route.isPlay || controller.route == .home))
            switch pose {
            case .play:
                let layout = ScreenLayout.make(viewSize: canvas, hasFold: fold, hudOnLeft: controller.hudOnLeft)
                screenLayer(AppCanvas(size: canvas, insets: safe, layout: layout))
            case .pose:
                if phoneCardReady || isDuoLike(canvas) {
                    PoseCard(insets: safe, isDuo: isDuoLike(canvas), reduceMotion: controller.reduceMotion)
                        .transition(.opacity)
                } else {
                    SnapBackdrop()
                }
            case .cover:
                CoverCard(controller: controller, store: store, insets: safe)
                    .transition(.opacity)
            }
            if let toast = controller.toast {
                Text(toast)
                    .font(SnapType.body(true))
                    .foregroundStyle(SnapTheme.cream)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(SnapTheme.surfaceRaised))
                    .overlay(Capsule().stroke(SnapTheme.lime.opacity(0.3), lineWidth: 1))
                    .position(x: canvas.width / 2, y: max(safe.top, 12) + 40)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if controller.showsIcon {
                iconLayer(canvas)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .animation(SnapTheme.settle(controller.reduceMotion), value: pose)
        .onAppear {
            refreshWindowInsets()
            handleCanvas(canvas)
            launchOnce()
        }
        .onChange(of: canvas) { _, newSize in
            refreshWindowInsets()
            handleCanvas(newSize)
        }
        .onChange(of: controller.hingeSeen) { _, _ in handleCanvas(canvas) }
        .onChange(of: controller.isShut) { _, _ in handleCanvas(canvas) }
        .onChange(of: controller.forcedPose) { _, _ in handleCanvas(canvas) }
        .task(id: pose == .pose) {
            phoneCardReady = false
            guard pose == .pose else { return }
            try? await Task.sleep(nanoseconds: UInt64(Self.phoneCardDelay * 1_000_000_000))
            if !Task.isCancelled { phoneCardReady = true }
        }
    }

    // MARK: - Pose and canvas

    private func isDuoLike(_ canvas: CGSize) -> Bool {
        controller.hingeSeen || AppRules.looksLikeDuoInner(canvas) || controller.forcedPose != nil
    }

    private func currentPose(_ canvas: CGSize) -> AppPose {
        if let forced = controller.forcedPose { return forced }
        return AppRules.pose(canvas: canvas, hingeSeen: controller.hingeSeen, isShut: controller.isShut)
    }

    private func currentFold(_ canvas: CGSize) -> Bool {
        AppRules.hasFold(canvas: canvas, hingeSeen: controller.hingeSeen, demoFold: controller.demoFold,
                         divisionSeen: divisionSeen)
    }

    private func handleCanvas(_ canvas: CGSize) {
        guard canvas.width > 1, canvas.height > 1 else { return }
        let pose = currentPose(canvas)
        controller.setPose(pose)
        if pose == .pose && controller.forcedPose == nil && !isDuoLike(canvas) {
            // A phone held upright (landscape-only mask): ask iOS to turn the interface now.
            OrientationLock.requestLandscape()
        }
        if pose == .play {
            controller.updateCanvas(canvas, hasFold: currentFold(canvas))
        } else if controller.scene == nil {
            // The scene is built for the screen as it will be held (landscape), so CI's frames and the first run
            // never wait on a rotation.
            let w = max(canvas.width, canvas.height)
            let h = min(canvas.width, canvas.height)
            controller.updateCanvas(CGSize(width: w, height: h), hasFold: false)
        }
    }

    private func merged(_ a: EdgeInsets, _ b: EdgeInsets) -> EdgeInsets {
        EdgeInsets(top: max(a.top, b.top), leading: max(a.leading, b.leading),
                   bottom: max(a.bottom, b.bottom), trailing: max(a.trailing, b.trailing))
    }

    private func refreshWindowInsets() {
        let read = OrientationLock.windowSafeArea()
        if read != windowInsets { windowInsets = read }
        // The window settles its insets a beat after a rotation or a display handover.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let later = OrientationLock.windowSafeArea()
            if later != windowInsets { windowInsets = later }
        }
    }

    /// The active fold (`.division` reserved region, iOS 27.1): present only while the Duo is partly folded.
    private static func activeDivision(in proxy: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).first?.frame
        }
        return nil
    }

    private func logFold(_ frame: CGRect) {
        if frame == .zero {
            AppTrace.t("SNAP-T fold inactive")
        } else {
            AppTrace.t(String(format: "SNAP-T fold active %.0f,%.0f %.0fx%.0f", frame.minX, frame.minY,
                              frame.width, frame.height))
        }
    }

    private func launchOnce() {
        guard !launched else { return }
        launched = true
        controller.setSystemReduceMotion(systemReduceMotion)
        OrientationLock.refreshSupportedOrientations()
        controller.launch()
    }

    // MARK: - Layers

    /// The scene renders only while a run or Home is on screen (real runs; CI's demo launches always render: they
    /// wait for `SNAP-T frame 120`), and holds still on a demo event freeze. The closing pause stops it too (a half-shut
    /// Duo saves its battery); the pause lifts from the hinge reports, not from frames (QA-1 #1).
    private func sceneIdle(visible: Bool) -> Bool {
        if controller.sceneHeld { return true }
        guard !controller.isDemo else { return false }
        return !visible || controller.isMenuOpen || controller.isClosingPaused
    }

    @ViewBuilder
    private func gameLayer(_ canvas: CGSize, visible: Bool) -> some View {
        if let scene = controller.scene {
            SpriteView(scene: scene, isPaused: sceneIdle(visible: visible),
                       preferredFramesPerSecond: controller.route == .home ? 60 : 120)
                .id(controller.sceneGeneration)
                .frame(width: canvas.width, height: canvas.height)
                .opacity(visible ? 1 : 0.001)
                .allowsHitTesting(visible)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func screenLayer(_ info: AppCanvas) -> some View {
        ZStack {
            switch controller.route {
            case .home:
                HomeView(controller: controller, store: store, info: info)
                    .transition(.opacity)
            case .playing, .lesson:
                PlayLayer(controller: controller, hud: controller.hud, info: info)
                    .transition(.opacity)
            case .results:
                if let summary = controller.summary {
                    ResultsView(controller: controller, summary: summary, info: info)
                        .transition(SnapTheme.pageTransition(controller.reduceMotion))
                }
            case .book:
                BugBookView(controller: controller, store: store, info: info)
                    .transition(SnapTheme.pageTransition(controller.reduceMotion))
            case .settings:
                SettingsView(controller: controller, settings: settings, store: store, info: info)
                    .transition(SnapTheme.pageTransition(controller.reduceMotion))
            case .daily:
                DailyView(controller: controller, store: store, info: info)
                    .transition(SnapTheme.pageTransition(controller.reduceMotion))
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .animation(SnapTheme.settle(controller.reduceMotion), value: controller.route)
    }

    @ViewBuilder
    private func iconLayer(_ canvas: CGSize) -> some View {
        let side = min(canvas.width, canvas.height)
        ZStack {
            Color.black
            AppIconArt()
                .frame(width: side, height: side)
        }
        .frame(width: canvas.width, height: canvas.height)
        .onAppear { IconExport.render() }
    }
}
