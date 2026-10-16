import Foundation

/// Minimal logging to the LaunchAgent's standard error, which
/// `~/Library/Logs/QuotaBar/quotabar.err.log` captures.
///
/// A menu bar agent has no window to show diagnostics in, so the log is the only
/// way to answer "why is my provider not in the menu bar" after the fact.
enum Log {
    static func write(_ message: String) {
        let line = "[quotabar] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
