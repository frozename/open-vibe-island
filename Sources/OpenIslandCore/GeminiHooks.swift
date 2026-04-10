import Foundation

public enum GeminiHookEventName: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case beforeAgent = "BeforeAgent"
    case afterAgent = "AfterAgent"
    case beforeTool = "BeforeTool"
    case afterTool = "AfterTool"
    case preCompress = "PreCompress"
    case notification = "Notification"
}

public struct GeminiHookPayload: Equatable, Codable, Sendable {
    public var sessionID: String
    public var transcriptPath: String
    public var cwd: String
    public var hookEventName: GeminiHookEventName
    public var timestamp: Date

    // Event-specific fields (all optional)
    public var source: String?
    public var reason: String?
    public var prompt: String?
    public var promptResponse: String?
    public var stopHookActive: Bool?
    public var toolName: String?
    public var toolInput: String? // Plan says "toolInput arrives as a JSON object — decode to compact String for preview"
    public var toolResponse: String? // AfterTool result preview
    public var originalRequestName: String? // BeforeTool/AfterTool original tool name
    public var trigger: String? // PreCompress trigger ("auto" | "manual")
    public var mcpContext: String? // Simplified for now as String
    public var notificationType: String?
    public var message: String?
    public var details: GeminiHookJSONValue?

    // Runtime context (populated via enrichment)
    public var terminalApp: String?
    public var terminalSessionID: String?
    public var terminalTTY: String?
    public var paneTitle: String?

    private enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case timestamp
        case source
        case reason
        case prompt
        case promptResponse = "prompt_response"
        case stopHookActive = "stop_hook_active"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case originalRequestName = "original_request_name"
        case trigger
        case mcpContext = "mcp_context"
        case notificationType = "notification_type"
        case message
        case details
        case terminalApp
        case terminalSessionID
        case terminalTTY
        case paneTitle
    }

    public init(
        sessionID: String,
        transcriptPath: String,
        cwd: String,
        hookEventName: GeminiHookEventName,
        timestamp: Date,
        source: String? = nil,
        reason: String? = nil,
        prompt: String? = nil,
        promptResponse: String? = nil,
        stopHookActive: Bool? = nil,
        toolName: String? = nil,
        toolInput: String? = nil,
        toolResponse: String? = nil,
        originalRequestName: String? = nil,
        trigger: String? = nil,
        mcpContext: String? = nil,
        notificationType: String? = nil,
        message: String? = nil,
        details: GeminiHookJSONValue? = nil,
        terminalApp: String? = nil,
        terminalSessionID: String? = nil,
        terminalTTY: String? = nil,
        paneTitle: String? = nil
    ) {
        self.sessionID = sessionID
        self.transcriptPath = transcriptPath
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.timestamp = timestamp
        self.source = source
        self.reason = reason
        self.prompt = prompt
        self.promptResponse = promptResponse
        self.stopHookActive = stopHookActive
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolResponse = toolResponse
        self.originalRequestName = originalRequestName
        self.trigger = trigger
        self.mcpContext = mcpContext
        self.notificationType = notificationType
        self.message = message
        self.details = details
        self.terminalApp = terminalApp
        self.terminalSessionID = terminalSessionID
        self.terminalTTY = terminalTTY
        self.paneTitle = paneTitle
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionID = try container.decode(String.self, forKey: .sessionID)
        self.transcriptPath = try container.decode(String.self, forKey: .transcriptPath)
        self.cwd = try container.decode(String.self, forKey: .cwd)
        self.hookEventName = try container.decode(GeminiHookEventName.self, forKey: .hookEventName)
        
        // Handle ISO8601 or similar timestamp formats if needed, otherwise default decode
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)

        self.source = try? container.decodeIfPresent(String.self, forKey: .source)
        self.reason = try? container.decodeIfPresent(String.self, forKey: .reason)
        self.prompt = try? container.decodeIfPresent(String.self, forKey: .prompt)
        self.promptResponse = try? container.decodeIfPresent(String.self, forKey: .promptResponse)
        self.stopHookActive = try? container.decodeIfPresent(Bool.self, forKey: .stopHookActive)
        self.toolName = try? container.decodeIfPresent(String.self, forKey: .toolName)
        
        // tool_input arrives as a JSON object, but we want it as a String preview.
        // It might arrive as a String if it went through the bridge.
        if let str = try? container.decodeIfPresent(String.self, forKey: .toolInput) {
            self.toolInput = str
        } else if let json = try? container.decodeIfPresent(GeminiHookJSONValue.self, forKey: .toolInput) {
            self.toolInput = json.toString()
        } else {
            self.toolInput = nil
        }

        if let str = try? container.decodeIfPresent(String.self, forKey: .toolResponse) {
            self.toolResponse = str
        } else if let json = try? container.decodeIfPresent(GeminiHookJSONValue.self, forKey: .toolResponse) {
            self.toolResponse = json.toString()
        } else {
            self.toolResponse = nil
        }

        self.originalRequestName = try? container.decodeIfPresent(String.self, forKey: .originalRequestName)
        self.trigger = try? container.decodeIfPresent(String.self, forKey: .trigger)
        
        if let str = try? container.decodeIfPresent(String.self, forKey: .mcpContext) {
            self.mcpContext = str
        } else if let json = try? container.decodeIfPresent(GeminiHookJSONValue.self, forKey: .mcpContext) {
            self.mcpContext = json.toString()
        } else {
            self.mcpContext = nil
        }

        self.notificationType = try? container.decodeIfPresent(String.self, forKey: .notificationType)
        self.message = try? container.decodeIfPresent(String.self, forKey: .message)
        self.details = try? container.decodeIfPresent(GeminiHookJSONValue.self, forKey: .details)

        self.terminalApp = try? container.decodeIfPresent(String.self, forKey: .terminalApp)
        self.terminalSessionID = try? container.decodeIfPresent(String.self, forKey: .terminalSessionID)
        self.terminalTTY = try? container.decodeIfPresent(String.self, forKey: .terminalTTY)
        self.paneTitle = try? container.decodeIfPresent(String.self, forKey: .paneTitle)
    }
}

