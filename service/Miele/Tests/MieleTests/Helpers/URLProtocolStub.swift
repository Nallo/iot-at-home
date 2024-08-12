//
//  URLProtocolStub.swift
//  MieleTests
//
//  Created by Stefano Martinallo on 27/07/24.
//

import Foundation

class URLProtocolStub: URLProtocol {

    private static var stub: Stub?
    private static var requestObserver: ((URLRequest) -> Void)?
    private static var taskObserver: ((URLSessionTask) -> Void)?

    private struct Stub {
        let data: Data?
        let response: HTTPURLResponse?
        let error: Error?
    }

    static func startInterceptingRequests() {
        URLProtocol.registerClass(URLProtocolStub.self)
    }

    static func stopInterceptingRequests() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        stub = nil
        requestObserver = nil
        taskObserver = nil
    }

    static func stub(url: URL, data: Data? = nil, response: HTTPURLResponse? = nil, error: Error? = nil) {
        stub = Stub(data: data, response: response, error: error)
    }

    static func observeRequests(observer: @escaping (URLRequest) -> Void) {
        requestObserver = observer
    }

    static func observeTasks(observer: @escaping (URLSessionTask) -> Void) {
        taskObserver = observer
    }

    override class func canInit(with request: URLRequest) -> Bool {
        requestObserver?(request)
        return true
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        taskObserver?(task)
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let response = URLProtocolStub.stub?.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = URLProtocolStub.stub?.data {
            client?.urlProtocol(self, didLoad: data)
        }

        if let error = URLProtocolStub.stub?.error {
            client?.urlProtocol(self, didFailWithError: error)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

}
