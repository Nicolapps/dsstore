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
        label(isPressed || emulator.keyboardButtons.contains(button))
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

/// A stationary dark socket surrounds a raised cap, with a narrow molded bevel.
private struct MoldedCap<S: InsettableShape>: View {
    let shape: S
    let isPressed: Bool
    let depth: CGFloat

    var body: some View {
        ZStack {
            shape.fill(Color(white: 0.43).shadow(.inner(color: .black.opacity(0.45), radius: depth, y: depth)))
                .overlay { shape.strokeBorder(.white.opacity(0.85), lineWidth: depth * 0.35) }
            shape
                .fill(LinearGradient(colors: [Color(white: 0.99), Color(white: 0.76), Color(white: 0.60)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(depth * 0.65)
                .shadow(color: .black.opacity(isPressed ? 0.15 : 0.38), radius: depth * 0.5,
                        x: depth * 0.3, y: isPressed ? 0 : depth)
            shape
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: isPressed ? 0.86 : 0.985), location: 0),
                    .init(color: Color(white: isPressed ? 0.88 : 0.95), location: 0.48),
                    .init(color: Color(white: 0.87), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { shape.strokeBorder(.white.opacity(0.7), lineWidth: depth * 0.3) }
                .padding(depth * 1.4)
                .offset(y: isPressed ? depth * 0.45 : -depth * 0.35)
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
            MoldedCap(shape: Circle(), isPressed: isPressed, depth: diameter * 0.055)
                .overlay {
                    Text(title)
                        .font(.system(size: diameter * 0.40, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.49))
                        .shadow(color: .white.opacity(0.95), radius: 0, x: 0.5, y: 0.8)
                        .offset(y: isPressed ? diameter * 0.025 : -diameter * 0.018)
                }
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
            MoldedCap(shape: DPadShape(), isPressed: !pressed.isEmpty || !emulator.keyboardButtons.isDisjoint(with: [.up, .down, .left, .right]), depth: size * 0.018)
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
nonisolated private struct DPadShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> DPadShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: insetAmount, dy: insetAmount)
        let a: CGFloat = 0.34
        let b: CGFloat = 0.66
        let points: [CGPoint] = [
            CGPoint(x: a, y: 0), CGPoint(x: b, y: 0), CGPoint(x: b, y: a),
            CGPoint(x: 1, y: a), CGPoint(x: 1, y: b), CGPoint(x: b, y: b),
            CGPoint(x: b, y: 1), CGPoint(x: a, y: 1), CGPoint(x: a, y: b),
            CGPoint(x: 0, y: b), CGPoint(x: 0, y: a), CGPoint(x: a, y: a)
        ]
        let vertices = points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        let rounding = bounds.width * 0.014
        return Path { path in
            for index in vertices.indices {
                let previous = vertices[(index + vertices.count - 1) % vertices.count]
                let current = vertices[index]
                let next = vertices[(index + 1) % vertices.count]
                func near(_ point: CGPoint) -> CGPoint {
                    let length = hypot(point.x - current.x, point.y - current.y)
                    return CGPoint(x: current.x + (point.x - current.x) * rounding / length,
                                   y: current.y + (point.y - current.y) * rounding / length)
                }
                let entry = near(previous)
                if index == 0 { path.move(to: entry) } else { path.addLine(to: entry) }
                path.addQuadCurve(to: near(next), control: current)
            }
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
                MoldedCap(shape: Circle(), isPressed: isPressed, depth: 0.9 * scale)
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
            MoldedCap(shape: UnevenRoundedRectangle(
                topLeadingRadius: isLeft ? 10 * scale : 4 * scale,
                bottomLeadingRadius: 4 * scale,
                bottomTrailingRadius: 4 * scale,
                topTrailingRadius: isLeft ? 4 * scale : 10 * scale,
                style: .continuous
            ), isPressed: isPressed, depth: 1.2 * scale)
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
