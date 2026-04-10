import Foundation
import PythonKit

// MARK: - Status

enum PythonEnvironmentStatus: Sendable {
    case ready
    case pythonNotFound
    case doclingNotInstalled
    case error(String)
}

// MARK: - Errors

enum PythonEnvironmentError: Error, LocalizedError {
    case pythonNotFound
    case dylibNotFound(String)
    case doclingNotInstalled

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 was not found. Install it with: brew install python"
        case .dylibNotFound(let path):
            return "Python shared library not found at: \(path)"
        case .doclingNotInstalled:
            return "docling-parse is not installed. Run: pip install docling-parse"
        }
    }
}

// MARK: - Constants

/// Path to the dedicated venv where docling-parse is installed.
/// Created once by running: python3.11 -m venv ~/.resumeforge-venv && pip install docling-parse
private let venvPath = (("~/.resumeforge-venv" as NSString).expandingTildeInPath)
private let venvPython = venvPath + "/bin/python3"

// MARK: - Service

enum PythonEnvironmentService {
    /// Call this once at app startup — BEFORE any `Python.import` call.
    /// Uses `PythonLibrary.useLibrary(at:)` which is the only reliable way to
    /// point PythonKit at a specific interpreter at runtime.
    static func configure() throws(PythonEnvironmentError) {
        let dylib = try findPythonDylib()
        PythonLibrary.useLibrary(at: dylib)
    }

    /// Returns `.ready` if docling can be imported, otherwise explains what's missing.
    static func checkDocling() -> PythonEnvironmentStatus {
        guard let sys = try? Python.attemptImport("sys") else {
            return .pythonNotFound
        }
        // Inject venv site-packages into sys.path so imports resolve correctly
        injectVenvSitePaths(into: sys)
        guard (try? Python.attemptImport("docling.document_converter")) != nil else {
            return .doclingNotInstalled
        }
        return .ready
    }

    /// Adds the venv's site-packages to Python's sys.path if not already present.
    /// Resolves paths from the venv directory structure directly — no subprocess needed.
    static func injectVenvSitePaths(into sys: PythonObject) {
        let libURL = URL(fileURLWithPath: venvPath).appendingPathComponent("lib")
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: libURL.path) else { return }

        var pathsToAdd: [String] = []
        for dir in contents where dir.hasPrefix("python3") {
            let base = libURL.path + "/" + dir
            let sitePackages = base + "/site-packages"
            if FileManager.default.fileExists(atPath: sitePackages) {
                pathsToAdd.append(sitePackages)
            }
        }
        guard !pathsToAdd.isEmpty else { return }

        let currentPaths = Array(sys.path) ?? []
        let existing = Set(currentPaths.compactMap { String($0) })
        for path in pathsToAdd where !existing.contains(path) {
            sys.path.insert(0, PythonObject(path))
        }
    }

    // MARK: - Dylib discovery

    /// Checks the dedicated venv first, then falls back to Homebrew Python.
    private static func findPythonDylib() throws(PythonEnvironmentError) -> String {
        // Priority 1: the app's dedicated venv (Python 3.11, has docling-parse)
        let interpreters = [
            venvPython,                         // ~/.resumeforge-venv
            "/opt/homebrew/bin/python3.11",     // Homebrew 3.11 directly
            "/opt/homebrew/bin/python3",        // Homebrew default
            "/usr/local/bin/python3",           // Intel Homebrew
        ]

        for interp in interpreters where FileManager.default.isExecutableFile(atPath: interp) {
            if let dylib = dylibPath(from: interp) {
                return dylib
            }
        }

        // Fallback: glob known Homebrew framework paths for any 3.x dylib
        let globs = [
            "/opt/homebrew/opt/python@3.11/Frameworks/Python.framework/Versions/3.11/lib/libpython3.11.dylib",
            "/opt/homebrew/opt/python@3.*/Frameworks/Python.framework/Versions/3.*/lib/libpython3.*.dylib",
            "/usr/local/opt/python@3.*/Frameworks/Python.framework/Versions/3.*/lib/libpython3.*.dylib",
        ]
        for pattern in globs {
            // Direct path check first (no glob needed for the 3.11 exact path)
            if FileManager.default.fileExists(atPath: pattern) { return pattern }
            if let found = globSearch(pattern: pattern).first { return found }
        }

        throw .pythonNotFound
    }

    /// Ask the interpreter for its own dylib path via sysconfig.
    private static func dylibPath(from pythonExec: String) -> String? {
        let script = """
import sysconfig, os, glob
prefix = sysconfig.get_config_var('prefix')
libdir = sysconfig.get_config_var('LIBDIR') or os.path.join(prefix, 'lib')
# Look for libpythonX.Y.dylib in LIBDIR
hits = glob.glob(os.path.join(libdir, 'libpython3*.dylib'))
if hits:
    print(hits[0])
"""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonExec)
        task.arguments = ["-c", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // suppress stderr
        guard (try? task.run()) != nil else { return nil }
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? nil : output
    }

    /// Minimal glob expansion for `*` wildcards using FileManager.
    private static func globSearch(pattern: String) -> [String] {
        // Split on first * to get a searchable base directory
        let parts = pattern.components(separatedBy: "*")
        guard parts.count > 1 else {
            return FileManager.default.fileExists(atPath: pattern) ? [pattern] : []
        }
        // Walk from the last known literal directory
        var base = (parts[0] as NSString).deletingLastPathComponent
        if base.isEmpty { base = "/" }

        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: base),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        // Convert the shell glob to a simple NSPredicate regex
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: "[^/]*") + "$"
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return [] }

        var results: [String] = []
        for case let url as URL in enumerator {
            let p = url.path
            let range = NSRange(p.startIndex..., in: p)
            if regex.firstMatch(in: p, range: range) != nil {
                results.append(p)
            }
        }
        return results.sorted()
    }
}
