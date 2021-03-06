//
//  WebView.swift
//  PortButler
//
//  Created by Albin Ekblom on 2020-07-27.
//  Copyright © 2020 Albin Ekblom. All rights reserved.
//

import AppKit
import Combine
import SwiftUI
import WebKit

import SwiftSoup

public struct WebBrowserView {
    private let webView = WKWebView(frame: .zero)

    // ...

    public func load(url: URL) {
        print(url)
        webView.load(URLRequest(url: url))
    }

    public func getTitle() -> String {
        webView.title ?? "None"
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebBrowserView

        init(parent: WebBrowserView) {
            self.parent = parent
        }

        public func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            // ...
            print("webview error")
        }

        public func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            // ...
        }

        public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            parent.didFinish(title: webView.title!)
        }

        public func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            // ...
        }

        public func webView(_: WKWebView, decidePolicyFor _: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView, createWebViewWith _: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures _: WKWindowFeatures) -> WKWebView? {
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

        public func updateNSView(_: WKWebView, context _: NSViewRepresentableContext<WebBrowserView>) {}

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

        public func load(url: URL) {
            DispatchQueue.global().async {
                do {
                    let contents = try String(contentsOf: url)
                    let doc: Document = try SwiftSoup.parseBodyFragment(contents)

                    let title = try doc.title()
                    DispatchQueue.main.async {
                        if title.count > 1 {
                            self.title = title
                            self.isLoading = false
                            self.isDone = true
                            self.webView = nil
                        }
                    }

                } catch {
                    guard let webView = self.webView else { return }
                    webView.navigationDelegate = self
                    webView.load(URLRequest(url: url))
                    // webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
                    webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
                }
            }
        }

        override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
            guard let webView = self.webView else { return }

            if keyPath == "title" {
                guard let title = webView.title else {
                    self.title = "Error"
                    return
                }
                maybeUpdateTitle(title)
            }
            if keyPath == "estimatedProgress" {
                estimatedProgress = webView.estimatedProgress
            }
        }

        public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            isLoading = false
            guard let title = webView.title else {
                self.title = "Error"
                return
            }
            maybeUpdateTitle(title)
        }

        public func unload() {
            webView = nil
            isDone = true
        }

        func maybeUpdateTitle(_ title: String) {
            if title.count > 2 {
                self.title = title

                isDone = true
                webView = nil

            } else if self.title.count == 0 {
                self.title = "-"
            }
        }
    }

    extension String: Error {}

    struct BrowserTitleView: View {
        let NC = NotificationCenter.default
        var port: Int
        @ObservedObject private var webView = ObservableWebView()

        var body: some View {
            AnyView(
                Group {
                    if self.webView.isLoading {
                        ProgressIndicator {
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
            ).onAppear {
                self.handleAppearObserver(nil)
                self.NC.addObserver(forName: NSNotification.RefreshWebView, object: nil, queue: nil,
                                    using: self.handleAppearObserver)
            }
            .onDisappear {
                self.NC.removeObserver(self)
                self.webView.unload()
            }
        }

        func handleAppearObserver(_: Notification?) {
            loadWebView()
        }

        func loadWebView() {
            guard let url = URL(string: "http://127.0.0.1:" + String(port)) else {
                print("Error getting URL from port:")
                print(port)
                return
            }
            webView.load(url: url)
        }
    }

#endif
