import Foundation
import OpenIslandCore

enum IslandListItem: Identifiable {
    case group(SessionGroup)
    case single(AgentSession)

    var id: String {
        switch self {
        case .group(let group):
            return group.id
        case .single(let session):
            return session.id
        }
    }
}

struct SessionGroup: Identifiable {
    let id: String
    let workspaceName: String
    let sessions: [AgentSession]

    var hasAttention: Bool {
        sessions.contains { $0.phase.requiresAttention }
    }

    var attentionCount: Int {
        sessions.filter { $0.phase.requiresAttention }.count
    }
}

func groupIslandSessions(_ sessions: [AgentSession]) -> [IslandListItem] {
    var groups: [String: [AgentSession]] = [:]
    var order: [String] = []

    for session in sessions {
        let key = session.spotlightWorkspaceName.lowercased()
        if groups[key] == nil {
            groups[key] = []
            order.append(key)
        }
        groups[key]?.append(session)
    }

    var items: [IslandListItem] = []
    for key in order {
        guard let groupSessions = groups[key] else { continue }

        if groupSessions.count == 1, let session = groupSessions.first {
            items.append(.single(session))
        } else if groupSessions.count >= 2 {
            let workspaceName = groupSessions.first?.spotlightWorkspaceName ?? key
            items.append(.group(SessionGroup(id: key, workspaceName: workspaceName, sessions: groupSessions)))
        }
    }

    return items
}
