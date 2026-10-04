enum InvitationCode: Equatable {
    case new(String)
    case legacy(String)

    private static let newCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    private static let legacyCodeAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"

    static func parse(_ input: String) -> InvitationCode? {
        let groups = input.split(separator: "-", omittingEmptySubsequences: false)
        if groups.count == 3, groups.allSatisfy({ $0.count == 4 }) {
            let value = groups.joined().uppercased()
            if isNewCode(value) { return .new(value) }
        }
        let uppercaseInput = input.uppercased()
        if isNewCode(uppercaseInput) {
            return .new(uppercaseInput)
        }
        if input.count == 22, input.allSatisfy({ legacyCodeAlphabet.contains($0) }) {
            return .legacy(input)
        }
        return nil
    }

    private static func isNewCode(_ input: String) -> Bool {
        input.count == 12 && input.allSatisfy({ newCodeAlphabet.contains($0) })
    }

    var displayValue: String {
        switch self {
        case let .new(value):
            return "\(value.prefix(4))-\(value.dropFirst(4).prefix(4))-\(value.dropFirst(8))"
        case let .legacy(value):
            return value
        }
    }

    var submissionValue: String {
        switch self {
        case let .new(value): value
        case let .legacy(value): value
        }
    }
}
