//  ViewerViewModel.swift
//  Singleton ViewModel managing the embedded WKWebView and extracting measurement values from the 3D viewer.

import SwiftUI
import WebKit

class ViewerViewModel: ObservableObject {
    // Shared singleton instance
    static let shared = ViewerViewModel()
    
    // Embedded web view used for 3D viewing
    @Published var webView: WKWebView?
    private var isInitialized = false
    
    private init() {
        setupWebView()
    }
    
    // Initializes and loads the default 3D viewer URL
    private func setupWebView() {
        if !isInitialized {
            let webView = WKWebView()
            webView.load(URLRequest(url: URL(string: "https://3dviewer.net")!))
            self.webView = webView
            isInitialized = true
        }
    }
    
    // Reloads the current page
    func reload() {
        webView?.reload()
    }
    
    // Executes JavaScript to extract the value of the first element with class '.ov_measure_value'
    func retrieveMeasureValue(completion: @escaping (String?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }
        
        if webView.isLoading {
            print("Page is loading, retry in 1 sec.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.retrieveMeasureValue(completion: completion)
            }
            return
        }
        
        let js = "document.querySelectorAll('.ov_measure_value')[0]?.textContent"
        webView.evaluateJavaScript(js) { (result, error) in
            if let error = error {
                print("JS error: \(error)")
                completion(nil)
                return
            }
            if let measureValue = result as? String {
                print("Extracted measurement value: \(measureValue)")
                completion(measureValue)
            } else {
                print("No result found for .ov_measure_value")
                completion(nil)
            }
        }
    }
} 
