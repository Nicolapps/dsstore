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

extension View {
    /// Text molded into the shell: a shade darker than the plastic, with the lip below it catching the light.
    func engraved(_ color: Color = Palette.engraving) -> some View {
        foregroundStyle(color)
            .shadow(color: .white.opacity(0.9), radius: 0, x: 0, y: 0.8)
    }
}

// MARK: - Molded caps

/// The console is seen from slightly in front, lit from above: a raised cap shows a sliver of
/// its side wall below its top face, and sinks into a dark well in the shell when pushed.
private struct RaisedCap<S: InsettableShape, Top: View>: View {
    let shape: S
    let isPressed: Bool
    /// How far a released cap stands out of its well.
    let travel: CGFloat
    /// Width of the rounded edge between the top face and the side wall.
    let bevel: CGFloat
    var gloss = true
    @ViewBuilder var top: Top

    var body: some View {
        let lift = isPressed ? travel * 0.18 : travel

        ZStack {
            Well(shape: shape, gap: travel * 0.5)
            CastShadow(shape: shape, lift: lift, travel: travel)
            CapSide(shape: shape, lift: lift)
            CapFace(shape: shape, bevel: bevel, gloss: gloss, dimmed: isPressed) { top }
                .offset(y: -lift)
        }
        .animation(isPressed ? .easeOut(duration: 0.05) : .spring(duration: 0.26, bounce: 0.45), value: isPressed)
    }
}

/// The opening in the shell a cap sits in: its upper wall in shadow, its lower lip catching the light.
private struct Well<S: InsettableShape>: View {
    let shape: S
    let gap: CGFloat

    var body: some View {
        let hole = shape.inset(by: -gap)
        hole.fill(Color(white: 0.64).shadow(.inner(color: .black.opacity(0.35), radius: gap * 1.4, y: gap)))
            .overlay {
                hole.strokeBorder(LinearGradient(colors: [.black.opacity(0.12), .clear, .white],
                                                 startPoint: .top, endPoint: .bottom),
                                  lineWidth: max(0.6, gap * 0.45))
            }
    }
}

/// Soft and long while the cap stands proud, tight once it's pushed down against the well.
private struct CastShadow<S: Shape>: View {
    let shape: S
    let lift: CGFloat
    let travel: CGFloat
    var tilt: CGVector = .zero

    var body: some View {
        let height = lift / travel
        shape.fill(.black.opacity(0.1 + 0.1 * height))
            .blur(radius: travel * (0.25 + 0.6 * height))
            .offset(x: -tilt.dx * travel * 0.3, y: travel * (0.12 + 0.45 * height) - tilt.dy * travel * 0.3)
    }
}

/// The cap's side wall, swept from its base up to the top face so the whole silhouette stays solid.
private struct CapSide<S: Shape>: View {
    let shape: S
    let lift: CGFloat
    var tilt: CGVector = .zero

    var body: some View {
        let steps = 8
        ZStack {
            ForEach(0...steps, id: \.self) { step in
                let height = CGFloat(step) / CGFloat(steps)
                shape
                    .fill(LinearGradient(stops: [
                        .init(color: Color(white: 0.76), location: 0),
                        .init(color: Color(white: 0.85), location: 0.22),
                        .init(color: Color(white: 0.9), location: 0.5),
                        .init(color: Color(white: 0.84), location: 0.8),
                        .init(color: Color(white: 0.75), location: 1)
                    ], startPoint: .leading, endPoint: .trailing))
                    .modifier(Rock(tilt: tilt, lift: lift * height))
                    .offset(y: -lift * height)
            }
            // Where the wall meets the well.
            shape.stroke(.black.opacity(0.1), lineWidth: 0.6)
        }
    }
}

/// Leans a slice of a rocking cap that stands `lift` above its well: the side in the tilt's direction
/// sinks toward the shell (so, seen from the front, it drops and recedes) while the opposite side rises.
private struct Rock: GeometryEffect {
    var tilt: CGVector
    let lift: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(tilt.dx, tilt.dy) }
        set { tilt = CGVector(dx: newValue.first, dy: newValue.second) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amount = hypot(tilt.dx, tilt.dy)
        guard amount > 0, lift > 0, size.width > 0, size.height > 0 else { return ProjectionTransform() }
        // How far each tip moves from its resting height, relative to the cap's full lift.
        let dip: CGFloat = 0.45
        var transform = CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0)
        // Foreshortening: the sunken side is farther from the viewer.
        let angle = atan(dip * lift / (size.width / 2))
        transform = CATransform3DConcat(transform, CATransform3DMakeRotation(angle * amount, -tilt.dy, tilt.dx, 0))
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / (size.width * 2.2)
        transform = CATransform3DConcat(transform, perspective)
        // Parallax: lower points sit less far above the shell, so they show lower on screen.
        var shear = CATransform3DIdentity
        shear.m12 = dip * lift * tilt.dx / (size.width / 2)
        shear.m22 = 1 + dip * lift * tilt.dy / (size.height / 2)
        transform = CATransform3DConcat(transform, shear)
        transform = CATransform3DConcat(transform, CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0))
        return ProjectionTransform(transform)
    }
}

