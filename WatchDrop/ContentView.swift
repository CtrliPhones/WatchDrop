import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var filePath: String = ""
    @State private var session: WCSession = WCSession.default
    @State private var delegate: WatchSessionDelegate?
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var progress: Double = 0.0
    @State private var isButtonDisabled: Bool = true
    @State private var receivedFilesCount: Int = 0
    @State private var totalFilesCount: Int = 0
    
    var body: some View {
        VStack {
            TextField("Enter a file path", text: $filePath)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Queue File Fetch") {
                sendPathToWatch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isButtonDisabled)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
            
            Text("Files received: \(receivedFilesCount) / \(totalFilesCount)")
                .padding()
            
            Button("Reset Connection") {
                resetConnection()
            }
            .buttonStyle(.bordered)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Transfer Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            let delegate = WatchSessionDelegate(onFileSaved: { message, progress, receivedFiles, totalFiles in
                self.alertMessage = message
                self.showAlert = true
                self.progress = progress
                self.receivedFilesCount = receivedFiles
                self.totalFilesCount = totalFiles
            })
            session.delegate = delegate
            self.delegate = delegate // Store the delegate to prevent deallocation
            session.activate()
        }
        .onChange(of: session.isReachable) { reachable in
            isButtonDisabled = !reachable
        }
    }
    
    func sendPathToWatch() {
        if session.isReachable {
            session.sendMessage(["filePath": filePath], replyHandler: nil) { error in
                self.alertMessage = "Error sending message: \(error.localizedDescription)"
                self.showAlert = true
            }
        }
    }
    
    func resetConnection() {
        session.delegate = nil
        session.activate()
        session.delegate = delegate
        alertMessage = "Connection reset"
        showAlert = true
    }
}

class WatchSessionDelegate: NSObject, WCSessionDelegate {
    private var onFileSaved: ((String, Double, Int, Int) -> Void)?
    private var totalFilesCount = 0
    private var receivedFilesCount = 0
    
    init(onFileSaved: @escaping (String, Double, Int, Int) -> Void) {
        self.onFileSaved = onFileSaved
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fileURL = file.fileURL
        saveFileToDocumentsDirectory(fileURL, relativePath: file.metadata?["relativePath"] as? String)
    }
    
    private func saveFileToDocumentsDirectory(_ fileURL: URL, relativePath: String?) {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = relativePath != nil ? documentsDirectory.appendingPathComponent(relativePath!) : documentsDirectory.appendingPathComponent(fileURL.lastPathComponent)
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            self.receivedFilesCount += 1
            let progress = Double(self.receivedFilesCount) / Double(self.totalFilesCount)
            DispatchQueue.main.async {
                self.onFileSaved?("", progress, self.receivedFilesCount, self.totalFilesCount)
                if self.receivedFilesCount == self.totalFilesCount {
                    self.onFileSaved?("Transfer complete", progress, self.receivedFilesCount, self.totalFilesCount)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.onFileSaved?("Failed to save file: \(error.localizedDescription)", 0.0, self.receivedFilesCount, self.totalFilesCount)
            }
        }
    }
    
    func updateFileCounts(totalFiles: Int) {
        self.totalFilesCount = totalFiles
        self.receivedFilesCount = 0
        DispatchQueue.main.async {
            self.onFileSaved?("", 0.0, self.receivedFilesCount, self.totalFilesCount)
        }
    }
}
