import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var status: String = "iPhone not ready"
    @State private var session: WCSession = WCSession.default
    @State private var delegate: WatchSessionDelegate?
    
    var body: some View {
        VStack {
            Text(status)
                .padding()
        }
        .onAppear {
            let delegate = WatchSessionDelegate(status: $status)
            session.delegate = delegate
            self.delegate = delegate // Store the delegate to prevent deallocation
            session.activate()
        }
    }
}

class WatchSessionDelegate: NSObject, WCSessionDelegate {
    @Binding var status: String
    
    init(status: Binding<String>) {
        _status = status
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.status = session.isReachable ? "Connection established" : "iPhone not ready"
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let filePath = message["filePath"] as? String {
            DispatchQueue.main.async {
                self.status = "File request received"
            }
            sendFileContents(filePath: filePath, session: session)
        }
    }
    
    func sendFileContents(filePath: String, session: WCSession) {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        let fileURL = URL(fileURLWithPath: filePath)
        
        if fileManager.fileExists(atPath: filePath, isDirectory: &isDir) {
            if isDir.boolValue {
                sendDirectoryContents(at: fileURL, session: session)
            } else {
                sendFile(at: fileURL, session: session)
            }
        } else {
            DispatchQueue.main.async {
                self.status = "File is unavailable or path is incorrect"
            }
            session.sendMessage(["error": "File is unavailable or path is incorrect"], replyHandler: nil, errorHandler: nil)
        }
    }
    
    func sendFile(at fileURL: URL, session: WCSession, relativePath: String? = nil) {
        do {
            let fileData = try Data(contentsOf: fileURL)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileURL.lastPathComponent)
            try fileData.write(to: tempURL)
            var metadata: [String: Any] = [:]
            if let relativePath = relativePath {
                metadata["relativePath"] = relativePath
            }
            session.transferFile(tempURL, metadata: metadata)
            DispatchQueue.main.async {
                self.status = "Sending file"
            }
        } catch {
            DispatchQueue.main.async {
                self.status = "Failed to read file"
            }
            session.sendMessage(["error": "Failed to read file"], replyHandler: nil, errorHandler: nil)
        }
    }
    
    func sendDirectoryContents(at directoryURL: URL, session: WCSession, relativePath: String? = nil) {
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let totalFiles = fileURLs.count
            session.sendMessage(["totalFiles": totalFiles], replyHandler: nil, errorHandler: nil)
            for fileURL in fileURLs {
                let relativeFilePath = relativePath != nil ? "\(relativePath!)/\(fileURL.lastPathComponent)" : fileURL.lastPathComponent
                sendFile(at: fileURL, session: session, relativePath: relativeFilePath)
            }
            DispatchQueue.main.async {
                self.status = "Sending directory contents"
            }
        } catch {
            DispatchQueue.main.async {
                self.status = "Failed to read directory"
            }
            session.sendMessage(["error": "Failed to read directory"], replyHandler: nil, errorHandler: nil)
        }
    }
}
