import GameController
import SwiftUI

extension View {
    /// Drives the emulator from a hardware keyboard while this view is on screen.
    func keyboardControls(for emulator: DSEmulator) -> some View {
        modifier(KeyboardControls(emulator: emulator))
    }
}

/// WASD is the D-pad, Q/E the shoulders, the arrow keys the face buttons
/// (laid out like the diamond: ↑ X, ← Y, → A, ↓ B), Return is START and
/// Right Shift is SELECT (with Space as an easier-to-reach alternative).
private struct KeyboardControls: ViewModifier {
    let emulator: DSEmulator

    private static let mapping: [GCKeyCode: DSButton] = [
        .keyW: .up, .keyA: .left, .keyS: .down, .keyD: .right,
        .keyQ: .l, .keyE: .r,
        .upArrow: .x, .leftArrow: .y, .rightArrow: .a, .downArrow: .b,
        .returnOrEnter: .start, .keypadEnter: .start,
        .rightShift: .select, .spacebar: .select,
    ]

    func body(content: Content) -> some View {
        content
            .onAppear { attach(GCKeyboard.coalesced) }
            .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { note in
                attach(note.object as? GCKeyboard)
            }
            .onDisappear {
                GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = nil
                for button in Set(Self.mapping.values) { emulator.release(button) }
            }
    }

    private func attach(_ keyboard: GCKeyboard?) {
        keyboard?.keyboardInput?.keyChangedHandler = { [emulator] _, _, keyCode, pressed in
            guard let button = Self.mapping[keyCode] else { return }
            Task { @MainActor in
                if pressed { emulator.press(button) } else { emulator.release(button) }
            }
        }
    }
}
