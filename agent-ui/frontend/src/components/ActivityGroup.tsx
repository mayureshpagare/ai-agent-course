import { useState } from "react";
import type { ChatItem } from "../api";

type ToolItem = Extract<ChatItem, { kind: "tool" }>;
export type ActivityStep = ToolItem | Extract<ChatItem, { kind: "thinking" }>;

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

function summary(steps: ActivityStep[]): string {
  const tools = steps.filter((s) => s.kind === "tool").length;
  const thought = steps.some((s) => s.kind === "thinking");
  const parts = [];
  if (thought) parts.push("Thought");
  if (tools) parts.push(`used ${tools} tool${tools === 1 ? "" : "s"}`);
  const text = parts.join(", ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

interface Props {
  steps: ActivityStep[];
  /** Status text while this group is the one currently running. */
  liveStatus?: string;
  onDecide: (callId: string, approved: boolean) => void;
}

/** One collapsible block holding a turn's reasoning and tool calls. */
export default function ActivityGroup({ steps, liveStatus, onDecide }: Props) {
  const [expanded, setExpanded] = useState(false);
  const pendingApproval = steps.some((s) => s.kind === "tool" && s.status === "approval");
  const running = liveStatus !== undefined;
  const open = expanded || pendingApproval;

  return (
    <div className={`activity ${pendingApproval ? "needs-approval" : ""}`}>
      <button className="activity-header" onClick={() => setExpanded(!expanded)} aria-expanded={open}>
        <span className="tool-icon">{running ? <span className="spinner" /> : "✦"}</span>
        <span className="activity-title">{running && liveStatus ? liveStatus : summary(steps)}</span>
        <span className="chevron">{open ? "▾" : "▸"}</span>
      </button>

      {open && (
        <ol className="activity-steps">
          {steps.map((step, index) =>
            step.kind === "thinking" ? (
              <li key={index} className="step thinking">
                {step.content.trim()}
              </li>
            ) : (
              <li key={step.id} className={`step tool ${step.status}`}>
                <div className="step-head">
                  <span className="tool-icon">{step.status === "running" ? <span className="spinner" /> : "⚙"}</span>
                  <span className="tool-name">{step.name}</span>
                  <span className="tool-args">({argSummary(step.args)})</span>
                </div>
                {step.status === "approval" && (
                  <div className="approval">
                    <p>
                      <strong>Approval needed.</strong> {step.warning}
                    </p>
                    <div className="approval-buttons">
                      <button className="approve" onClick={() => onDecide(step.id, true)}>
                        Approve
                      </button>
                      <button className="deny" onClick={() => onDecide(step.id, false)}>
                        Deny
                      </button>
                    </div>
                  </div>
                )}
                {step.result !== null && <pre className="step-result">{pretty(step.result)}</pre>}
              </li>
            ),
          )}
        </ol>
      )}
    </div>
  );
}
