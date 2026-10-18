export interface Agent {
  id: string;
  name: string;
  description: string;
  model: string;
}

export interface Conversation {
  id: string;
  agent_id: string;
  title: string;
  created_at: number;
  updated_at: number;
}

export type ToolStatus = "running" | "approval" | "done";

export type ChatItem =
  | { kind: "user" | "assistant" | "error"; content: string }
  | { kind: "thinking"; content: string }
  | {
      kind: "tool";
      id: string;
      name: string;
      args: Record<string, unknown>;
      result: string | null;
      status: ToolStatus;
      warning?: string;
    };

export type StreamEvent =
  | { type: "status"; message: string }
  | { type: "title"; title: string }
  | { type: "thinking"; content: string }
  | { type: "tool_call"; call_id: string; name: string; args: Record<string, unknown> }
  | { type: "approval_required"; call_id: string; name: string; args: Record<string, unknown>; warning: string }
  | { type: "tool_result"; call_id: string; name: string; content: string }
  | { type: "final"; content: string }
  | { type: "error"; message: string };

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.detail ?? `${response.status} ${response.statusText}`);
  }
  return response.json();
}

export const api = {
  agents: () => request<Agent[]>("/api/agents"),
  conversations: (agentId: string) =>
    request<Conversation[]>(`/api/conversations?agent_id=${encodeURIComponent(agentId)}`),
  createConversation: (agentId: string) =>
    request<Conversation>("/api/conversations", {
      method: "POST",
      body: JSON.stringify({ agent_id: agentId }),
    }),
  conversation: (id: string) => request<Conversation & { items: ChatItem[] }>(`/api/conversations/${id}`),
  rename: (id: string, title: string) =>
    request(`/api/conversations/${id}`, { method: "PATCH", body: JSON.stringify({ title }) }),
  remove: (id: string) => request(`/api/conversations/${id}`, { method: "DELETE" }),
  approve: (id: string, callId: string, approved: boolean) =>
    request(`/api/conversations/${id}/approve`, {
      method: "POST",
      body: JSON.stringify({ call_id: callId, approved }),
    }),
  stop: (id: string) => request(`/api/conversations/${id}/stop`, { method: "POST" }),
};

/** POST a message and call `onEvent` for every server-sent event until the turn ends. */
export async function streamMessage(
  conversationId: string,
  content: string,
  onEvent: (event: StreamEvent) => void,
  signal: AbortSignal,
): Promise<void> {
  const response = await fetch(`/api/conversations/${conversationId}/messages`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content }),
    signal,
  });
  if (!response.ok || !response.body) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.detail ?? `${response.status} ${response.statusText}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let boundary: number;
    while ((boundary = buffer.indexOf("\n\n")) !== -1) {
      const chunk = buffer.slice(0, boundary);
      buffer = buffer.slice(boundary + 2);
      for (const line of chunk.split("\n")) {
        if (line.startsWith("data: ")) onEvent(JSON.parse(line.slice(6)));
      }
    }
  }
}
