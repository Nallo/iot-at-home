//
//  MieleTests.swift
//  MieleTests
//
//  Created by Stefano Martinallo on 16/07/2024.
//

import XCTest
import Miele


final class MieleTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual(MielePlayground.version, "Version 1.0")
    }

    func test_service_doesNotSendRequestUponCreation() {
        let (client, _) = makeSUT()

        XCTAssertTrue(client.requestedUrls.isEmpty)
    }

    func test_startListeningForData_requestDataFromUrl() {
        let url = anyURL()
        let secret = "any secret"
        let (client, sut) = makeSUT()

        sut.startListeningForData(using: url, andSecret: secret) { _ in }

        XCTAssertEqual(client.requestedUrls, [url])
    }

    func test_startListeningForData_sendsGetHttpRequest() {
        let url = anyURL()
        let secret = "any secret"
        let (client, sut) = makeSUT()

        sut.startListeningForData(using: url, andSecret: secret) { _ in }

        XCTAssertEqual(client.requestedHttpVerbs, ["GET"])
    }

    func test_startListeningForData_sendsCorrectHttpHeaders() {
        let url = anyURL()
        let expectedSecret = "Super Impossible Secret"
        let (client, sut) = makeSUT()

        sut.startListeningForData(using: url, andSecret: expectedSecret) { _ in }

        assert(client, requestedHeadersWithKey: "Accept", andValue: "text/event-stream")
        assert(client, requestedHeadersWithKey: "Accept-Language", andValue: "it")
        assert(client, requestedHeadersWithKey: "Authorization", andValue: "Bearer \(expectedSecret)")
    }

    func test_startListeningForData_completesWithConnectivityErrorWhenClientCompletesWithAnyError() {
        let (client, sut) = makeSUT()

        expect(sut, toCompleteWith: .failure(.connectivity)) {
            let clientError = NSError(domain: "Test", code: 0)
            client.complete(with: clientError)
        }
    }

    func test_startListeningForData_deliversInvalidDataErrorOnNon200HTTPResponse() {
        let anyData = Data()
        let (client, sut) = makeSUT()
        let samples = [199, 201, 300, 400, 500]

        samples.enumerated().forEach { index, statusCode in
            expect(sut, toCompleteWith: .failure(.invalidData(payload: anyData))) {
                client.complete(withStatusCode: statusCode, data: anyData, at: index)
            }
        }
    }

    func test_startListeningForData_deliversInvalidDataErrorOn200HTTPResponseWithInvalidEventDataFormat() {
        let invalidEventData = "this format is not valid".data(using: .utf8)!
        let (client, sut) = makeSUT()

        expect(sut, toCompleteWith: .failure(.invalidData(payload: invalidEventData))) {
            client.complete(withStatusCode: 200, data: invalidEventData)
        }
    }

    func test_startListeningForData_deliversInvalidDataErrorOn200HTTPResponseWithPartiallyCorrectEventDataFormat() {
        let partiallyCorrectEventData = "event: devices\ndata: { this format is not valid }".data(using: .utf8)!
        let (client, sut) = makeSUT()

        expect(sut, toCompleteWith: .failure(.invalidData(payload: partiallyCorrectEventData))) {
            client.complete(withStatusCode: 200, data: partiallyCorrectEventData)
        }
    }

    func test_startListeningForData_deliversSuccessWithNoDevicesOn200HTTPResponseWithEmptyJSONList() {
        let (client, sut) = makeSUT()

        expect(sut, toCompleteWith: .success([])) {
            let payloadWithoutDevices = makeEventPayload(withJsonDevices: [])
            client.complete(withStatusCode: 200, data: payloadWithoutDevices)
        }
    }

    func test_startListeningForData_deliversSuccessWithOneDeviceOn200HTTPResponseWithOneDeviceInJSONList() {
        let (client, sut) = makeSUT()
        let (deviceModel, deviceJson) = makeDevice()

        expect(sut, toCompleteWith: .success([deviceModel])) {
            let payloadWithOnetDevice = makeEventPayload(withJsonDevices: [deviceJson])
            client.complete(withStatusCode: 200, data: payloadWithOnetDevice)
        }
    }

    func test_startListeningForData_deliversSuccessWithMultipleDevicesOn200HTTPResponseWithMultipleDevicesInJSONList() {
        let (client, sut) = makeSUT()
        let (deviceModel1, deviceJson1) = makeDevice(id: "1000", type: "Washing Machine", program: "Wool", programState: .Ended)
        let (deviceModel2, deviceJson2) = makeDevice(id: "2000", type: "Dryer", program: "Cotton", programState: .Running)
        let (deviceModel3, deviceJson3) = makeDevice(id: "3000", type: "Hoven", program: "Cooking sea", programState: .Ended)
        let deviceModels = [deviceModel1, deviceModel2, deviceModel3]
        let deviceJsons = [deviceJson1, deviceJson2, deviceJson3]

        expect(sut, toCompleteWith: .success(deviceModels)) {
            let payloadWithTwoDevices = makeEventPayload(withJsonDevices: deviceJsons)
            client.complete(withStatusCode: 200, data: payloadWithTwoDevices)
        }
    }

    func test_startListeningForData_deliversSuccessWithoutDevicesWithInvalidProgramStateOn200HTTPResponseWithMultipleDevicesInJSONListAndSomeWithInvalidProgramState() {
        let (deviceModel1, deviceJson1) = makeDevice(id: "1000", type: "Washing Machine", program: "Wool", programState: .Ended)
        let (deviceModel2, deviceJson2) = makeDevice(id: "2000", type: "Dryer", program: "Cotton", programState: .Running)
        let deviceJsonWithInvalidProgramState = makeDeviceJsonWithInvalidProgramState()

        let expectedDeviceModels = [deviceModel1, deviceModel2]
        let deviceJsons = [deviceJson1, deviceJson2, deviceJsonWithInvalidProgramState]

        let (client, sut) = makeSUT()

        expect(sut, toCompleteWith: .success(expectedDeviceModels)) {
            let payloadWithTwoDevices = makeEventPayload(withJsonDevices: deviceJsons)
            client.complete(withStatusCode: 200, data: payloadWithTwoDevices)
        }
    }

    func test_startListeningForData_deliversSuccessWithOneDeviceOnMultiple200HTTPResponsesWithOneDeviceInJSONList() {
        let (client, sut) = makeSUT()
        let (deviceModel1, deviceJson1) = makeDevice(id: "1000", type: "Washing Machine", program: "Wool")
        let (deviceModel2, deviceJson2) = makeDevice(id: "2000", type: "Dryer", program: "Cotton")
        let (deviceModel3, deviceJson3) = makeDevice(id: "3000", type: "Hoven", program: "Cooking sea")

        expect(sut, toCompleteWith: .success([deviceModel1]), .success([deviceModel2]), .success([deviceModel3])) {
            let payload1 = makeEventPayload(withJsonDevices: [deviceJson1])
            client.complete(withStatusCode: 200, data: payload1)

            let payload2 = makeEventPayload(withJsonDevices: [deviceJson2])
            client.complete(withStatusCode: 200, data: payload2)

            let payload3 = makeEventPayload(withJsonDevices: [deviceJson3])
            client.complete(withStatusCode: 200, data: payload3)
        }
    }

    func test_startListeningForData_doesNotDeliverResultAfterSUTInstanceHasBeenDeallocated() {
        let url = anyURL()
        let secret = "Super Impossible Secret"
        let client = HTTPClientSpy()
        var sut: MieleService? = MieleService(client: client)
        let (_, deviceJson) = makeDevice()

        var capturedResults = [MieleService.Result]()
        sut?.startListeningForData(using: url, andSecret: secret) { capturedResults.append($0) }

        sut = nil
        client.complete(withStatusCode: 200, data: makeEventPayload(withJsonDevices: [deviceJson]))

        XCTAssertTrue(capturedResults.isEmpty)
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (client: HTTPClientSpy, sut: MieleService) {
        let client = HTTPClientSpy()
        let sut = MieleService(client: client)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        return (client, sut)
    }

    private func assert(_ client: HTTPClientSpy, requestedHeadersWithKey expectedKey: String, andValue expectedValue: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let _ = client.requestedHeaders[expectedKey] else {
            return XCTFail("Expecting key \"\(expectedKey)\" in HTTP headers. Got \(client.requestedHeaders) instead", file: file, line: line)
        }

        let receivedValue = client.requestedHeaders[expectedKey]
        XCTAssertEqual(receivedValue, expectedValue, "Expecting value \"\(expectedValue)\" for key \"\(expectedKey)\" in HTTP headers. Got \(client.requestedHeaders) instead", file: file, line: line)
    }

    private func makeDevice(
        id: String = "any-id",
        type: String = "any-type",
        program: String = "any-program",
        programState: ProgramState = .Running,
        waterConsumptionUnit: String = "l",
        waterConsumptionValue: Double = 123.0) -> (model: Device, json: [String: Any])
    {
        let waterConsumption: Measurement<UnitVolume> = Measurement(value: waterConsumptionValue, unit: UnitVolume(symbol: waterConsumptionUnit))
        let model = Device(id: id, type: type, program: program, programState: programState, waterConsumption: waterConsumption)

        let json = [
            id: [
                "ident": [
                    "type": [
                        "value_localized": type
                    ]
                ],
                "state": [
                    "ProgramID": [
                        "value_localized": program
                    ],
                    "status": [
                        "value_raw": getMieleState(from: programState)
                    ],
                    "ecoFeedback": [
                        "currentWaterConsumption": [
                            "unit": waterConsumptionUnit,
                            "value": waterConsumptionValue
                        ]
                    ]
                ]
            ]
        ].compactMapValues { $0 }

        return (model, json)
    }

    private func makeDeviceJsonWithInvalidProgramState() -> [String: Any] {
        let invalidProgramState = -1

        let json = [
            "id-1234": [
                "ident": [
                    "type": [
                        "value_localized": "any type"
                    ]
                ],
                "state": [
                    "ProgramID": [
                        "value_localized": "any program"
                    ],
                    "status": [
                        "value_raw": invalidProgramState
                    ],
                    "ecoFeedback": [
                        "currentWaterConsumption": [
                            "unit": "l",
                            "value": 100.0
                        ]
                    ]
                ]
            ]
        ].compactMapValues { $0 }

        return json
    }

    private func getMieleState(from programState: ProgramState) -> Int {
        switch programState {
        case .Running:
            return 5
        case .Ended:
            return 7
        }
    }

    private func makeEventPayload(withJsonDevices jsonDevices: [[String: Any]]) -> Data {
        var combinedJson = [String: Any]()
        for jsonDevice in jsonDevices {
            combinedJson.merge(jsonDevice, uniquingKeysWith: { a, _ in a })
        }

        let jsonData = try! JSONSerialization.data(withJSONObject: combinedJson)
        let jsonString = String.init(data: jsonData, encoding: .utf8)!

        var stringPayload = "event: devices\n"
        stringPayload += "data: \(jsonString)\n"
        stringPayload += "\n"
        stringPayload += "event: actions\n"
        stringPayload += "data: {}\n"
        stringPayload += "\n"

        return stringPayload.data(using: .utf8)!
    }

    private func expect(_ sut: MieleService, toCompleteWith expectedResults: MieleService.Result..., when action: () -> Void,
                        file: StaticString = #filePath, line: UInt = #line) {
        var expectedResultIndex = 0
        let exp = expectation(description: "Wait for SUT to complete")
        exp.expectedFulfillmentCount = expectedResults.count
        let url = anyURL()
        let secret = "any secret"

        sut.startListeningForData(using: url, andSecret: secret) { receivedResult in
            guard expectedResults.count > expectedResultIndex else {
                return XCTFail("Can't assert expectedResult at index \(expectedResultIndex). Out of range", file: file, line: line)
            }

            let expectedResult = expectedResults[expectedResultIndex]

            switch (receivedResult, expectedResult) {

            case let (.success(receivedDevices), .success(expectedDevices)):
                XCTAssertEqual(receivedDevices.count, expectedDevices.count, "Expected \(expectedDevices.count) devices, got \(receivedDevices.count) instead", file: file, line: line)
                let receivedDevicesSet = Set(receivedDevices)
                let expectedDevicesSet = Set(expectedDevices)
                XCTAssertEqual(receivedDevicesSet, expectedDevicesSet, "Expected \(expectedDevicesSet), got \(receivedDevicesSet) instead", file: file, line: line)
                expectedResultIndex += 1

            case let (.failure(receivedError), .failure(expectedError)):
                switch (receivedError, expectedError) {

                case (.connectivity, .connectivity):
                    break

                case let (.invalidData(payload: receivedData), .invalidData(payload: expectedData)):
                    XCTAssertEqual(receivedData.base64EncodedData(), expectedData.base64EncodedData(), "Expected \(expectedData). Got \(receivedData) instead", file: file, line: line)

                default:
                    XCTFail("Expected SUT to fail with \"\(expectedError)\" error, got \"\(receivedError)\" error instead", file: file, line: line)
                }

            default:
                XCTFail("Expected result \(expectedResult) got \(receivedResult) instead", file: file, line: line)
            }

            exp.fulfill()
        }

        action()
        waitForExpectations(timeout: 0.1)
    }

}
