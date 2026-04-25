import Foundation

public enum MigrationError: Error, CustomStringConvertible {
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case .unsupportedVersion(let v):
            return "EditRecipe schemaVersion \(v) is not supported by this build (max \(EditRecipe.currentSchemaVersion))."
        }
    }
}

public enum Migrations {
    public typealias Step = (inout EditRecipe) throws -> Void

    /// Registry: stepRegistry[fromVersion] = (toVersion, transform).
    /// v1 has no upgrade target yet; entries are added when schemaVersion is bumped.
    private static let stepRegistry: [Int: (target: Int, step: Step)] = [:]

    public static let lowestSupportedVersion: Int = 1
    public static var latestVersion: Int { EditRecipe.currentSchemaVersion }

    /// Upgrade `recipe` from its current schemaVersion up to `EditRecipe.currentSchemaVersion`.
    /// Throws if the source version is unknown to this build.
    public static func upgrade(_ recipe: inout EditRecipe) throws {
        guard recipe.schemaVersion >= lowestSupportedVersion,
              recipe.schemaVersion <= latestVersion else {
            throw MigrationError.unsupportedVersion(recipe.schemaVersion)
        }
        while recipe.schemaVersion < latestVersion {
            guard let entry = stepRegistry[recipe.schemaVersion] else {
                throw MigrationError.unsupportedVersion(recipe.schemaVersion)
            }
            try entry.step(&recipe)
            recipe.schemaVersion = entry.target
        }
    }
}
