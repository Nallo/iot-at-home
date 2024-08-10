//
//  XCTestCase+AnyHelpers.swift
//  MieleTests
//
//  Created by Stefano Martinallo on 27/07/2024.
//

import XCTest

extension XCTestCase {
    func anyURL() -> URL {
        return URL(string: "http://any-url.com")!
    }
}
