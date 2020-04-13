//
//  TpaAuthViewController.swift
//  edX
//
//  Created by Jillian Vogel on 2020-04-14
//

import Foundation

class TpaAuthViewController: UIViewController, UIWebViewDelegate, InterfaceOrientationOverriding {

    typealias Environment = OEXAnalyticsProvider & OEXConfigProvider & OEXStylesProvider
    private let environment: Environment

    private let loadController = LoadStateViewController()
    let webView = UIWebView()
    var request: URLRequest?

    init(environment : Environment) {
        self.environment = environment

        super.init(nibName: nil, bundle: nil)

        automaticallyAdjustsScrollViewInsets = false

        if let hostURL = environment.config.apiHostURL() {
          if let components = NSURLComponents(string:hostURL.absoluteString) {
            // FIXME JV
            // put into OEXNetworkConstants, and make the parts configurable
            components.path = "/auth/login/tpa-saml"
            components.queryItems = [
                NSURLQueryItem(name:"auth_entry", value:"login"),
                NSURLQueryItem(name:"next", value:"/"),
                NSURLQueryItem(name:"idp", value:"cloudera"),
            ] as [URLQueryItem]

            if let url = components.url {
                let mutableRequest = NSMutableURLRequest(url:url)
                mutableRequest.httpShouldHandleCookies = true
                self.request = mutableRequest as URLRequest
            }
          }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalTo(safeEdges)
        }

        webView.delegate = self

        loadController.setupInController(controller: self, contentView: webView)
        webView.backgroundColor = OEXStyles.shared().standardBackgroundColor()

        // FIXME JV move to Strings const
        title = "External Authentication"
        loadController.state = .Initial

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        environment.analytics.trackScreen(withName: OEXAnalyticsScreenCertificate)
        if let request = self.request {
            webView.loadRequest(request)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.stopLoading()
    }

    // MARK: - Web view delegate

    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        loadController.state = LoadState.failed(error: error as NSError)
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        loadController.state = .Loaded
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.allButUpsideDown
    }
}

