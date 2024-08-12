//
//  HTTPClient.swift
//  Miele
//
//  Created by Stefano Martinallo on 21/07/2024.
//

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Foundation

public protocol HTTPClient {

    typealias Result = Swift.Result<(Data, HTTPURLResponse), Error>

    func get(url: URL, headers: [String: String], completion: @escaping (Result) -> Void)

}
