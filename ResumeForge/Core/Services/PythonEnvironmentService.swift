import Foundation

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
    case backendScriptNotFound
    case doclingNotInstalled

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 was not found. Install it with: brew install python"
        case .backendScriptNotFound:
            return "Docling backend script was not found in app resources."
        case .doclingNotInstalled:
            return "docling-parse is not installed. Run: ./.venv/bin/python -m pip install docling-parse"
        }
    }
}

// MARK: - Service

enum PythonEnvironmentService {
    /// Optional startup validation for the local Python backend setup.
    static func configure() throws(PythonEnvironmentError) {
        do {
            _ = try DoclingBackendService.checkHealth()
        } catch let error as DoclingBackendServiceError {
            switch error {
            case .pythonNotFound:
                throw .pythonNotFound
            case .backendScriptNotFound:
                throw .backendScriptNotFound
            default:
                return
            }
        } catch {
            return
        }
    }

    /// Returns `.ready` if Python and docling backend are healthy, otherwise explains what's missing.
    static func checkDocling() -> PythonEnvironmentStatus {
        do {
            let health = try DoclingBackendService.checkHealth()
            if health.ok {
                return .ready
            }
            if health.docling == false {
                return .doclingNotInstalled
            }
            return .error(health.error ?? "Python backend health check failed.")
        } catch let error as DoclingBackendServiceError {
            switch error {
            case .pythonNotFound:
                return .pythonNotFound
            case .backendScriptNotFound:
                return .error("Docling backend script missing from app resources.")
            case .backendError(let message):
                if message.localizedCaseInsensitiveContains("docling") {
                    return .doclingNotInstalled
                }
                return .error(message)
            case .launchFailed(let details):
                return .error(details)
            case .timedOut:
                return .error("Python backend timed out.")
            case .invalidResponse:
                return .error("Invalid response from Python backend.")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

// MARK: - Backend Models

struct DoclingBackendHealthResponse: Decodable {
    let ok: Bool
    let python: String?
    let docling: Bool?
    let error: String?
}

private struct DoclingBackendExtractResponse: Decodable {
    let ok: Bool
    let text: String?
    let error: String?
}

// MARK: - Backend Errors

enum DoclingBackendServiceError: Error, LocalizedError {
    case pythonNotFound
    case backendScriptNotFound
    case launchFailed(String)
    case timedOut
    case invalidResponse
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 was not found."
        case .backendScriptNotFound:
            return "Docling backend script is missing."
        case .launchFailed(let details):
            return "Failed to start Python backend: \(details)"
        case .timedOut:
            return "Python backend timed out while processing the PDF."
        case .invalidResponse:
            return "Python backend returned an invalid response."
        case .backendError(let message):
            return message
        }
    }
}

// MARK: - Process-based backend

enum DoclingBackendService {
    static func checkHealth() throws -> DoclingBackendHealthResponse {
        let result = try run(arguments: ["health"], timeout: 8)
        let data = Data(result.stdout.utf8)
        return try JSONDecoder().decode(DoclingBackendHealthResponse.self, from: data)
    }

    static func extractText(from pdfURL: URL) throws -> String {
        let result = try run(arguments: ["extract", "--pdf", pdfURL.path], timeout: 90)
        let data = Data(result.stdout.utf8)
        let decoded = try JSONDecoder().decode(DoclingBackendExtractResponse.self, from: data)

        guard decoded.ok else {
            throw DoclingBackendServiceError.backendError(decoded.error ?? "Docling extraction failed.")
        }

        let text = decoded.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw DoclingBackendServiceError.backendError("Docling extracted no text from this PDF.")
        }
        return text
    }

    private static func run(arguments: [String], timeout: TimeInterval) throws -> ProcessResult {
        let pythonExec = try resolvePythonExecutablePath()
        let scriptPath = try resolveBackendScriptPath()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonExec)
        task.arguments = [scriptPath] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
        } catch {
            throw DoclingBackendServiceError.launchFailed(error.localizedDescription)
        }

        let group = DispatchGroup()
        group.enter()
        task.terminationHandler = { _ in group.leave() }

        if group.wait(timeout: .now() + timeout) == .timedOut {
            task.terminate()
            throw DoclingBackendServiceError.timedOut
        }

        let stdout = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if task.terminationStatus != 0 {
            if containsMissingDoclingSignal(in: stderr) || containsMissingDoclingSignal(in: stdout) {
                throw DoclingBackendServiceError.backendError("docling-parse is not installed for the active Python interpreter.")
            }
            let message = backendErrorMessage(stdout: stdout, stderr: stderr, exitCode: task.terminationStatus)
            throw DoclingBackendServiceError.backendError(message)
        }

        guard !stdout.isEmpty else {
            throw DoclingBackendServiceError.invalidResponse
        }