/// The top of a white glossy cap: gently domed, with a rounded edge and a soft reflection of the light above.
private struct CapFace<S: InsettableShape, Top: View>: View {
    let shape: S
    let bevel: CGFloat
    let gloss: Bool
    let dimmed: Bool
    @ViewBuilder var top: Top

    var body: some View {
        shape
            .fill(EllipticalGradient(stops: [
                .init(color: .white, location: 0),
                .init(color: Color(white: 0.965), location: 0.5),
                .init(color: Color(white: 0.88), location: 1)
            ], center: UnitPoint(x: 0.42, y: 0.3), startRadiusFraction: 0, endRadiusFraction: 0.85))
            .overlay {
                // The rounded edge: bright where it turns toward the light, shaded where it turns away.
                shape.strokeBorder(LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.2), location: 0.35),
                    .init(color: .black.opacity(0.04), location: 0.6),
                    .init(color: .black.opacity(0.2), location: 1)
                ], startPoint: .top, endPoint: .bottom), lineWidth: bevel)
                .blur(radius: bevel * 0.35)
            }
            .overlay {
                if gloss {
                    GeometryReader { proxy in
                        Ellipse()
                            .fill(.white.opacity(0.85))
                            .frame(width: proxy.size.width * 0.46, height: proxy.size.height * 0.2)
                            .blur(radius: proxy.size.width * 0.05)
                            .position(x: proxy.size.width * 0.44, y: proxy.size.height * 0.2)
                    }
                }
            }
            .overlay { top }
            .overlay { shape.fill(.black.opacity(dimmed ? 0.06 : 0)) }
            .clipShape(shape)
    }
}

// MARK: - Face buttons

struct FaceButtons: View {
    let emulator: DSEmulator
    let size: CGFloat

    var body: some View {
        let offset = size * 0.335

        ZStack {
            face(.x, "X").offset(y: -offset)
            face(.b, "B").offset(y: offset)
            face(.y, "Y").offset(x: -offset)
            face(.a, "A").offset(x: offset)
        }
        .frame(width: size, height: size)
    }

