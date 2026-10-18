import { useEffect, useRef, useState } from "react";
import type { Agent } from "../api";
import Avatar from "./Avatar";

interface Props {
  agents: Agent[];
  agentId: string | null;
  /** True once a chat has started: its agent can no longer be changed. */
  locked: boolean;
  onSelect: (id: string) => void;
}

export default function AgentPicker({ agents, agentId, locked, onSelect }: Props) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const agent = agents.find((a) => a.id === agentId) ?? null;

  // Close when clicking outside the menu or pressing Escape.
  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  useEffect(() => {
    if (locked) setOpen(false);
  }, [locked]);

  const label = agent?.name ?? (agentId ? `${agentId} (not found)` : "Select an agent");

  return (
    <div className="agent-picker" ref={rootRef}>
      <button
        className={`agent-picker-button ${locked ? "locked" : ""}`}
        onClick={() => !locked && setOpen((value) => !value)}
        aria-haspopup="listbox"
        aria-expanded={open}
        title={locked ? "This chat's agent is fixed. Start a new chat to use a different agent." : "Choose an agent"}
      >
        <span>{label}</span>
        {!locked && <span className="chevron">▾</span>}
      </button>
      {agent?.model && <span className="badge">{agent.model}</span>}

      {open && (
        <div className="agent-menu" role="listbox">
          {agents.length === 0 && <div className="sidebar-empty">No agents found</div>}
          {agents.map((a) => (
            <button
              key={a.id}
              role="option"
              aria-selected={a.id === agentId}
              className={`agent-row ${a.id === agentId ? "active" : ""}`}
              onClick={() => {
                onSelect(a.id);
                setOpen(false);
              }}
            >
              <Avatar agent={a} />
              <span className="agent-text">
                <span className="agent-name">{a.name}</span>
                <span className="agent-desc">{a.description}</span>
              </span>
              {a.id === agentId && <span className="check">✓</span>}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
