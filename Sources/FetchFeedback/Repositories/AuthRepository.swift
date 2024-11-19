import Foundation
import Utils

final class SpaceAuth {

    static let command = "/bin/bash"

    static func refreshAuth() async throws {
  
        let email = ProcessInfo.processInfo.environment["FASTLANE_EMAIL"]
        guard let email = email, !email.isEmpty else {
            print("FASTLANE_EMAIL is not set..", color: .yellow)
            return
        }
        // Create a Process to run the command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = ["-c", "fastlane spaceauth -u \(email)"]
        // Create a Pipe to capture the output
        let pipe = Pipe()
        process.standardOutput = pipe

        // Variable to store the matched line
        var fastlaneSession: String?

        do {
            // Launch the process
          
            try process.run()

            // Create a file handle for reading the output
            let fileHandle = pipe.fileHandleForReading
            var isCompleted:Bool = false
            var foundSessionPrefex = false
            // Process the output in real time
            fileHandle.readabilityHandler = { handle in
                if let inString = String(data: handle.availableData, encoding: .utf8) {
                    // Split the output into lines
                    let lines = inString.components(separatedBy: .newlines)
                    //loop through the lines
                    for line in lines {
                        // print(line)
                        // Check if the line starts with "export FASTLANE_SESSION="
                        if isCompleted {
                            break
                        }
                        if foundSessionPrefex && !line.isEmpty {
                            // Capture the line in the variable
                            fastlaneSession = line
                            print("Captured session Auth")
                            Environment.fastLaneOverride = line

                            // Stop monitoring the output
                            isCompleted = true
                            process.terminate()
                            break
                        }
                        else if line.hasPrefix(
                            "Pass the following via the FASTLANE_SESSION environment variable:")
                        {
                            foundSessionPrefex = true
                        }
                    }
                }
            }
            
            // Wait for the process to complete
            process.waitUntilExit()

            // Print the captured session
            if let session = fastlaneSession {
                print("Refreshed Auth")
            } else {
                print("No session found.")
            }
        } catch {
            print("Failed to run the process: \(error)")
        }
    }
}
