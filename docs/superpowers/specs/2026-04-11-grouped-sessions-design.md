# Grouped Sessions by Project

## Problem

When multiple agents (Claude Code, Gemini CLI, Codex) run against the same project, the island panel shows them as independent flat rows. With 6+ sessions across 3-4 projects, it's hard to see which agents belong to which project.

## Design

Group sessions by project in the island panel. Multi-session projects get a tree-structured group header with connector lines; single-session projects stay as flat rows (no wrapper).

### Grouping Key

Sessions are grouped by **workspace name**, derived from the resolved working directory (`jumpTarget.workingDirectory`). Symlinks are resolved via `normalizedPathForMatching` so `/Users/me/DevStorage/foo` and `/Volumes/WorkSSD/foo` map to the same group.

Worktree branches are NOT separate groups — a session in `open-vibe-island (fix/foo)` groups under `open-vibe-island` alongside a session in `open-vibe-island (main)`.

### Layout Rules

1. **Multi-session projects** (2+ sessions sharing a workspace name):
   - Project header row: green status dot + project name (bold, 14pt) + agent count badge
   - Vertical connector line (1.5px, `#333`) from below the header, left-aligned under the status dot
   - Horizontal branch lines connecting each session row to the vertical line
   - Session rows indented under the connector, showing: small status dot + agent display name (medium weight) + current activity in muted text + age badge

2. **Single-session projects** (only 1 session for that workspace):
   - Rendered as a flat row, identical to today's `IslandSessionRow`
   - No group header, no connector lines

3. **Ordering**:
   - Groups are ordered by the highest-priority session within the group (using existing `displayPriority` scoring)
   - Within a group, sessions are ordered by priority then activity date
   - Single-session flat rows interleave with groups based on the same priority sort

### Session Row Content (Grouped Mode)

When a session is inside a group, the row title changes:

- **Current**: `spotlightHeadlineText` = workspace name (e.g., "open-vibe-island")
- **Grouped**: agent display name + activity suffix (e.g., "Gemini CLI — calling Bash", "Claude Code — Running")

The agent badge in the trailing badge cluster is removed (redundant with the new title). Terminal badge and age badge remain.

### Attention State

When a session in a group requires attention (`phase.requiresAttention`):

- The group header's status dot turns amber
- The header's agent count badge is replaced with an amber attention label (e.g., "1 needs approval")
- The attention session row gets a highlighted background (`rgba(245,158,11,0.08)`) with an amber border and the inline action card (approval buttons, question form) expanded within it
- Other sessions in the group remain in their normal state
- Non-attention groups are visually de-emphasized (reduced opacity) to draw focus

### Panel Height

The `openedContentHeight` calculation in `OverlayPanelController` accounts for group headers as additional rows in the height sum. A group header is estimated at ~34pt (dot + project name + padding). The existing `maxSessionListHeight` (560pt) cap and `AutoHeightScrollView` scrolling behavior remain unchanged.

## Architecture

### Data Layer

No new models needed. Grouping is a **view-level concern** computed from the existing `islandListSessions` array.

A new computed property on `AppModel` (or a helper struct) groups sessions:

```
struct SessionGroup: Identifiable {
    let id: String              // workspace name (lowercased, resolved)
    let workspaceName: String   // display name
    let sessions: [AgentSession]
}

var groupedIslandSessions: [IslandListItem] {
    // returns an array of either .group(SessionGroup) or .single(AgentSession)
}
```

The grouping logic:
1. Take `islandListSessions` (already sorted by priority)
2. Group by **base workspace name** (the directory name from the resolved working directory path, ignoring worktree branch suffixes — `spotlightWorkspaceName` without the branch annotation)
3. Groups with 1 session → `.single(session)`
4. Groups with 2+ sessions → `.group(SessionGroup)`
5. Sort groups/singles by the priority of their top session

### View Layer

- `IslandPanelView.sessionListContent` — replace the flat `ForEach(model.islandListSessions)` with a `ForEach` over `groupedIslandSessions` that renders either a `ProjectGroupView` or the existing `IslandSessionRow`
- New `ProjectGroupView` — renders the header + connector lines + nested session rows
- `IslandSessionRow` gets a `isGrouped: Bool` parameter that switches the headline from workspace name to agent + activity, and hides the agent badge
- `estimatedIslandRowHeight` — add a `estimatedGroupHeaderHeight` for the panel controller's height calculation

### Height Estimation

`OverlayPanelController.openedContentHeight` is updated to iterate over grouped items:
- `.single(session)` → existing `estimatedIslandRowHeight`
- `.group(group)` → header height (34pt) + sum of session row heights + spacing

## Scope

### In scope
- Grouping logic and `SessionGroup` model
- `ProjectGroupView` with connector lines
- Modified `IslandSessionRow` for grouped mode
- Updated height estimation
- Attention state rendering within groups

### Out of scope
- Collapsible groups (always expanded)
- Group-level actions (jump to project, etc.)
- Notification mode changes (single-session notification card is unchanged)
- Control center / debug view changes
