//
//  MieleServiceMapper.swift
//  Miele
//
//  Created by Stefano Martinallo on 26/07/2024.
//

import Foundation

public final class MieleServiceMapper {

    private struct Response: Decodable {
        let ident: DeviceType
        let state: Program
    }

    private struct DeviceType: Decodable {
        let type: Value
    }

    private struct Program: Decodable {
        let ProgramID: Value
        let status: ValueRaw
        let ecoFeedback: EcoFeedback
    }

    private struct Value: Decodable {
        let value_localized: String
    }

    private struct ValueRaw: Decodable {
        let value_raw: Int
    }

    private struct EcoFeedback: Decodable {
        let currentWaterConsumption: MieleMeasurement
    }

    private struct MieleMeasurement: Decodable {
        let unit: String
        let value: Double
    }

    private static let ProgramStateMapping: [Int: ProgramState] = [
        5: .Running,
        7: .Ended
    ]

    static func map(_ data: Data, and response: HTTPURLResponse) -> MieleService.Result {
        guard
            response.statusCode == 200,
            let dataAsString = String(data: data, encoding: .utf8),
            dataAsString.starts(with: "event: devices")
        else {
            return .failure(.invalidData(payload: data))
        }

        let jsonArray = extractJSONData(from: dataAsString)

        var devices = [Device]()

        for json in jsonArray {
            do {
                let d = try JSONDecoder().decode([String: Response].self, from: json)
                for (deviceId, item) in d {
                    guard let device = makeDevice(withId: deviceId, and: item) else { continue }
                    devices.append(device)
                }
            } catch {
                return .failure(.invalidData(payload: data))
            }
        }

        return .success(devices)
    }

    private static func extractJSONData(from dataString: String) -> [Data] {
        return dataString
            .split(separator: "\n")
            .filter { $0.starts(with: "data: {") }
            .map { String($0).replacingOccurrences(of: "data: ", with: "") }
            .compactMap { $0.data(using: .utf8) }
    }

    private static func makeDevice(withId deviceId: String, and response: MieleServiceMapper.Response) -> Device? {
        let name = response.ident.type.value_localized
        let program = response.state.ProgramID.value_localized
        let waterConsumptionUnitAsString = response.state.ecoFeedback.currentWaterConsumption.unit
        let waterConsumptionValue = response.state.ecoFeedback.currentWaterConsumption.value
        let waterConsumptionUnit = UnitVolume(symbol: waterConsumptionUnitAsString)
        let waterConsumption = Measurement(value: waterConsumptionValue, unit: waterConsumptionUnit)

        let programStateRaw = response.state.status.value_raw
        guard let programState = ProgramStateMapping[programStateRaw] else { return nil }

        return Device(id: deviceId, type: name, program: program, programState: programState, waterConsumption: waterConsumption)
    }

}
