import SwiftUI
import CoreHaptics
import UIKit

@main
struct RumbleTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class HapticsController: ObservableObject {
    @Published var level = 3
    @Published private(set) var isHolding = false
    @Published private(set) var status = "Ready to test"

    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var fallbackTask: Task<Void, Never>?
    private var supportsCoreHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    init() {
        guard supportsCoreHaptics else {
            status = "Using standard iPhone haptics"
            return
        }

        do {
            let newEngine = try CHHapticEngine()
            newEngine.isAutoShutdownEnabled = true
            newEngine.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            try newEngine.start()
            engine = newEngine
            status = "Core Haptics ready"
        } catch {
            status = "Standard haptics fallback"
        }
    }

    func pulse() {
        stopHolding()
        let strength = Float(level) / 5.0

        guard supportsCoreHaptics, let engine else {
            let style: UIImpactFeedbackGenerator.FeedbackStyle =
                level <= 1 ? .soft : level <= 2 ? .light : level <= 3 ? .medium : level <= 4 ? .heavy : .rigid
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(strength))
            status = "Pulse sent · Level \(level)"
            return
        }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: strength),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: min(1, 0.25 + strength * 0.7))
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
            status = "Pulse sent · Level \(level)"
        } catch {
            status = "Couldn't play haptic: \(error.localizedDescription)"
        }
    }

    func startHolding() {
        guard !isHolding else { return }
        isHolding = true
        status = "Vibrating · Level \(level)"

        if supportsCoreHaptics, let engine {
            do {
                try engine.start()
                let strength = Float(level) / 5.0
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: strength),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: min(1, 0.25 + strength * 0.7))
                    ],
                    relativeTime: 0,
                    duration: 30
                )
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                continuousPlayer = player
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                status = "Using standard haptics fallback"
            }
        }

        // UIKit does not expose continuous vibration. Repeated impacts approximate a hold.
        fallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isHolding else { break }
                let style: UIImpactFeedbackGenerator.FeedbackStyle =
                    self.level <= 1 ? .soft : self.level <= 2 ? .light : self.level <= 3 ? .medium : self.level <= 4 ? .heavy : .rigid
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred(intensity: CGFloat(self.level) / 5.0)
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    func stopHolding() {
        guard isHolding else { return }
        isHolding = false
        fallbackTask?.cancel()
        fallbackTask = nil
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
        status = "Ready to test"
    }

    func setLevel(_ newLevel: Int) {
        level = newLevel
        if isHolding {
            stopHolding()
        }
    }
}

struct ContentView: View {
    @StateObject private var haptics = HapticsController()

    private let red = Color(red: 1.0, green: 0.22, blue: 0.27)

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.055, blue: 0.075).ignoresSafeArea()

            VStack(spacing: 26) {
                header

                VStack(spacing: 10) {
                    Text("INTENSITY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.45))

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(haptics.level)")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("/ 5")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                haptics.setLevel(value)
                            } label: {
                                VStack(spacing: 9) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(value <= haptics.level ? red : .white.opacity(0.12))
                                        .frame(height: CGFloat(16 + value * 8))
                                    Text("\(value)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(value == haptics.level ? .white : .white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Intensity level \(value)")
                        }
                    }
                    .frame(height: 76)
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 12) {
                    Text("QUICK TEST")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.45))

                    Button {
                        haptics.pulse()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform")
                            Text("Send vibration")
                        }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(red.opacity(0.18), in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(red.opacity(0.55), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    Text("CONTINUOUS TEST")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.45))

                    HoldToVibrateButton(isHolding: haptics.isHolding, accent: red) {
                        haptics.startHolding()
                    } onRelease: {
                        haptics.stopHolding()
                    }

                    Text("Press and hold to vibrate · Release to stop")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Circle()
                        .fill(haptics.isHolding ? red : Color.green)
                        .frame(width: 7, height: 7)
                    Text(haptics.status)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 12)
        }
        .onDisappear {
            haptics.stopHolding()
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(red.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: "waveform.path")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("RUMBLE")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
                Text("iPhone haptic tester")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Text("BETA")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(red)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(red.opacity(0.12), in: Capsule())
        }
    }
}

struct HoldToVibrateButton: View {
    let isHolding: Bool
    let accent: Color
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(isHolding ? 0.22 : 0.10))
                .frame(width: 190, height: 190)
                .scaleEffect(isHolding ? 1.08 : 1)
                .animation(.easeOut(duration: 0.18), value: isHolding)

            Circle()
                .stroke(accent.opacity(0.35), lineWidth: 1)
                .frame(width: 164, height: 164)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent, Color(red: 0.65, green: 0.06, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 136, height: 136)
                .shadow(color: accent.opacity(isHolding ? 0.55 : 0.22), radius: isHolding ? 25 : 12)

            VStack(spacing: 8) {
                Image(systemName: isHolding ? "waveform" : "hand.tap.fill")
                    .font(.system(size: 29, weight: .medium))
                Text(isHolding ? "VIBRATING" : "HOLD")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
        .accessibilityElement()
        .accessibilityLabel("Press and hold to vibrate")
        .accessibilityHint("Release to stop the vibration")
    }
}
