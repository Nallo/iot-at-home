//
//  MieleService.swift
//  Miele
//
//  Created by Stefano Martinallo on 21/07/2024.
//

import Foundation

@frozen public enum ProgramState {
    case Running
    case Ended
}

public struct Device: Hashable {

    public let id: String
    public let type: String
    public let program: String
    public let programState: ProgramState
    public let waterConsumption: Measurement<UnitVolume>

    public init(id: String, type: String, program: String, programState: ProgramState, waterConsumption: Measurement<UnitVolume>) {
        self.id = id
        self.type = type
        self.program = program
        self.programState = programState
        self.waterConsumption = waterConsumption
    }

}

public final class MieleService {

    public typealias Result = Swift.Result<[Device], Error>

    public enum Error: Swift.Error {
        case connectivity
        case invalidData(payload: Data)
    }

    private let client: HTTPClient
    private let mapper: MieleServiceMapper.Type

    public init(client: HTTPClient, mapper: MieleServiceMapper.Type = MieleServiceMapper.self) {
        self.client = client
        self.mapper = mapper
    }

    public func startListeningForData(using url: URL, andSecret secret: String, completion: @escaping (Result) -> Void) {
        let httpHeaders = [
            "Accept": "text/event-stream",
            "Accept-Language": "it",
            "Authorization": "Bearer \(secret)"
        ]

        client.get(url: url, headers: httpHeaders) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success((data, response)):
                completion(self.mapper.map(data, and: response))
            case .failure:
                completion(.failure(.connectivity))
            }
        }
    }

}
