import Foundation

class SSHClient {
    let host: String
    let port: Int
    let username: String
    let authMethod: String
    let keyPath: String?
    let password: String?

    init(config: ServerConfig) {
        self.host = config.host
        self.port = config.port
        self.username = config.username
        self.authMethod = config.authMethod
        self.keyPath = config.keyPath
        self.password = config.password
    }

    func executeCommand(_ command: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        var sshCommand = ["ssh"]

        sshCommand.append("-p")
        sshCommand.append("\(port)")

        if let keyPath = keyPath {
            let expandedPath = NSString(string: keyPath).expandingTildeInPath
            sshCommand.append("-i")
            sshCommand.append(expandedPath)
        }

        sshCommand.append("-o")
        sshCommand.append("StrictHostKeyChecking=no")
        sshCommand.append("-o")
        sshCommand.append("ConnectTimeout=10")

        sshCommand.append("\(username)@\(host)")
        sshCommand.append(command)

        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = Array(sshCommand.dropFirst())
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SSHError.commandFailed(errorString)
        }

        guard let output = String(data: data, encoding: .utf8) else {
            throw SSHError.invalidOutput
        }

        return output
    }

    func getGPUInfo() async throws -> [GPUInfo] {
        let command = "nvidia-smi --query-gpu=index,name,temperature.gpu,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits"

        let output = try await executeCommand(command)

        var gpus: [GPUInfo] = []

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            guard parts.count >= 6 else { continue }

            guard let index = Int(parts[0]),
                  let temperature = Int(parts[2]),
                  let memoryUsed = Int(parts[3]),
                  let memoryTotal = Int(parts[4]),
                  let utilization = Int(parts[5]) else {
                continue
            }

            let gpu = GPUInfo(
                index: index,
                name: parts[1],
                temperature: temperature,
                memoryUsed: memoryUsed,
                memoryTotal: memoryTotal,
                utilization: utilization
            )

            gpus.append(gpu)
        }

        return gpus
    }
}

enum SSHError: Error {
    case commandFailed(String)
    case invalidOutput
    case connectionFailed
}
