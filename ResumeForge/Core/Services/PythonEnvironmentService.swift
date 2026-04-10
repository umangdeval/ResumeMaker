import Foundation

// MARK: - Status (kept for PythonSetupView compatibility)

/// Legacy type retained so PythonSetupView compiles during transition.
/// Backend connectivity is now tracked via BackendStatus / BackendService.
enum PythonEnvironmentStatus: Sendable {
    case ready
    case pythonNotFound
    case doclingNotInstalled
    case error(String)
}

// MARK: - Errors (legacy stubs)

enum PythonEnvironmentError: Error, LocalizedError {
    case pythonNotFound
    case dylibNotFound(String)
    case doclingNotInstalled

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 was not found. The backend server now handles PDF extraction."
        case .dylibNotFound(let path):
            return "Python shared library not found at: \(path)"
        case .doclingNotInstalled:
            return "docling is not installed. Install it in the backend: pip install docling"
        }
    }
}

// MARK: - Service (stub)

/// Legacy service retained for compilation compatibility.
/// The app now uses BackendService for all Python-powered functionality.
enum PythonEnvironmentService {
    static func configure() throws(PythonEnvironmentError) {
        // No-op: Python is now managed by the standalone backend server.
    }

    static func checkDocling() -> PythonEnvironmentStatus {
        // Always returns .ready; actual backend health is checked via BackendService.
        return .ready
    }

    static func injectVenvSitePaths(into _: Any) {
        // No-op: venv injection is not needed without PythonKit.
    }
}

