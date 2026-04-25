import Foundation

/// Root non-destructive edit state, persisted as a JSON sidecar. Phase 1.
/// Schema-complete from day 1 per the execution plan; pipeline stages
/// only consume fields they implement.
public struct EditRecipe: Codable, Equatable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int = currentSchemaVersion

    public init() {}
}
