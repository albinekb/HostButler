//
//  WebView.swift
//  PortButler
//
//  Created by Albin Ekblom on 2020-07-27.
//  Copyright © 2020 Albin Ekblom. All rights reserved.
//


import WebKit
import Combine
import SwiftUI
import AppKit


public struct WebBrowserView {

    private let webView: WKWebView = WKWebView(frame: .zero)
    

    // ...

    public func load(url: URL) {
        print(url)
        webView.load(URLRequest(url: url))
    }
    
    public func getTitle () -> String {
        webView.title ?? "None"
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        var parent: WebBrowserView

        init(parent: WebBrowserView) {
            self.parent = parent
        }

        public func webView(_: WKWebView, didFail: WKNavigation!, withError: Error) {
            // ...
            print("webview error")
        }

        public func webView(_: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error) {
            // ...
        }

        public func webView(_ webView: WKWebView, didFinish: WKNavigation!) {
            parent.didFinish(title: webView.title!)
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // ...
        }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
}


#if os(macOS) // macOS Implementation (iOS version omitted for brevity)
extension WebBrowserView: NSViewRepresentable {

    public typealias NSViewType = WKWebView

    public func makeNSView(context: NSViewRepresentableContext<WebBrowserView>) -> WKWebView {

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<WebBrowserView>) {

    }
    public func didFinish(title: String) {
        print(title)
    }
}

class ObservableWebView: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var title: String = ""
    @Published var isLoading: Bool = true
    @Published var estimatedProgress: Double = 0
    private var isDone: Bool = false
    private var webView: WKWebView? = WKWebView(frame: .zero)
    
    public func load(url: URL){
        guard let webView = self.webView else {return}
        webView.navigationDelegate = self
        webView.load(URLRequest(url: url))
        //webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = self.webView else {return}
        if keyPath == "title" {
            guard let title = webView.title else {
                self.title = "Error"
                return
            }
            self.maybeUpdateTitle(title)
        }
        if keyPath == "estimatedProgress" {
            self.estimatedProgress = webView.estimatedProgress
        }
    }
    public func webView(_ webView: WKWebView, didFinish: WKNavigation!) {
        self.isLoading = false
        guard let title = webView.title else {
            self.title = "Error"
            return
        }
        self.maybeUpdateTitle(title)
    }
    
    public func unload () {
        self.webView = nil
        self.isDone = true
    }
    
    func maybeUpdateTitle (_ title: String) {
        if title.count > 2 {
            self.title = title

            self.isDone = true
            self.webView = nil

         } else if self.title.count == 0 {
             self.title = "-"
         }
    }
}

struct BrowserTitleView: View {
    let NC = NotificationCenter.default
    var port: Int
    @ObservedObject private var webView = ObservableWebView()
    
    var body: some View {
        AnyView(
            Group{
                if self.webView.isLoading  {
                    ProgressIndicator{
                        $0.style = .spinning
                        $0.sizeToFit()
                        $0.usesThreadedAnimation = true
                        $0.startAnimation(nil)
                        $0.controlSize = .small
                    }
                } else {
                    Text(self.webView.title).lineLimit(2).font(.system(size: 12, weight: .regular))
                }
            }
        ).onAppear{
            self.NC.addObserver(forName: NSNotification.ViewDidAppear, object: nil, queue: nil,
            using: self.handleAppearObserver)
        }
        .onDisappear{
            print("Hello")
            self.NC.removeObserver(self)
            self.webView.unload()
        }
    }
    
    func handleAppearObserver(_ notification: Notification) {
        print("handleObserver")
        self.loadWebView()
    }
    
    func loadWebView () {
        print("handleAppear")
        guard let url = URL(string: "http://localhost:" + String(self.port)) else {
            print("Error getting URL from port:")
            print(self.port)
            return
        }
        self.webView.load(url: url)
    }
}

//struct BrowserView: View {
//    private let browser = WebBrowserView()
//    var port: Int
//
//    var body: some View {
//        HStack {
//            browser
//                .onAppear() {
//                    self.browser
//                        .load(url: URL(string: "http://localhost:" + String(self.port))!)
//            }.frame(width:0,height: 0)
//
//
//        }
//        .padding()
//    }
//}
#endif