public enum GeminiHookDecision: String, Codable, Sendable {
    case allow
    case deny
    case block
}

public struct GeminiHookDirective: Equatable, Codable, Sendable {
    public var `continue`: Bool
    public var decision: GeminiHookDecision
    public var reason: String?
    public var systemMessage: String?
    public var suppressOutput: Bool?

    public init(
        `continue`: Bool = true,
        decision: GeminiHookDecision,
        reason: String? = nil,
        systemMessage: String? = nil,
        suppressOutput: Bool? = nil
    ) {
        self.`continue` = `continue`
        self.decision = decision
        self.reason = reason
        self.systemMessage = systemMessage
        self.suppressOutput = suppressOutput
    }
}

public struct GeminiSessionMetadata: Equatable, Codable, Sendable {
    public var sessionID: String?
    public var initialUserPrompt: String?
    public var lastUserPrompt: String?
    public var lastAssistantMessage: String?
    public var currentTool: String?
    public var currentToolInputPreview: String?
    public var transcriptPath: String?

    public init(
        sessionID: String? = nil,
        initialUserPrompt: String? = nil,
        lastUserPrompt: String? = nil,
        lastAssistantMessage: String? = nil,
        currentTool: String? = nil,
        currentToolInputPreview: String? = nil,
        transcriptPath: String? = nil
    ) {
        self.sessionID = sessionID
        self.initialUserPrompt = initialUserPrompt
        self.lastUserPrompt = lastUserPrompt
        self.lastAssistantMessage = lastAssistantMessage
        self.currentTool = currentTool
        self.currentToolInputPreview = currentToolInputPreview
        self.transcriptPath = transcriptPath
    }

    public var isEmpty: Bool {
        sessionID == nil
            && initialUserPrompt == nil
            && lastUserPrompt == nil
            && lastAssistantMessage == nil
            && currentTool == nil
            && currentToolInputPreview == nil
            && transcriptPath == nil
    }
}

// MARK: - Payload Convenience Extensions

public extension GeminiHookPayload {
    var workspaceRoot: String {
        cwd
    }

    var workspaceName: String {
        WorkspaceNameResolver.workspaceName(for: workspaceRoot)
    }

    var sessionTitle: String {
        "Gemini \u{00B7} \(workspaceName)"
    }

    var defaultJumpTarget: JumpTarget {
        JumpTarget(
            terminalApp: terminalApp ?? "Terminal",
            workspaceName: workspaceName,
            paneTitle: paneTitle ?? "Gemini \(sessionID.prefix(8))",
            workingDirectory: workspaceRoot,
            terminalSessionID: terminalSessionID,
            terminalTTY: terminalTTY
        )
    }

