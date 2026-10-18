import { useState } from "react";
import type { Agent } from "../api";

interface Props {
  agent: Agent | null | undefined;
  size?: "small" | "large";
  /** Shown when the agent is unknown. */
  fallback?: string;
}

/** The agent's logo from agent-ui/logos/, or its initial letter when it has none. */
export default function Avatar({ agent, size, fallback = "?" }: Props) {
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  const className = `avatar ${size ?? ""}`;

  if (agent?.logo && agent.logo !== failedUrl) {
    return (
      <span className={`${className} has-logo`}>
        <img src={agent.logo} alt="" draggable={false} onError={() => setFailedUrl(agent.logo)} />
      </span>
    );
  }
  return <span className={className}>{agent?.name.charAt(0).toUpperCase() ?? fallback}</span>;
}
