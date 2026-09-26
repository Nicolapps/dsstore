import SwiftUI

/// Tracks a finger held down on a view, reporting presses and releases (not taps).
private struct HoldGesture: ViewModifier {
    @Binding var isPressed: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isPressed { isPressed = true } }
                    .onEnded { _ in isPressed = false }
            )
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isPressed) { _, pressed in pressed }
    }
}

/// A button that forwards press and release to the emulator.
private struct HardwareButton<Label: View>: View {
    let button: DSButton
    let emulator: DSEmulator
    @ViewBuilder let label: (_ isPressed: Bool) -> Label

    @State private var isPressed = false

    var body: some View {
        label(isPressed)
            .modifier(HoldGesture(isPressed: $isPressed))
            .onChange(of: isPressed) { _, pressed in
                if pressed { emulator.press(button) } else { emulator.release(button) }
            }
    }
}

// MARK: - Face buttons

struct FaceButtons: View {
    let emulator: DSEmulator
    let size: CGFloat

    var body: some View {
        let offset = size * 0.33

        ZStack {
            face(.x, "X").offset(y: -offset)
            face(.b, "B").offset(y: offset)
            face(.y, "Y").offset(x: -offset)
            face(.a, "A").offset(x: offset)
        }
        .frame(width: size, height: size)
    }

    private func face(_ button: DSButton, _ title: String) -> some View {
        let diameter = size * 0.34
        return HardwareButton(button: button, emulator: emulator) { isPressed in
            Circle()
                .fill(isPressed ? Palette.buttonPressed : Palette.button)
                .overlay {
                    Text(title)
                        .font(.system(size: diameter * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.buttonLabel)
                }
                .shadow(color: .black.opacity(isPressed ? 0.1 : 0.3), radius: isPressed ? 0.5 : 1.5, y: isPressed ? 0.5 : 1.5)
                .scaleEffect(isPressed ? 0.94 : 1)
                .frame(width: diameter, height: diameter)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - D-pad

struct DPad: View {
    let emulator: DSEmulator
    let size: CGFloat

    @State private var pressed: Set<DSButton> = []

    var body: some View {
        let arm = size * 0.34

        ZStack {
            RoundedRectangle(cornerRadius: arm * 0.18)
                .frame(width: arm, height: size)
            RoundedRectangle(cornerRadius: arm * 0.18)
                .frame(width: size, height: arm)
            Circle()
                .fill(.black.opacity(0.25))
                .frame(width: arm * 0.45)
        }
        .foregroundStyle(Palette.dpad)
        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1.5)
        .rotation3DEffect(.degrees(pressed.isEmpty ? 0 : 8), axis: tiltAxis)
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in update(directions(at: value.location)) }
                .onEnded { _ in update([]) }
        )
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressed) { old, new in
            !new.subtracting(old).isEmpty
        }
    }

    /// Maps a touch to up to two directions, so diagonals press both.
    private func directions(at location: CGPoint) -> Set<DSButton> {
        let dx = location.x - size / 2
        let dy = location.y - size / 2
        guard hypot(dx, dy) > size * 0.1 else { return [] }

        // Each direction covers a 135° sector, so the 45° between neighbors activates both.
        let angle = atan2(-dy, dx) * 180 / .pi
        let sectors: [(DSButton, Double)] = [(.right, 0), (.up, 90), (.left, 180), (.down, -90)]
        return Set(sectors.compactMap { button, center in
            let delta = abs(remainder(angle - center, 360))
            return delta < 67.5 ? button : nil
        })
    }

    private func update(_ newValue: Set<DSButton>) {
        for button in pressed.subtracting(newValue) { emulator.release(button) }
        for button in newValue.subtracting(pressed) { emulator.press(button) }
        pressed = newValue
    }

    private var tiltAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        let x: CGFloat = (pressed.contains(.up) ? 1 : 0) - (pressed.contains(.down) ? 1 : 0)
        let y: CGFloat = (pressed.contains(.right) ? 1 : 0) - (pressed.contains(.left) ? 1 : 0)
        return (x, y, 0)
    }
}

// MARK: - Small buttons

struct PillButton: View {
    let button: DSButton
    let title: String
    let emulator: DSEmulator
    let scale: CGFloat

    var body: some View {
        HardwareButton(button: button, emulator: emulator) { isPressed in
            VStack(spacing: 3 * scale) {
                Circle()
                    .fill(isPressed ? Palette.buttonPressed : Palette.button)
                    .shadow(color: .black.opacity(isPressed ? 0.1 : 0.3), radius: 1, y: isPressed ? 0.5 : 1)
                    .frame(width: 16 * scale, height: 16 * scale)
                Text(title)
                    .font(.system(size: 8 * scale, weight: .medium))
                    .kerning(0.5)
                    .foregroundStyle(Palette.engraving)
            }
            .padding(6 * scale)
        }
        .accessibilityLabel(title)
    }
}

struct ShoulderButton: View {
    let button: DSButton
    let emulator: DSEmulator
    let scale: CGFloat

    var body: some View {
        let isLeft = button == .l

        HardwareButton(button: button, emulator: emulator) { isPressed in
            UnevenRoundedRectangle(
                topLeadingRadius: isLeft ? 18 * scale : 6 * scale,
                bottomLeadingRadius: 4 * scale,
                bottomTrailingRadius: 4 * scale,
                topTrailingRadius: isLeft ? 6 * scale : 18 * scale,
                style: .continuous
            )
            .fill(isPressed ? Palette.shoulderPressed : Palette.shoulder)
            .overlay {
                Text(isLeft ? "L" : "R")
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.engraving)
            }
            .frame(width: 84 * scale, height: 22 * scale)
            .offset(y: isPressed ? 2 * scale : 0)
        }
        .accessibilityLabel(isLeft ? "L" : "R")
    }
}
