import { useState } from "react";
import type { ChatItem } from "../api";

type ToolItem = Extract<ChatItem, { kind: "tool" }>;

function pretty(value: unknown): string {
  if (typeof value === "string") {
    try {
      return JSON.stringify(JSON.parse(value), null, 2);
    } catch {
      return value;
    }
  }
  return JSON.stringify(value, null, 2);
}

function argSummary(args: Record<string, unknown>): string {
  return Object.entries(args)
    .map(([key, value]) => `${key}=${typeof value === "string" ? `"${value}"` : JSON.stringify(value)}`)
    .join(", ");
}

export default function ToolCallCard({
  item,
  onDecide,
}: {
  item: ToolItem;
  onDecide: (callId: string, approved: boolean) => void;
}) {
  const [open, setOpen] = useState(false);
  const needsApproval = item.status === "approval";

  return (
    <div className={`tool-card ${item.status}`}>
      <button className="tool-header" onClick={() => setOpen(!open)} aria-expanded={open}>
        <span className="tool-icon">{item.status === "running" ? <span className="spinner" /> : "⚙"}</span>
        <span className="tool-name">{item.name}</span>
        <span className="tool-args">({argSummary(item.args)})</span>
        <span className="chevron">{open ? "▾" : "▸"}</span>
      </button>

      {needsApproval && (
        <div className="approval">
          <p>
            <strong>Approval needed.</strong> {item.warning}
          </p>
          <div className="approval-buttons">
            <button className="approve" onClick={() => onDecide(item.id, true)}>
              Approve
            </button>
            <button className="deny" onClick={() => onDecide(item.id, false)}>
              Deny
            </button>
          </div>
        </div>
      )}

      {open && (
        <div className="tool-body">
          <div className="tool-label">Arguments</div>
          <pre>{pretty(item.args)}</pre>
          <div className="tool-label">Result</div>
          <pre>{item.result === null ? "…" : pretty(item.result)}</pre>
        </div>
      )}
    </div>
  );
}
