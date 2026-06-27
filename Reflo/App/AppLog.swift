import Foundation
import os

/// Centralized loggers for the app, built on the unified logging system (`os.Logger`).
///
/// Use these instead of `print`. Debug-level messages are only captured when the
/// log level is turned up (e.g. via Console.app or `log` streaming), so they are
/// free in normal runs while still giving rich diagnostics when investigating issues.
///
/// Stream debug logs from a connected device/simulator with:
/// `log stream --predicate 'subsystem == "com.reflo.app"' --level debug`
enum AppLog {
    static let subsystem = "com.reflo.app"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let library = Logger(subsystem: subsystem, category: "Library")
    static let epub = Logger(subsystem: subsystem, category: "EPUB")
    static let brain = Logger(subsystem: subsystem, category: "Brain")
    static let llm = Logger(subsystem: subsystem, category: "LLM")
    static let quiz = Logger(subsystem: subsystem, category: "Quiz")
    static let narrate = Logger(subsystem: subsystem, category: "Narrate")
    static let feedback = Logger(subsystem: subsystem, category: "Feedback")
    static let speech = Logger(subsystem: subsystem, category: "Speech")
}
