import Testing
@testable import OpenIslandApp
import OpenIslandCore
import Foundation

struct SessionGroupingTests {
    @Test func testGroupingLogic() throws {
        let session1 = AgentSession(
            id: "1", title: "Task A", tool: .claudeCode, phase: .running, summary: "Run", updatedAt: .now,
            jumpTarget: JumpTarget(terminalApp: "iTerm2", workspaceName: "ProjectX", paneTitle: "a")
        )
        let session2 = AgentSession(
            id: "2", title: "Task B", tool: .codex, phase: .running, summary: "Run", updatedAt: .now,
            jumpTarget: JumpTarget(terminalApp: "iTerm2", workspaceName: "projectx", paneTitle: "b")
        )
        let session3 = AgentSession(
            id: "3", title: "Task C", tool: .cursor, phase: .running, summary: "Run", updatedAt: .now,
            jumpTarget: JumpTarget(terminalApp: "Terminal", workspaceName: "ProjectY", paneTitle: "c")
        )

        let items = groupIslandSessions([session1, session2, session3])

        #expect(items.count == 2)

        guard case let .group(group) = items[0] else {
            Issue.record("Expected group for ProjectX")
            return
        }
        #expect(group.id == "projectx")
        #expect(group.workspaceName == "ProjectX")
        #expect(group.sessions.count == 2)
        #expect(group.sessions[0].id == "1")
        #expect(group.sessions[1].id == "2")

        guard case let .single(session) = items[1] else {
            Issue.record("Expected single for ProjectY")
            return
        }
        #expect(session.id == "3")
    }
}
