//
//  HTTPClientSpy.swift
//  MieleTests
//
//  Created by Stefano Martinallo on 21/07/2024.
//

import XCTest
import Miele

final class HTTPClientSpy: HTTPClient {

    private(set) var requestedUrls: [URL] = []
    private(set) var requestedHttpVerbs: [String] = []
    private(set) var requestedHeaders = [String: String]()

    private var messages = [(url: URL, completion: (HTTPClient.Result) -> Void)]()

    func get(url: URL, headers: [String: String], completion: @escaping (HTTPClient.Result) -> Void) {
        requestedUrls.append(url)
        requestedHeaders = headers
        requestedHttpVerbs.append("GET")
        messages.append((url, completion))
    }

    func complete(with error: Error, at index: Int = 0, file: StaticString = #filePath, line: UInt = #line) {
        guard messages.count > index else {
            return XCTFail("Can't complete request never made", file: file, line: line)
        }

        messages[index].completion(.failure(error))
    }

    func complete(withStatusCode code: Int, data: Data, at index: Int = 0, file: StaticString = #filePath, line: UInt = #line) {
        guard messages.count > index else {
            return XCTFail("Can't complete request never made", file: file, line: line)
        }

        let response = HTTPURLResponse(
            url: requestedUrls[index],
            statusCode: code,
            httpVersion: nil,
            headerFields: nil)!

        messages[index].completion(.success((data, response)))
    }

}
