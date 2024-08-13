//
//  URLSessionHTTPClient.swift
//  Miele
//
//  Created by Stefano Martinallo on 27/07/2024.
//

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Foundation

final class SessionDelegate: NSObject, URLSessionDataDelegate {

    private var completion: ((HTTPClient.Result) -> Void)?

    func setCompletion(_ completion: @escaping (HTTPClient.Result) -> Void) {
        self.completion = completion
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let httpResponse = dataTask.response as? HTTPURLResponse else { return }
        completion?(.success((data, httpResponse)))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error = error else { return }
        completion?(.failure(error))
    }

}

public final class URLSessionHTTPClient: HTTPClient {

    private let delegate: SessionDelegate
    private let session: URLSession

    public init(session: URLSession) {
        self.delegate = SessionDelegate()
        self.session = URLSession(
            configuration: session.configuration,
            delegate: self.delegate,
            delegateQueue: .main)
    }

    public func get(url: URL, headers: [String : String], completion: @escaping (HTTPClient.Result) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        delegate.setCompletion(completion)
        session.dataTask(with: request).resume()
    }

}

public final class VerboseHTTPClientDecorator: HTTPClient {

    private let decoratee: HTTPClient

    public init(decoratee: HTTPClient) {
        self.decoratee = decoratee
    }

    public func get(url: URL, headers: [String : String], completion: @escaping (HTTPClient.Result) -> Void) {
        decoratee.get(url: url, headers: headers) { result in
            print(Date().description(with: .current))

            switch result {

            case let .success((data, _)):
                print(String(data: data, encoding: .ascii) ?? "")

            case let .failure(error):
                print(error)
            }

            completion(result)
        }
    }

}