        return ProcessResult(stdout: stdout, stderr: stderr)
    }

    private static func containsMissingDoclingSignal(in output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("no module named") && normalized.contains("docling")
    }

    private static func backendErrorMessage(stdout: String, stderr: String, exitCode: Int32) -> String {
        if let jsonMessage = parseJSONErrorMessage(from: stdout) {
            return jsonMessage
        }
        if !stderr.isEmpty {
            return stderr
        }
        return "Python backend exited with code \(exitCode)."
    }

    private static func parseJSONErrorMessage(from text: String) -> String? {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let error = object["error"] as? String else { return nil }
        let trimmed = error.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func resolvePythonExecutablePath() throws -> String {
        let env = ProcessInfo.processInfo.environment
        let envPython = env["RESUMEFORGE_PYTHON"]
        let cwd = FileManager.default.currentDirectoryPath

        let candidates = [
            envPython,
            "\(cwd)/.venv/bin/python3",
            ("~/.resumeforge-venv/bin/python3" as NSString).expandingTildeInPath,
            "/opt/homebrew/bin/python3",
            "/opt/homebrew/bin/python3.11",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            ("~/.pyenv/shims/python3" as NSString).expandingTildeInPath,
        ].compactMap { $0 }

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        throw DoclingBackendServiceError.pythonNotFound
    }

    private static func resolveBackendScriptPath() throws -> String {
        if let bundled = Bundle.main.url(forResource: "docling_backend", withExtension: "py") {
            return bundled.path
        }

        if let bundledInPython = Bundle.main.url(
            forResource: "docling_backend",
            withExtension: "py",
            subdirectory: "Python"
        ) {
            return bundledInPython.path
        }

        let cwd = FileManager.default.currentDirectoryPath
        let sourcePath = "\(cwd)/ResumeForge/Resources/Python/docling_backend.py"
        if FileManager.default.fileExists(atPath: sourcePath) {
            return sourcePath
        }

        // Last-resort fallback: materialize script into temporary directory.
        return try writeEmbeddedScriptIfNeeded()
    }

    private static func writeEmbeddedScriptIfNeeded() throws -> String {
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("resumeforge_docling_backend.py")
            .path

        do {
            let existing = try? String(contentsOfFile: tempPath, encoding: .utf8)
            if existing != embeddedBackendScript {
                try embeddedBackendScript.write(toFile: tempPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempPath)
            }
        } catch {
            throw DoclingBackendServiceError.backendScriptNotFound
        }

        return tempPath
    }

    private static let embeddedBackendScript = #"""
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys


def emit(payload):
    print(json.dumps(payload, ensure_ascii=True))


def import_docling_parse():
    from docling_parse.pdf_parser import DoclingPdfParser  # type: ignore
    return DoclingPdfParser


def cmd_health():
    payload = {"ok": False, "python": sys.version.split()[0], "docling": False}
    try:
        import_docling_parse()
        payload["ok"] = True
        payload["docling"] = True
        emit(payload)
        return 0
    except Exception as exc:
        payload["error"] = str(exc)
        emit(payload)
        return 2


def extract_text(docling_parser_type, pdf_path):
    parser = docling_parser_type()
    document = parser.load(pdf_path, lazy=False)
    total_pages = int(document.number_of_pages())
    if total_pages <= 0:
        raise RuntimeError("No pages were extracted")

    def normalize_page(page_item):
        if hasattr(page_item, "iterate_cells"):
            return page_item
        if isinstance(page_item, tuple):
            for candidate in page_item:
                if hasattr(candidate, "iterate_cells"):
                    return candidate
        raise RuntimeError("Unexpected page shape returned by docling parser")

    def page_cells(page):
        unit_type = page.iterate_cells.__annotations__.get("unit_type")
        if unit_type is None:
            raise RuntimeError("Docling page API missing unit_type annotation")

        unit_candidates = [
            getattr(unit_type, "LINE", None),
            getattr(unit_type, "WORD", None),
            getattr(unit_type, "CHAR", None),
        ]

        for candidate in unit_candidates:
            if candidate is None:
                continue
            try:
                cells = list(page.iterate_cells(candidate))
                if cells:
                    return cells
            except Exception:
                continue

        return []

    def normalize_lines(raw_lines):
        cleaned = []
        bullet_pending = False

        for raw in raw_lines:
            line = re.sub(r"\s+", " ", raw).strip()
            if not line:
                continue
            if re.fullmatch(r"[.\s]{2,}", line):
                continue

            if line in {"•", "-"}:
                bullet_pending = True
                continue

            if bullet_pending:
                cleaned.append(f"• {line}")
                bullet_pending = False
            else:
                cleaned.append(line)

        return cleaned

    raw_parts = []
    for page_item in document.iterate_pages():
        page = normalize_page(page_item)
        cells = page_cells(page)
        if cells:
            for cell in cells:
                text = str(getattr(cell, "text", "") or "").strip()
                if text:
                    raw_parts.append(text)

    parts = normalize_lines(raw_parts)

    full_text = "\\n".join(parts).strip()
    if not full_text:
        raise RuntimeError("Docling extracted no text")
    return full_text


def cmd_extract(pdf_path):
    try:
        docling_parser_type = import_docling_parse()
        text = extract_text(docling_parser_type, pdf_path)
        emit({"ok": True, "text": text})
        return 0
    except Exception as exc:
        emit({"ok": False, "error": str(exc)})
        return 1


def build_parser():
    parser = argparse.ArgumentParser(prog="docling_backend")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("health")
    extract_parser = subparsers.add_parser("extract")
    extract_parser.add_argument("--pdf", required=True)
    return parser


def main():
    args = build_parser().parse_args()
    if args.command == "health":
        return cmd_health()
    if args.command == "extract":
        return cmd_extract(args.pdf)
    emit({"ok": False, "error": "Unsupported command"})
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
"""#
}

private struct ProcessResult {
    let stdout: String
    let stderr: String
}
