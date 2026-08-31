import Foundation

struct AppVersion: Equatable, Sendable {
    let publicVersion: String
    let build: String
    let gitRevision: String?
    let isDirty: Bool

    init?(infoDictionary: [String: Any], metadataDictionary: [String: Any]) {
        guard
            let publicVersion = Self.nonemptyString(infoDictionary["CFBundleShortVersionString"]),
            let build = Self.nonemptyString(infoDictionary["CFBundleVersion"])
        else {
            return nil
        }

        self.publicVersion = publicVersion
        self.build = build
        gitRevision = Self.validRevision(metadataDictionary["GitRevision"])
        isDirty = gitRevision != nil && metadataDictionary["GitDirty"] as? Bool == true
    }

    init?(bundle: Bundle) {
        self.init(
            infoDictionary: bundle.infoDictionary ?? [:],
            metadataDictionary: Self.metadataDictionary(in: bundle)
        )
    }

    var displayString: String {
        let bundleIdentity = "\(publicVersion) (\(build))"
        guard let gitRevision else { return bundleIdentity }
        return "\(bundleIdentity) · \(gitRevision)\(isDirty ? " dirty" : "")"
    }

    static var current: AppVersion? {
        AppVersion(bundle: .main)
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func validRevision(_ value: Any?) -> String? {
        guard let revision = nonemptyString(value), revision.count == 7 else { return nil }
        let hexadecimal = CharacterSet(charactersIn: "0123456789abcdef")
        return revision.unicodeScalars.allSatisfy(hexadecimal.contains) ? revision : nil
    }

    private static func metadataDictionary(in bundle: Bundle) -> [String: Any] {
        guard
            let url = bundle.url(forResource: "BuildMetadata", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return [:]
        }
        return dictionary
    }
}
