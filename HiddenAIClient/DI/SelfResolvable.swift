//
//  SelfResolvable.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for types that can resolve themselves from the DI container
protocol SelfResolvable {
    /// Resolves an instance of the conforming type from the DI container
    static func resolve() -> Self
}

extension SelfResolvable {
    /// Default implementation that resolves from the shared container
    static func resolve() -> Self {
        guard let instance = DIContainer.shared.resolve(Self.self) else {
            fatalError("Failed to resolve \(Self.self) from DIContainer")
        }
        return instance
    }
}
