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
            .onDisappear {
                if isPressed { emulator.release(button) }
                isPressed = false
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
                .fill(LinearGradient(
                    colors: isPressed ? [Palette.buttonPressed, Palette.button] : [.white, Palette.button, Color(white: 0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay { Circle().strokeBorder(.white.opacity(0.85), lineWidth: diameter * 0.035) }
                .overlay {
                    Text(title)
                        .font(.system(size: diameter * 0.42, weight: .regular, design: .rounded))
                        .foregroundStyle(Palette.buttonLabel)
                        .shadow(color: .white, radius: 0, y: 1)
                }
                .shadow(color: .black.opacity(isPressed ? 0.16 : 0.35), radius: isPressed ? 0.5 : 1.2, y: isPressed ? 0.5 : 2.5)
                .padding(2)
                .background { Circle().fill(Color(white: 0.65)).shadow(color: .white, radius: 0, y: 1) }
                .offset(y: isPressed ? 1 : 0)
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
            DPadShape()
                .fill(Color(white: 0.62))
                .padding(-2)
                .shadow(color: .white, radius: 0.5, y: 1)
            DPadShape()
                .fill(LinearGradient(colors: [.white, Color(white: 0.93), Color(white: 0.81)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { DPadShape().stroke(.white.opacity(0.9), lineWidth: 1) }
                .shadow(color: .black.opacity(0.28), radius: 1, y: pressed.isEmpty ? 2 : 0.5)
            ForEach(0..<4, id: \.self) { direction in
                Capsule()
                    .fill(Color(white: 0.74))
                    .frame(width: 2, height: arm * 0.38)
                    .shadow(color: .white, radius: 0, x: 1, y: 1)
                    .offset(y: -size * 0.32)
                    .rotationEffect(.degrees(Double(direction) * 90))
            }
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.86), Color(white: 0.94)], center: .center, startRadius: 0, endRadius: arm * 0.25))
                .frame(width: arm * 0.48, height: arm * 0.48)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in update(directions(at: value.location)) }
                .onEnded { _ in update([]) }
        )
        .onDisappear { update([]) }
        .accessibilityLabel("Directional pad")
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

}

/// One continuous molded cross, with no overlapping rectangle seams.
nonisolated private struct DPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let a: CGFloat = 0.34
        let b: CGFloat = 0.66
        let points: [CGPoint] = [
            CGPoint(x: a, y: 0), CGPoint(x: b, y: 0), CGPoint(x: b, y: a),
            CGPoint(x: 1, y: a), CGPoint(x: 1, y: b), CGPoint(x: b, y: b),
            CGPoint(x: b, y: 1), CGPoint(x: a, y: 1), CGPoint(x: a, y: b),
            CGPoint(x: 0, y: b), CGPoint(x: 0, y: a), CGPoint(x: a, y: a)
        ]
        return Path { path in
            path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
            path.closeSubpath()
        }
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
                    .fill(LinearGradient(colors: isPressed ? [Palette.buttonPressed, Palette.button] : [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                    .overlay { Circle().strokeBorder(Color(white: 0.7), lineWidth: 0.7) }
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
            .fill(LinearGradient(colors: isPressed ? [Color(white: 0.78), Palette.button] : [.white, Color(white: 0.83)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
            .overlay {
                Text(isLeft ? "L" : "R")
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.engraving)
            }
            .frame(width: 33 * scale, height: 29 * scale)
            .offset(y: isPressed ? 2 * scale : 0)
        }
        .accessibilityLabel(isLeft ? "L" : "R")
    }
}
