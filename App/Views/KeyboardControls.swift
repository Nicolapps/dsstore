import SwiftUI
import UIKit

extension View {
    /// Drives the emulator from a hardware keyboard while this view is on screen.
    func keyboardControls(for emulator: DSEmulator) -> some View {
        background(KeyboardControls(emulator: emulator))
    }
}

/// WASD is the D-pad, Q/E the shoulders, the arrow keys the face buttons
/// (laid out like the diamond: ↑ X, ← Y, → A, ↓ B), Return is START and
/// Right Shift is SELECT (with Space as an easier-to-reach alternative).
///
/// Reads keys as UIKit presses rather than through `GCKeyboard`, which only
/// sees keyboards the system reports as connected game input (some simulator
/// hosts, like Bitrig, deliver key events without one).
private struct KeyboardControls: UIViewRepresentable {
    let emulator: DSEmulator

    func makeUIView(context: Context) -> KeyView {
        KeyView(emulator: emulator)
    }

    func updateUIView(_ view: KeyView, context: Context) {
        view.emulator = emulator
    }

    final class KeyView: UIView {
        private static let mapping: [UIKeyboardHIDUsage: DSButton] = [
            .keyboardW: .up, .keyboardA: .left, .keyboardS: .down, .keyboardD: .right,
            .keyboardQ: .l, .keyboardE: .r,
            .keyboardUpArrow: .x, .keyboardLeftArrow: .y, .keyboardRightArrow: .a, .keyboardDownArrow: .b,
            .keyboardReturnOrEnter: .start, .keypadEnter: .start,
            .keyboardRightShift: .select, .keyboardSpacebar: .select,
        ]

        var emulator: DSEmulator

        init(emulator: DSEmulator) {
            self.emulator = emulator
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                becomeFirstResponder()
            } else {
                for button in emulator.keyboardButtons { emulator.setKeyboardButton(button, pressed: false) }
            }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if !handle(presses, pressed: true) { super.pressesBegan(presses, with: event) }
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if !handle(presses, pressed: false) { super.pressesEnded(presses, with: event) }
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if !handle(presses, pressed: false) { super.pressesCancelled(presses, with: event) }
        }

        /// Returns whether every press was one of ours.
        private func handle(_ presses: Set<UIPress>, pressed: Bool) -> Bool {
            var handledAll = true
            for press in presses {
                guard let code = press.key?.keyCode, let button = Self.mapping[code] else {
                    handledAll = false
                    continue
                }
                emulator.setKeyboardButton(button, pressed: pressed)
            }
            return handledAll
        }
    }
}
