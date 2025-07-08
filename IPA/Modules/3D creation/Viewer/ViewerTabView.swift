//  ViewerTabView.swift
//  View embedding a WKWebView to interact with an online 3D viewer and extract measurements.

import SwiftUI
import WebKit

struct ViewerTabView: View {
    @EnvironmentObject var objScalerViewModel: OBJScalerViewModel
    @StateObject private var viewerViewModel = ViewerViewModel.shared
    
    var body: some View {
        VStack {
            // Embedded web view displaying the 3D viewer
            WebViewContainer(webView: viewerViewModel.webView)
                .frame(minWidth: 800, minHeight: 600)
            
            // Action buttons
            HStack {
                Button("Reload page") {
                    viewerViewModel.reload()
                }
                .padding()
                
                Button("Extract measure") {
                    viewerViewModel.retrieveMeasureValue { measureValue in
                        if let value = measureValue {
                            objScalerViewModel.uncalibrated = value
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// Wrapper for embedding a WKWebView into SwiftUI
struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView?
    
    func makeNSView(context: Context) -> WKWebView {
        if let existingWebView = webView {
            return existingWebView
        }
        return WKWebView()
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
    }
}