    var defaultGeminiMetadata: GeminiSessionMetadata {
        GeminiSessionMetadata(
            sessionID: sessionID,
            initialUserPrompt: promptPreview,
            lastUserPrompt: promptPreview,
            lastAssistantMessage: promptResponsePreview,
            currentTool: toolName,
            currentToolInputPreview: toolInputPreview,
            transcriptPath: transcriptPath
        )
    }

    var implicitStartSummary: String {
        switch hookEventName {
        case .sessionStart:
            return "Gemini session started in \(workspaceName)."
        case .beforeAgent:
            return "Gemini is preparing a response in \(workspaceName)."
        case .beforeTool:
            return "Gemini is calling \(toolName ?? "a tool") in \(workspaceName)."
        case .notification:
            return message ?? "Gemini sent a notification in \(workspaceName)."
        case .preCompress:
            let type = (trigger == "manual") ? "manual" : "automatic"
            return "Gemini is performing \(type) compaction."
        default:
            return "Gemini activity in \(workspaceName)."
        }
    }

    var isBlockingHook: Bool {
        hookEventName == .beforeTool
    }

    var promptPreview: String? {
        clipped(prompt)
    }

    var promptResponsePreview: String? {
        clipped(promptResponse)
    }

    var messagePreview: String? {
        clipped(message)
    }

    var toolInputPreview: String? {
        clipped(toolInput)
    }

    var permissionRequestTitle: String {
        switch hookEventName {
        case .beforeTool:
            let name = toolName ?? "tool"
            return "Allow \(name)"
        default:
            return "Allow Gemini action"
        }
    }

    var permissionRequestSummary: String {
        switch hookEventName {
        case .beforeTool:
            let name = toolName ?? "a tool"
            return "Gemini wants to call \(name)."
        default:
            return "Gemini needs permission to continue."
        }
    }

    var permissionAffectedPath: String {
        workspaceRoot
    }

    private func clipped(_ value: String?, limit: Int = 110) -> String? {
        guard let value else { return nil }

        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > limit else { return collapsed }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit - 1)
        return "\(collapsed[..<endIndex])\u{2026}"
    }

    func withRuntimeContext(environment: [String: String]) -> GeminiHookPayload {
        var payload = self

        if payload.terminalApp == nil {
            payload.terminalApp = inferTerminalApp(from: environment)
        }

        if payload.terminalTTY == nil {
            payload.terminalTTY = currentTTY()
        }

        if payload.terminalSessionID == nil {
            if payload.terminalApp == "cmux" {
                payload.terminalSessionID = environment["CMUX_SURFACE_ID"]
            } else if payload.terminalApp == "Ghostty" {
                payload.terminalSessionID = environment["GHOSTTY_BIN_DIR"] != nil ? environment["TTY"] : nil
            }
        }

        return payload
    }

    private func inferTerminalApp(from environment: [String: String]) -> String? {
        if environment["CMUX_SURFACE_ID"] != nil {
            return "cmux"
        }
        if environment["GHOSTTY_BIN_DIR"] != nil {
            return "Ghostty"
        }
        if environment["ITERM_SESSION_ID"] != nil {
            return "iTerm"
        }
        if environment["TERM_PROGRAM"] == "Apple_Terminal" {
            return "Terminal"
        }
        if environment["VSCODE_GIT_ASKPASS_NODE"] != nil || environment["TERM_PROGRAM"] == "vscode" {
            return "VS Code"
        }
        return nil
    }

    private func currentTTY() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tty")
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let tty = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (tty == "not a tty") ? nil : tty
    }
}

// MARK: - GeminiHookJSONValue helper

public typealias GeminiHookJSONValue = CodexHookJSONValue

public extension GeminiHookJSONValue {
    func toString() -> String {
        switch self {
        case .string(let value):
            return "\"\(Self.escapeJSONString(value))\""
        case .number(let value):
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", value)
            }
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .object(let value):
            let pairs = value.map { "\"\(Self.escapeJSONString($0.key))\":\($0.value.toString())" }
                .sorted()
                .joined(separator: ",")
            return "{\(pairs)}"
        case .array(let value):
            let elements = value.map { $0.toString() }.joined(separator: ",")
            return "[\(elements)]"
        case .null:
            return "null"
        }
    }

    private static func escapeJSONString(_ value: String) -> String {
        var result = ""
        for char in value {
            switch char {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if let ascii = char.asciiValue, ascii < 0x20 {
                    result += String(format: "\\u%04x", ascii)
                } else {
                    result.append(char)
                }
            }
        }
        return result
    }
}
