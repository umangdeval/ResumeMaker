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
    case doclingNotInstalled
    case initFailed(String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 was not found. Please install Python 3 and ensure it is on your PATH."
        case .doclingNotInstalled:
            return "docling-parse is not installed. Run: pip install docling-parse"
        case .initFailed(let msg):
            return "Python initialization failed: \(msg)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .pythonNotFound:
            return "Install Python 3 from python.org or via Homebrew: brew install python"
        case .doclingNotInstalled:
            return "In your terminal, run: pip install docling-parse"
        case .initFailed:
            return "Restart the app. If the problem persists, reinstall docling-parse."
        }
    }
}

// MARK: - Service

/// Validates that the host Python environment has docling-parse available.
/// All Python interaction is isolated here so the rest of the app never imports PythonKit directly.
enum PythonEnvironmentService {
    /// Locate the best Python 3 executable and configure PythonKit to use it.
    /// Must be called once before any other Python-based service is used.
    @MainActor
    static func configure() throws(PythonEnvironmentError) {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            pythonFromPath()
        ].compactMap { $0 }

        guard let pythonPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw .pythonNotFound
        }

        // Tell PythonKit which interpreter to use before importing anything
        setenv("PYTHON_LIBRARY", pythonLibrary(for: pythonPath) ?? "", 1)
    }

    /// Checks docling_parse can be imported. Call after `configure()`.
    static func checkDocling() -> PythonEnvironmentStatus {
        do {
            _ = try Python.attemptImport("docling_parse")
            return .ready
        } catch {
            // Check if it's just docling missing vs Python entirely broken
            if (try? Python.attemptImport("sys")) != nil {
                return .doclingNotInstalled
            }
            return .pythonNotFound
        }
    }

    // MARK: - Helpers

    private static func pythonFromPath() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["python3"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Derive the Python shared library path from the executable path.
    private static func pythonLibrary(for pythonExec: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonExec)
        task.arguments = ["-c",
            "import sysconfig; print(sysconfig.get_config_var('LDLIBRARY') or '')"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        guard let lib = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                               encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lib.isEmpty else { return nil }

        // Build full path: <prefix>/lib/<libname>
        let prefix = URL(fileURLWithPath: pythonExec)
            .deletingLastPathComponent()   // bin/
            .deletingLastPathComponent()   // prefix/
        return prefix.appendingPathComponent("lib/\(lib)").path
    }
}
