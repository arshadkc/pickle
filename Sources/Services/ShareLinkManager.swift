import Foundation
import AppKit

final class ShareLinkManager: ObservableObject {
    static let shared = ShareLinkManager()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    
    private var currentUploadTask: URLSessionUploadTask?
    private let apiBaseURL = "https://api.pickleformac.app/api"
    private let apiKey = "dev-api-key-12345" // TODO: Move to secure storage
    
    private init() {}
    
    // Removed legacy createShareLink(for:) in favor of createShareLinkWithProgress
    
    // Returns upload task via onTask callback so callers can cancel
    func createShareLinkWithProgress(for fileURL: URL, onTask: @escaping (URLSessionUploadTask) -> Void, progressCallback: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        guard !isUploading else {
            completion(false)
            return
        }
        
        let contentType = getContentType(for: fileURL)
        
        // Step 1: Call API to get presigned upload + share URLs
        callCreateAPI(contentType: contentType) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Step 2: Copy link immediately and start upload in parallel
                    self?.copyToClipboard(response.shareUrl)
                    DispatchQueue.main.async {
                        ToastCenter.shared.info("Link copied", subtitle: nil, duration: 1.6)
                    }
                    
                    // Progress is shown locally on the tile; no global persistent progress toast
                    self?.startBackgroundUploadWithProgress(fileURL: fileURL, uploadURL: response.uploadUrl, onTask: onTask, progressCallback: progressCallback, completion: completion)
                case .failure(let error):
                    self?.handleAPIError(error)
                    completion(false)
                }
            }
        }
    }
    
    private func callCreateAPI(contentType: String, completion: @escaping (Result<APIResponse, Error>) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)/create") else {
            completion(.failure(ShareLinkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let requestBody = CreateRequest(contentType: contentType)
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(ShareLinkError.noData))
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                completion(.success(apiResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func handleAPIError(_ error: Error) {
        DispatchQueue.main.async {
            ToastCenter.shared.error("Failed to create share link", subtitle: "Please try again")
        }
        print("ShareLink API Error: \(error)")
    }
    
    // Removed legacy startBackgroundUpload in favor of startBackgroundUploadWithProgress
    
    private func startBackgroundUploadWithProgress(fileURL: URL, uploadURL: String, onTask: @escaping (URLSessionUploadTask) -> Void, progressCallback: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        guard let uploadURL = URL(string: uploadURL) else {
            DispatchQueue.main.async {
                ToastCenter.shared.error("Invalid upload URL", subtitle: nil)
            }
            completion(false)
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(getContentType(for: fileURL), forHTTPHeaderField: "Content-Type")
        request.setValue("public, max-age=31536000, immutable", forHTTPHeaderField: "Cache-Control")
        request.setValue("inline; filename=\"\(fileURL.lastPathComponent)\"", forHTTPHeaderField: "Content-Disposition")
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            
            // Create a custom URLSession with progress tracking
            let config = URLSessionConfiguration.default
            let delegate = UploadProgressDelegateWithCallback(progressCallback: progressCallback) { [weak self] success in
                DispatchQueue.main.async {
                    self?.isUploading = false
                    if success {
                        ToastCenter.shared.success("Uploaded — link is live", subtitle: nil)
                    } else {
                        ToastCenter.shared.error("Upload failed", subtitle: "Please try again")
                    }
                    completion(success)
                }
            }
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            
            let task = session.uploadTask(with: request, from: fileData)
            currentUploadTask = task
            onTask(task)
            task.resume()
        } catch {
            isUploading = false
            DispatchQueue.main.async {
                ToastCenter.shared.error("Failed to read file", subtitle: "Please try again")
            }
            completion(false)
        }
    }
    
    // Removed legacy handleUploadCompletion (used by old delegate path)
    
    // Progress updates are provided via callback from UploadProgressDelegateWithCallback
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    // Legacy showToast removed in favor of ToastCenter
    
    private func getContentType(for fileURL: URL) -> String {
        let pathExtension = fileURL.pathExtension.lowercased()
        switch pathExtension {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        default:
            return "image/png"
        }
    }
    
    // Removed retryUpload() — re-share from context menu instead
}

// MARK: - Data Models

struct CreateRequest: Codable {
    let contentType: String
}

struct APIResponse: Codable {
    let id: String
    let key: String
    let encodedKey: String
    let uploadUrl: String
    let shareUrl: String
    let publicUrlPreview: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case key
        case encodedKey
        case uploadUrl
        case shareUrl
        case publicUrlPreview
        case expiresAt
    }
}

enum ShareLinkError: Error, LocalizedError {
    case invalidURL
    case noData
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .uploadFailed:
            return "Upload failed"
        }
    }
}

// MARK: - Upload Progress Delegate (callback-based)

class UploadProgressDelegateWithCallback: NSObject, URLSessionTaskDelegate {
    private let progressCallback: (Double) -> Void
    private let completion: (Bool) -> Void
    
    init(progressCallback: @escaping (Double) -> Void, completion: @escaping (Bool) -> Void) {
        self.progressCallback = progressCallback
        self.completion = completion
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressCallback(progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let success = error == nil && (task.response as? HTTPURLResponse)?.statusCode ?? 0 < 400
        completion(success)
    }
}
