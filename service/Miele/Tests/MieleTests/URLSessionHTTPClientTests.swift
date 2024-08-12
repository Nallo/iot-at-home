//
//  URLSessionHTTPClientTests.swift
//  MieleTests
//
//  Created by Stefano Martinallo on 27/07/2024.
//

import XCTest
import Miele


final class URLSessionHTTPClientTests: XCTestCase {

    override func setUp() {
        super.setUp()

        URLProtocolStub.startInterceptingRequests()
    }

    override func tearDown() {
        super.tearDown()

        URLProtocolStub.stopInterceptingRequests()
    }

    func test_get_performsGETequestWithURL() {
        let url = anyURL()
        var expectedRequest = URLRequest(url: url)
        expectedRequest.httpMethod = "GET"

        let sut = makeSUT()

        expectRequest(toBe: expectedRequest, when: {
            sut.get(url: url, headers: [:]) { _ in }
        })
    }

    func test_get_performsGETequestWithGivenHttpHeaders() {
        let url = anyURL()
        let headers = [
            "header-key-1": "header-value-1",
            "header-key-2": "header-value-2",
            "header-key-3": "header-value-3",
        ]
        var expectedRequest = URLRequest(url: url)
        headers.forEach { expectedRequest.addValue($0.value, forHTTPHeaderField: $0.key) }

        let sut = makeSUT()

        expectRequest(toBe: expectedRequest, when: {
            sut.get(url: url, headers: headers) { _ in }
        })
    }

    func test_get_deliversErrorWhenRequestFails() {
        let url = anyURL()
        let expectedError = NSError(domain: "Test", code: 0)
        let sut = makeSUT()

        expectGET(fromURL: url, with: sut, toCompleteWith: .failure(expectedError), when: {
            URLProtocolStub.stub(url: url, data: nil, response: nil, error: expectedError)
        })
    }

    func test_get_deliversSuccessWithDataAndResponseWhenRequestSucceedsWithResponseBody() {
        let url = anyURL()
        let expectedData = "Test data".data(using: .ascii)!
        let expectedResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

        expectGET(fromURL: url, with: makeSUT(), toCompleteWith: .success((expectedData, expectedResponse)), when: {
            URLProtocolStub.stub(url: url, data: expectedData, response: expectedResponse, error: nil)
        })
    }

    // MARK: Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let sut = URLSessionHTTPClient(session: session)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    func expectRequest(toBe expectedRequest: URLRequest, when action: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Wait for request")

        URLProtocolStub.observeTasks { receivedTask in
            let receivedRequest = receivedTask.originalRequest!
            XCTAssertEqual(expectedRequest.url, receivedRequest.url, file: file, line: line)
            XCTAssertEqual(expectedRequest.httpMethod, receivedRequest.httpMethod, file: file, line: line)
            //                XCTAssertEqual(expectedRequest.httpBodyData, receivedRequest.httpBodyData, file: file, line: line)

            expectedRequest.allHTTPHeaderFields?.keys.forEach {
                XCTAssertNotNil(receivedRequest.allHTTPHeaderFields?[$0], "expected \($0) key not found in HTTP headers", file: file, line: line)
                let headerValue = expectedRequest.allHTTPHeaderFields?[$0]
                XCTAssertEqual(headerValue, receivedRequest.allHTTPHeaderFields?[$0], "expceted \(headerValue ?? "") value for key \($0) not found in HTTP headers", file: file, line: line)
            }

            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 0.1)
    }

    func expectGET(fromURL url: URL, with sut: URLSessionHTTPClient, toCompleteWith expectedResult: HTTPClient.Result, when action: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {

        action()

        let exp = expectation(description: "wait for completion")

        sut.get(url: url, headers: [:]) { receivedResult in
            switch (expectedResult, receivedResult) {
            case let (.success((expectedData, expectedResponse)), .success((receivedData, receivedResponse))):
                XCTAssertEqual(expectedResponse.url, receivedResponse.url, file: file, line: line)
                XCTAssertEqual(expectedResponse.statusCode, receivedResponse.statusCode, file: file, line: line)
                XCTAssertEqual(expectedData.base64EncodedData(), receivedData.base64EncodedData(), file: file, line: line)

            case let (.failure(receivedError as NSError), .failure(expectedError as NSError)):
                XCTAssertEqual(receivedError.code, expectedError.code, file: file, line: line)
                XCTAssertEqual(receivedError.domain, expectedError.domain, file: file, line: line)

            default:
                XCTFail("Expected result \(expectedResult) got \(receivedResult) instead", file: file, line: line)
            }

            exp.fulfill()
        }

        wait(for: [exp], timeout: 0.1)
    }
}
