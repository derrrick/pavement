import Foundation
import os

/// os.Logger subsystems for the engine.
public enum Log {
    public static let subsystem = "app.pavement"
    public static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    public static let catalog  = Logger(subsystem: subsystem, category: "catalog")
    public static let document = Logger(subsystem: subsystem, category: "document")
    public static let export   = Logger(subsystem: subsystem, category: "export")
}
