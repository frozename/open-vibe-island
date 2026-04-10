import Foundation
import Testing
@testable import OpenIslandCore

struct GeminiHooksTests {
    @Test
    func geminiHookPayloadDecodesFromJSON() throws {
        let json = """
        {
            "session_id": "session-123",
            "transcript_path": "/tmp/gemini/transcript.jsonl",
            "cwd": "/Users/test/project",
            "hook_event_name": "BeforeTool",
            "timestamp": "2026-04-10T04:00:00Z",
            "tool_name": "ls",
            "tool_input": { "path": "." }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let payload = try decoder.decode(GeminiHookPayload.self, from: json)
        #expect(payload.sessionID == "session-123")
        #expect(payload.hookEventName == .beforeTool)
        #expect(payload.cwd == "/Users/test/project")
        #expect(payload.toolName == "ls")
        #expect(payload.toolInput == "{\"path\":\".\"}")
        #expect(payload.isBlockingHook == true)
    }

    @Test
    func geminiHookPayloadDecodesAfterAgentWithResponse() throws {
        let json = """
        {
            "session_id": "session-123",
            "transcript_path": "/tmp/gemini/transcript.jsonl",
            "cwd": "/Users/test/project",
            "hook_event_name": "AfterAgent",
            "timestamp": "2026-04-10T04:00:05Z",
            "prompt_response": "Hello world"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let payload = try decoder.decode(GeminiHookPayload.self, from: json)
        #expect(payload.hookEventName == .afterAgent)
        #expect(payload.promptResponse == "Hello world")
        #expect(payload.defaultGeminiMetadata.lastAssistantMessage == "Hello world")
    }

    @Test
    func jsonValueToStringEscaping() {
        let obj: [String: JSONValue] = [
            "key with \"quotes\"": .string("line1\nline2\ttab\\backslashes")
        ]
        let value = JSONValue.object(obj)
        let string = value.toString()
        
        // Keys should be escaped, values should be escaped
        #expect(string.contains("\"key with \\\"quotes\\\"\":"))
        #expect(string.contains("\"line1\\nline2\\ttab\\\\backslashes\""))
    }

    @Test
    func geminiHookInstallerInstallsIntoEmptyFile() throws {
        let hookCommand = "'/bin/openislandhooks' --source gemini"
        let mutation = try GeminiHookInstaller.installSettingsJSON(existingData: nil, hookCommand: hookCommand)
        
        #expect(mutation.changed == true)
        #expect(mutation.managedHooksPresent == true)
        
        let data = try #require(mutation.contents)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = object["hooks"] as! [String: Any]
        
        // Verify nested structure for BeforeTool
        let beforeToolGroups = hooks["BeforeTool"] as! [[String: Any]]
        #expect(beforeToolGroups.count == 1)
        #expect(beforeToolGroups[0]["matcher"] as? String == "*")
        
        let beforeToolHooks = beforeToolGroups[0]["hooks"] as! [[String: Any]]
        #expect(beforeToolHooks[0]["command"] as? String == hookCommand)
        #expect(beforeToolHooks[0]["type"] as? String == "command")
        #expect(beforeToolHooks[0]["timeout"] as? Int == 86400)
    }

    @Test
    func geminiHookInstallerPreservesUserHooksInSameGroup() throws {
        let existingJSON = """
        {
            "hooks": {
                "BeforeTool": [
                    { 
                        "matcher": "*", 
                        "hooks": [
                            { "type": "command", "command": "user-hook" }
                        ] 
                    }
                ]
            }
        }
        """
        let hookCommand = "managed-hook"
        let mutation = try GeminiHookInstaller.installSettingsJSON(
            existingData: existingJSON.data(using: .utf8),
            hookCommand: hookCommand
        )
        
        let data = try #require(mutation.contents)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = object["hooks"] as! [String: Any]
        let beforeToolGroups = hooks["BeforeTool"] as! [[String: Any]]
        
        // The installer adds a new managed group with matcher "*", preserving the existing user group
        #expect(beforeToolGroups.count == 2)
        
        // Now test uninstallation preserves the user hook
        let uninstalled = try GeminiHookInstaller.uninstallSettingsJSON(
            existingData: data,
            managedCommand: hookCommand
        )
        let finalObject = try JSONSerialization.jsonObject(with: uninstalled.contents!) as! [String: Any]
        let finalHooks = finalObject["hooks"] as! [String: Any]
        let finalGroups = finalHooks["BeforeTool"] as! [[String: Any]]
        
        #expect(finalGroups.count == 1)
        let innerHooks = finalGroups[0]["hooks"] as! [[String: Any]]
        #expect(innerHooks.count == 1)
        #expect(innerHooks[0]["command"] as? String == "user-hook")
    }

    @Test
    func geminiHookInstallerUninstallsCleanly() throws {
        let hookCommand = "managed-command"
        let installed = try GeminiHookInstaller.installSettingsJSON(existingData: nil, hookCommand: hookCommand)
        
        let uninstalled = try GeminiHookInstaller.uninstallSettingsJSON(
            existingData: installed.contents,
            managedCommand: hookCommand
        )
        
        #expect(uninstalled.managedHooksPresent == false)
        #expect(uninstalled.contents != nil)
        
        let object = try JSONSerialization.jsonObject(with: uninstalled.contents!) as! [String: Any]
        #expect(object["hooks"] == nil)
    }

    @Test
    func geminiPayloadConvenienceProperties() {
        let payload = GeminiHookPayload(
            sessionID: "session-test",
            transcriptPath: "/tmp/transcript.jsonl",
            cwd: "/Users/test/my-project",
            hookEventName: .beforeTool,
            timestamp: Date(),
            toolName: "grep",
            toolInput: "{\"pattern\":\"error\"}"
        )

        #expect(payload.workspaceName == "my-project")
        #expect(payload.sessionTitle == "Gemini \u{00B7} my-project")
        #expect(payload.sessionID == "session-test")
        #expect(payload.permissionRequestTitle == "Allow grep")
        #expect(payload.permissionRequestSummary == "Gemini wants to call grep.")
    }

    @Test
    func bridgeRoundTripDoesNotDoubleQuoteJSON() throws {
        let originalJSON = """
        {
            "session_id": "session-roundtrip",
            "transcript_path": "/tmp/transcript.jsonl",
            "cwd": "/Users/test/project",
            "hook_event_name": "BeforeTool",
            "timestamp": "2026-04-10T04:00:00Z",
            "tool_name": "grep",
            "tool_input": { "pattern": "error" }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let initialPayload = try decoder.decode(GeminiHookPayload.self, from: originalJSON)
        #expect(initialPayload.toolInput == "{\"pattern\":\"error\"}")

        let command = BridgeCommand.processGeminiHook(initialPayload)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedCommand = try encoder.encode(command)
        
        let decodedCommand = try decoder.decode(BridgeCommand.self, from: encodedCommand)
        
        guard case let .processGeminiHook(roundTripPayload) = decodedCommand else {
            Issue.record("Expected processGeminiHook command")
            return
        }
        
        #expect(roundTripPayload.toolInput == "{\"pattern\":\"error\"}")
    }
}
