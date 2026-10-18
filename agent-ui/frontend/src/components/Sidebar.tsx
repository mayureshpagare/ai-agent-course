import { useState } from "react";
import type { Agent, Conversation } from "../api";

interface Props {
  agents: Agent[];
  agentId: string | null;
  onSelectAgent: (id: string) => void;
  conversations: Conversation[];
  conversationId: string | null;
  onOpen: (id: string) => void;
  onNewChat: () => void;
  onRename: (id: string, title: string) => void;
  onDelete: (id: string) => void;
  busy: boolean;
}

export default function Sidebar(props: Props) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");

  const commitRename = (id: string) => {
    if (draft.trim()) props.onRename(id, draft.trim());
    setEditingId(null);
  };

  return (
    <aside className="sidebar">
      <button className="new-chat" onClick={props.onNewChat} disabled={props.busy}>
        <span>＋</span> New chat
      </button>

      <div className="sidebar-section">
        <div className="sidebar-label">Agents</div>
        {props.agents.length === 0 && <div className="sidebar-empty">No agents found</div>}
        {props.agents.map((agent) => (
          <button
            key={agent.id}
            className={`agent-row ${agent.id === props.agentId ? "active" : ""}`}
            onClick={() => props.onSelectAgent(agent.id)}
            disabled={props.busy && agent.id !== props.agentId}
            title={agent.description}
          >
            <span className="avatar">{agent.name.charAt(0)}</span>
            <span className="agent-text">
              <span className="agent-name">{agent.name}</span>
              <span className="agent-desc">{agent.description}</span>
            </span>
          </button>
        ))}
      </div>

      <div className="sidebar-section grow">
        <div className="sidebar-label">Chats</div>
        {props.conversations.length === 0 && <div className="sidebar-empty">No chats yet</div>}
        {props.conversations.map((c) => (
          <div key={c.id} className={`chat-row ${c.id === props.conversationId ? "active" : ""}`}>
            {editingId === c.id ? (
              <input
                className="rename-input"
                autoFocus
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onBlur={() => commitRename(c.id)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") commitRename(c.id);
                  if (e.key === "Escape") setEditingId(null);
                }}
              />
            ) : (
              <>
                <button className="chat-title" onClick={() => props.onOpen(c.id)} title={c.title}>
                  {c.title}
                </button>
                <span className="chat-actions">
                  <button
                    className="icon-button"
                    aria-label="Rename chat"
                    onClick={() => {
                      setEditingId(c.id);
                      setDraft(c.title);
                    }}
                  >
                    ✎
                  </button>
                  <button
                    className="icon-button"
                    aria-label="Delete chat"
                    onClick={() => confirm(`Delete "${c.title}"?`) && props.onDelete(c.id)}
                  >
                    🗑
                  </button>
                </span>
              </>
            )}
          </div>
        ))}
      </div>
    </aside>
  );
}
