//
//  DIContainer.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// A dependency injection container that manages service instances and factories
class DIContainer {
    
    /// Singleton instance for global access
    static let shared = DIContainer()
    
    /// Storage for factory closures indexed by service type name
    private var factories: [String: () -> Any] = [:]
    
    /// Storage for singleton instances indexed by service type name
    private var instances: [String: Any] = [:]
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Registers a factory closure to create a service on demand
    /// - Parameters:
    ///   - type: The protocol or type to register
    ///   - factory: A closure that creates a new instance of the service
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    /// Registers a singleton instance of a service
    /// - Parameters:
    ///   - type: The protocol or type to register
    ///   - instance: The instance to be used as a singleton
    func registerSingleton<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        instances[key] = instance
    }
    
    /// Resolves a service by its type
    /// - Parameter type: The protocol or type to resolve
    /// - Returns: An instance of the requested service, or nil if not registered
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        // Return existing instance if available
        if let instance = instances[key] as? T {
            return instance
        }
        
        // Create from factory if available, and cache as singleton
        if let factory = factories[key] {
            // Use optional casting instead of forced casting
            if let instance = factory() as? T {
                instances[key] = instance
                return instance
            } else {
                print("ERROR: Factory for \(key) produced incompatible type")
                return nil
            }
        }
        
        return nil
    }
    
    /// Resets the container, removing all registrations (primarily for testing)
    func reset() {
        factories = [:]
        instances = [:]
    }
}
