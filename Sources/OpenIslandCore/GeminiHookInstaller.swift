import Foundation

public struct GeminiHookInstallerManifest: Equatable, Codable, Sendable {
    public static let fileName = "open-island-gemini-hooks-install.json"

    public var hookCommand: String
    public var installedAt: Date

    public init(hookCommand: String, installedAt: Date = .now) {
        self.hookCommand = hookCommand
        self.installedAt = installedAt
    }
}

public struct GeminiHookFileMutation: Equatable, Sendable {
    public var contents: Data?
    public var changed: Bool
    public var managedHooksPresent: Bool

    public init(contents: Data?, changed: Bool, managedHooksPresent: Bool) {
        self.contents = contents
        self.changed = changed
        self.managedHooksPresent = managedHooksPresent
    }
}

public enum GeminiHookInstallerError: Error, LocalizedError {
    case invalidSettingsJSON

    public var errorDescription: String? {
        switch self {
        case .invalidSettingsJSON:
            "The existing Gemini settings.json is not valid JSON."
        }
    }
}

public enum GeminiHookInstaller {
    private static let hookEvents: [String] = [
        "SessionStart",
        "SessionEnd",
        "BeforeAgent",
        "AfterAgent",
        "BeforeModel",
        "AfterModel",
        "BeforeTool",
        "AfterTool",
        "PreCompress",
        "Notification",
    ]

    public static func hookCommand(for binaryPath: String) -> String {
        "\(shellQuote(binaryPath)) --source gemini"
    }

    public static func installSettingsJSON(
        existingData: Data?,
        hookCommand: String
    ) throws -> GeminiHookFileMutation {
        var rootObject = try loadRootObject(from: existingData)

        var hooksObject = rootObject["hooks"] as? [String: Any] ?? [:]

        for event in hookEvents {
            var groups = hooksObject[event] as? [[String: Any]] ?? []
            // Filter out managed hooks WITHIN groups to avoid duplicates
            groups = groups.compactMap { group in
                var group = group
                guard var hooks = group["hooks"] as? [[String: Any]] else { return group }
                hooks = hooks.filter { hook in
                    guard let command = hook["command"] as? String else { return true }
                    if command == hookCommand { return false }
                    return !isOpenIslandGeminiHookCommand(command)
                }
                if hooks.isEmpty { return nil }
                group["hooks"] = hooks
                return group
            }
            
            // Add our hook command wrapped in a group
            let timeout = (event == "BeforeTool") ? 86_400_000 : nil  // Gemini CLI timeout is in milliseconds
            groups.append(managedGroup(matcher: "*", timeout: timeout, hookCommand: hookCommand))
            
            hooksObject[event] = groups
        }

        rootObject["hooks"] = hooksObject
        let data = try serialize(rootObject)

        return GeminiHookFileMutation(
            contents: data,
            changed: data != existingData,
            managedHooksPresent: true
        )
    }

    public static func uninstallSettingsJSON(
        existingData: Data?,
        managedCommand: String?
    ) throws -> GeminiHookFileMutation {
        guard let existingData else {
            return GeminiHookFileMutation(contents: nil, changed: false, managedHooksPresent: false)
        }

        var rootObject = try loadRootObject(from: existingData)
        guard var hooksObject = rootObject["hooks"] as? [String: Any] else {
            return GeminiHookFileMutation(contents: existingData, changed: false, managedHooksPresent: false)
        }

        var mutated = false

        for event in hookEvents {
            guard let groups = hooksObject[event] as? [[String: Any]] else { continue }
            var filteredGroups: [[String: Any]] = []

            for var group in groups {
                guard var hooks = group["hooks"] as? [[String: Any]] else {
                    filteredGroups.append(group)
                    continue
                }
                let before = hooks.count
                hooks = hooks.filter { hook in
                    guard let command = hook["command"] as? String else { return true }
                    if let managedCommand, command == managedCommand { return false }
                    return !isOpenIslandGeminiHookCommand(command)
                }
                if hooks.count != before { mutated = true }
                if !hooks.isEmpty {
                    group["hooks"] = hooks
                    filteredGroups.append(group)
                }
            }

            if filteredGroups.isEmpty {
                hooksObject.removeValue(forKey: event)
            } else {
                hooksObject[event] = filteredGroups
            }
        }

        if hooksObject.isEmpty {
            rootObject.removeValue(forKey: "hooks")
        } else {
            rootObject["hooks"] = hooksObject
        }

        let data = try serialize(rootObject)

        return GeminiHookFileMutation(
            contents: data,
            changed: mutated || data != existingData,
            managedHooksPresent: mutated
        )
    }

    private static func loadRootObject(from data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let rootObject = object as? [String: Any] else {
            throw GeminiHookInstallerError.invalidSettingsJSON
        }

        return rootObject
    }

    private static func serialize(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private static func managedGroup(
        matcher: String?,
        timeout: Int?,
        hookCommand: String
    ) -> [String: Any] {
        var hook: [String: Any] = [
            "type": "command",
            "command": hookCommand,
        ]
        if let timeout {
            hook["timeout"] = timeout
        }

        var group: [String: Any] = [
            "hooks": [hook],
        ]

        if let matcher {
            group["matcher"] = matcher
        }

        return group
    }

    private static func isOpenIslandGeminiHookCommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return (normalized.contains("openislandhooks") || normalized.contains("vibeislandhooks"))
            && normalized.contains("gemini")
    }

    private static func shellQuote(_ string: String) -> String {
        guard !string.isEmpty else { return "''" }
        return "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
