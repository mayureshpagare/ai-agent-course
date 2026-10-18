import { useState } from "react";
import type { Agent, Conversation } from "../api";
import Avatar from "./Avatar";

interface Props {
  agents: Agent[];
  conversations: Conversation[];
  conversationId: string | null;
  onOpen: (id: string) => void;
  onNewChat: () => void;
  onRename: (id: string, title: string) => void;
  onDelete: (id: string) => void;
  /** Set only on the host computer: opens the phone pairing QR code. */
  onConnectPhone?: () => void;
  busy: boolean;
}

export default function Sidebar(props: Props) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");

  const commitRename = (id: string) => {
    if (draft.trim()) props.onRename(id, draft.trim());
    setEditingId(null);
  };

  const agentName = (id: string) => props.agents.find((a) => a.id === id)?.name ?? id;

  return (
    <aside className="sidebar">
      <button className="new-chat" onClick={props.onNewChat} disabled={props.busy}>
        <span>＋</span> New chat
      </button>

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
                <button
                  className="chat-title"
                  onClick={() => props.onOpen(c.id)}
                  title={`${c.title} (${agentName(c.agent_id)})`}
                >
                  <Avatar
                    agent={props.agents.find((a) => a.id === c.agent_id)}
                    size="small"
                    fallback={c.agent_id.charAt(0).toUpperCase()}
                  />
                  <span className="chat-title-text">{c.title}</span>
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

      {props.onConnectPhone && (
        <button className="connect-phone" onClick={props.onConnectPhone}>
          <span>📱</span> Use on your phone
        </button>
      )}
    </aside>
  );
}
