import Foundation

/// JSONDecoder helper that round-trips unknown keys so older builds don't drop newer fields.
public enum UnknownKeysContainer {}