    private func face(_ button: DSButton, _ title: String) -> some View {
        let diameter = size * 0.31
        return HardwareButton(button: button, emulator: emulator) { isPressed in
            RaisedCap(shape: Circle(), isPressed: isPressed, travel: diameter * 0.09, bevel: diameter * 0.08) {
                Text(title)
                    .font(HardwareFont.faceLetter(size: diameter * 0.38))
                    .engraved(Color(white: 0.78))
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

    private static let directions: Set<DSButton> = [.up, .down, .left, .right]

    var body: some View {
        let tilt = Self.tilt(for: pressed.union(emulator.keyboardButtons.intersection(Self.directions)))
        let travel = size * 0.05
        // A real pad rocks on a pivot under its center: the pressed arm dips, the opposite one rises.
        let shape = DPadShape()

        ZStack {
            Well(shape: shape, gap: size * 0.016)
            CastShadow(shape: shape, lift: travel, travel: travel, tilt: tilt)
            ZStack {
                CapSide(shape: shape, lift: travel, tilt: tilt)
                CapFace(shape: shape, bevel: size * 0.028, gloss: false, dimmed: false) {
                    DPadMarkings(size: size)
                }
                .overlay {
                    // The dipping arm turns away from the light; the rising one catches more of it.
                    LinearGradient(colors: [.black.opacity(0.13), .clear, .white.opacity(0.25)],
                                   startPoint: UnitPoint(x: 0.5 + tilt.dx / 2, y: 0.5 + tilt.dy / 2),
                                   endPoint: UnitPoint(x: 0.5 - tilt.dx / 2, y: 0.5 - tilt.dy / 2))
                        .clipShape(shape)
                        .opacity(tilt == .zero ? 0 : 1)
                }
                .modifier(Rock(tilt: tilt, lift: travel))
                .offset(y: -travel)
            }
        }
        .animation(.spring(duration: 0.2, bounce: 0.35), value: tilt)
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

    /// Which way the pad leans, as a unit vector in view coordinates (zero when centered).
    private static func tilt(for held: Set<DSButton>) -> CGVector {
        let dx = (held.contains(.right) ? 1.0 : 0) - (held.contains(.left) ? 1.0 : 0)
        let dy = (held.contains(.down) ? 1.0 : 0) - (held.contains(.up) ? 1.0 : 0)
        let length = hypot(dx, dy)
        return length == 0 ? .zero : CGVector(dx: dx / length, dy: dy / length)
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

/// A line molded into each arm, pointing along it, and the shallow dish at the pivot.
private struct DPadMarkings: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { direction in
                Capsule()
                    .fill(Color(white: 0.84).shadow(.inner(color: .black.opacity(0.15), radius: 0.5, y: 0.5)))
                    .frame(width: size * 0.018, height: size * 0.1)
                    .shadow(color: .white, radius: 0, y: 0.8)
                    .offset(y: -size * 0.33)
                    .rotationEffect(.degrees(Double(direction) * 90))
            }
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.96), .white],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    Circle().strokeBorder(LinearGradient(colors: [.black.opacity(0.06), .white],
                                                         startPoint: .top, endPoint: .bottom),
                                          lineWidth: size * 0.01)
                }
                .frame(width: size * 0.19, height: size * 0.19)
        }
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
        let a: CGFloat = 0.34
        let b: CGFloat = 0.66
        let points: [CGPoint] = [
            CGPoint(x: a, y: 0), CGPoint(x: b, y: 0), CGPoint(x: b, y: a),
            CGPoint(x: 1, y: a), CGPoint(x: 1, y: b), CGPoint(x: b, y: b),
            CGPoint(x: b, y: 1), CGPoint(x: a, y: 1), CGPoint(x: a, y: b),
            CGPoint(x: 0, y: b), CGPoint(x: 0, y: a), CGPoint(x: a, y: a)
        ]
        // Every edge is axis-aligned, so offsetting the outline evenly moves each corner,
        // convex or not, the same distance toward the center on both axes.
        let vertices = points.map { point in
            CGPoint(x: bounds.minX + point.x * bounds.width + (point.x < 0.5 ? insetAmount : -insetAmount),
                    y: bounds.minY + point.y * bounds.height + (point.y < 0.5 ? insetAmount : -insetAmount))
        }
        let rounding = bounds.width * 0.03
        return Path { path in
            for index in vertices.indices {
                let previous = vertices[(index + vertices.count - 1) % vertices.count]
                let current = vertices[index]
                let next = vertices[(index + 1) % vertices.count]
                func near(_ point: CGPoint) -> CGPoint {
                    let length = hypot(point.x - current.x, point.y - current.y)
                    let distance = min(rounding, length / 2)
                    return CGPoint(x: current.x + (point.x - current.x) * distance / length,
                                   y: current.y + (point.y - current.y) * distance / length)
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

/// START above SELECT, each a small round cap with its name molded beside it.
struct SystemButtons: View {
    let emulator: DSEmulator
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            row(.start, "START")
            row(.select, "SELECT")
        }
    }

    private func row(_ button: DSButton, _ title: String) -> some View {
        HardwareButton(button: button, emulator: emulator) { isPressed in
            HStack(spacing: 7 * scale) {
                RaisedCap(shape: Circle(), isPressed: isPressed, travel: 2.4 * scale, bevel: 1.6 * scale) {
                    EmptyView()
                }
                .frame(width: 18 * scale, height: 18 * scale)
                Text(title)
                    .font(HardwareFont.label(size: 10.5 * scale))
                    .kerning(0.6 * scale)
                    .engraved(Color(white: 0.5))
            }
            .padding(5 * scale)
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
            RaisedCap(shape: UnevenRoundedRectangle(
                topLeadingRadius: isLeft ? 11 * scale : 4 * scale,
                bottomLeadingRadius: 4 * scale,
                bottomTrailingRadius: 4 * scale,
                topTrailingRadius: isLeft ? 4 * scale : 11 * scale,
                style: .continuous
            ), isPressed: isPressed, travel: 3.2 * scale, bevel: 2.4 * scale, gloss: false) {
                Text(isLeft ? "L" : "R")
                    .font(HardwareFont.label(size: 11 * scale))
                    .engraved()
            }
            .frame(width: 36 * scale, height: 26 * scale)
        }
        .accessibilityLabel(isLeft ? "L" : "R")
    }
}
