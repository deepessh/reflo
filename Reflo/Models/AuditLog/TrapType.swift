import Foundation

enum TrapType: String, Codable, Sendable, Hashable, CaseIterable {
    case falseBelief = "false_belief"
    case flawedMentalModel = "flawed_mental_model"
    case ontologicalMiscategorization = "ontological_miscategorization"
    case overturnedCommonSenseBelief = "overturned_common_sense_belief"
    case unclassified = "unclassified"

    static func fromWireValue(_ value: String?) throws -> TrapType? {
        guard let value else { return nil }
        guard let trap = TrapType(rawValue: value) else {
            throw QuizAuditValidationError.invalidTrapType(value)
        }
        return trap
    }

    static func fromLegacyDepth(_ depth: String?) -> TrapType? {
        guard let depth else { return nil }
        switch depth {
        case "false_belief":
            return .falseBelief
        case "flawed_model", "flawed_mental_model":
            return .flawedMentalModel
        case "wrong_category", "ontological_miscategorization":
            return .ontologicalMiscategorization
        case "overturned_common_sense_belief":
            return .overturnedCommonSenseBelief
        case "unclassified":
            return .unclassified
        default:
            return .unclassified
        }
    }
}
