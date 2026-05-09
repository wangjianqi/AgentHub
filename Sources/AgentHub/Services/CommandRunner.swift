import Foundation

struct CommandRunner {
    static func which(_ executable: String) -> String? {
        let result = run("/usr/bin/which", arguments: [executable], timeout: 3)
        guard result.exitCode == 0 else { return nil }
        return result.stdout.trimmed.nilIfEmpty
    }

    static func version(command: String, candidates: [[String]]) -> String? {
        for args in candidates {
            let result = run(command, arguments: args, timeout: 4)
            if result.exitCode == 0, let output = (result.stdout + result.stderr).firstNonEmptyLine(maxLength: 100) {
                return output
            }
        }
        return nil
    }

    static func run(_ launchPath: String, arguments: [String], timeout: TimeInterval) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
        }

        let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return CommandResult(exitCode: Int(process.terminationStatus), stdout: stdout, stderr: stderr)
    }
}

struct CommandResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
