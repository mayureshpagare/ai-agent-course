import { useCallback, useEffect, useRef, useState } from "react";
import {
  api,
  streamMessage,
  UNAUTHORIZED_EVENT,
  type Agent,
  type AuthStatus,
  type ChatItem,
  type Conversation,
  type StreamEvent,
} from "./api";
import AgentPicker from "./components/AgentPicker";
import Avatar from "./components/Avatar";
import ConnectPhone from "./components/ConnectPhone";
import Login from "./components/Login";
import Sidebar from "./components/Sidebar";
import ChatView from "./components/ChatView";
import Composer from "./components/Composer";

const AGENT_KEY = "agent-ui:selected-agent";

function loadSavedAgent(): string | null {
  try {
    return localStorage.getItem(AGENT_KEY);
  } catch {
    return null;
  }
}

export default function App() {
  const [auth, setAuth] = useState<AuthStatus | null>(null);

  const checkAuth = useCallback(() => {
    api
      .auth()
      .then(setAuth)
      // Old backend without /api/auth, or unreachable: let the chat UI report it.
      .catch(() => setAuth({ required: false, authorized: true, local: true }));
  }, []);

  useEffect(() => {
    checkAuth();
    const signedOut = () => setAuth((current) => current && { ...current, authorized: false });
    window.addEventListener(UNAUTHORIZED_EVENT, signedOut);
    return () => window.removeEventListener(UNAUTHORIZED_EVENT, signedOut);
  }, [checkAuth]);

  if (!auth) return null;
  if (!auth.authorized) return <Login onSignedIn={checkAuth} />;
  return <ChatApp local={auth.local} />;
}

function ChatApp({ local }: { local: boolean }) {
  const [connectOpen, setConnectOpen] = useState(false);
  const [agents, setAgents] = useState<Agent[]>([]);
  const [agentId, setAgentId] = useState<string | null>(loadSavedAgent);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [items, setItems] = useState<ChatItem[]>([]);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [loadError, setLoadError] = useState("");
  const abortRef = useRef<AbortController | null>(null);
  const conversationIdRef = useRef<string | null>(null);
  conversationIdRef.current = conversationId;

  const agent = agents.find((a) => a.id === agentId) ?? null;

  useEffect(() => {
    api
      .agents()
      .then((list) => {
        setAgents(list);
        setAgentId((current) => (list.some((a) => a.id === current) ? current : list[0]?.id ?? null));
      })
      .catch((error) => setLoadError(`Could not reach the backend: ${error.message}`));
  }, []);

  // The history lists every chat, whichever agent it belongs to.
  const refreshConversations = useCallback(async () => {
    setConversations(await api.conversations());
  }, []);

  useEffect(() => {
    refreshConversations().catch(() => setConversations([]));
  }, [refreshConversations]);

  /** Pick the agent for a new chat. Remembered as the default for next time. */
  const selectAgent = (id: string) => {
    if (busy || conversationId) return;
    setAgentId(id);
    try {
      localStorage.setItem(AGENT_KEY, id);
    } catch {
      /* storage unavailable: selection just won't be remembered */
    }
  };

  const openConversation = async (id: string) => {
    if (busy) return;
    setSidebarOpen(false);
    setConversationId(id);
    const data = await api.conversation(id);
    // Each chat is bound to the agent it was started with.
    setAgentId(data.agent_id);
    setItems(data.items);
  };

  const newChat = () => {
    if (busy) return;
    setConversationId(null);
    setItems([]);
    setSidebarOpen(false);
    // Keep the agent of the chat you were in, unless that agent no longer exists.
    if (!agents.some((a) => a.id === agentId)) {
      const saved = loadSavedAgent();
      setAgentId(agents.some((a) => a.id === saved) ? saved : agents[0]?.id ?? null);
    }
  };

  const updateTool = (callId: string, patch: Partial<Extract<ChatItem, { kind: "tool" }>>) =>
    setItems((prev) =>
      prev.map((item) => (item.kind === "tool" && item.id === callId ? { ...item, ...patch } : item)),
    );

  const handleEvent = (event: StreamEvent) => {
    switch (event.type) {
      case "status":
        setStatus(event.message);
        break;
      case "title":
        setConversations((prev) =>
          prev.map((c) => (c.id === conversationIdRef.current ? { ...c, title: event.title } : c)),
        );
        break;
      case "thinking":
        setItems((prev) => [...prev, { kind: "thinking", content: event.content }]);
        break;
      case "tool_call":
        setStatus(`Running ${event.name}...`);
        setItems((prev) => [
          ...prev,
          { kind: "tool", id: event.call_id, name: event.name, args: event.args, result: null, status: "running" },
        ]);
        break;
      case "approval_required":
        setStatus("Waiting for your approval...");
        updateTool(event.call_id, { status: "approval", warning: event.warning });
        break;
      case "tool_result":
        setStatus("Thinking...");
        updateTool(event.call_id, { status: "done", result: event.content });
        break;
      case "final":
        setItems((prev) => [...prev, { kind: "assistant", content: event.content }]);
        break;
      case "error":
        setItems((prev) => [...prev, { kind: "error", content: event.message }]);
        break;
    }
  };

  const send = async (text: string) => {
    if (!agentId || busy) return;
    setBusy(true);
    setStatus("Thinking...");
    let id = conversationId;
    try {
      if (!id) {
        const created = await api.createConversation(agentId);
        id = created.id;
        conversationIdRef.current = id;
        setConversationId(id);
        setConversations((prev) => [created, ...prev]);
      }
      setItems((prev) => [...prev, { kind: "user", content: text }]);
      const controller = new AbortController();
      abortRef.current = controller;
      await streamMessage(id, text, handleEvent, controller.signal);
    } catch (error) {
      if ((error as Error).name !== "AbortError") {
        setItems((prev) => [...prev, { kind: "error", content: (error as Error).message }]);
      } else {
        setItems((prev) => [...prev, { kind: "error", content: "Stopped." }]);
      }
    } finally {
      abortRef.current = null;
      setBusy(false);
      setStatus("");
      // Any tool still spinning was interrupted.
      setItems((prev) =>
        prev.map((item) => (item.kind === "tool" && item.status !== "done" ? { ...item, status: "done" } : item)),
      );
      refreshConversations().catch(() => undefined);
    }
  };

  const stop = async () => {
    if (conversationId) await api.stop(conversationId).catch(() => undefined);
    abortRef.current?.abort();
  };

  const decide = async (callId: string, approved: boolean) => {
    if (!conversationId) return;
    updateTool(callId, { status: "running" });
    setStatus(approved ? "Running approved action..." : "Cancelling...");
    await api.approve(conversationId, callId, approved);
  };

  const rename = async (id: string, title: string) => {
    await api.rename(id, title);
    refreshConversations();
  };

  const remove = async (id: string) => {
    await api.remove(id);
    if (id === conversationId) newChat();
    refreshConversations();
  };

  const isNewChat = items.length === 0 && !busy;
  const composer = (
    <Composer
      // Remount on switching layouts so the large box gets focus.
      key={isNewChat ? "centered" : "docked"}
      centered={isNewChat && !loadError}
      disabled={!agent}
      busy={busy}
      onSend={send}
      onStop={stop}
      agentName={agent?.name ?? "agent"}
    />
  );

  return (
    <div className={`app ${sidebarOpen ? "sidebar-open" : ""}`}>
      <Sidebar
        agents={agents}
        conversations={conversations}
        conversationId={conversationId}
        onOpen={openConversation}
        onNewChat={newChat}
        onRename={rename}
        onDelete={remove}
        onConnectPhone={local ? () => setConnectOpen(true) : undefined}
        busy={busy}
      />
      {connectOpen && <ConnectPhone onClose={() => setConnectOpen(false)} />}
      <div className="scrim" onClick={() => setSidebarOpen(false)} />
      <main className="main">
        <header className="topbar">
          <button className="icon-button menu-button" onClick={() => setSidebarOpen(true)} aria-label="Open sidebar">
            ☰
          </button>
          <AgentPicker
            agents={agents}
            agentId={agentId}
            locked={conversationId !== null || busy}
            onSelect={selectAgent}
          />
        </header>
        {loadError ? (
          <>
            <div className="empty-state">
              <h1>Backend not reachable</h1>
              <p>{loadError}</p>
            </div>
            {composer}
          </>
        ) : isNewChat ? (
          // New chat: greeting and a large input box, centred together.
          <div className="new-chat-view">
            <div className="empty-state">
              <Avatar agent={agent} size="large" />
              <h1>{agent ? agent.name : "Pick an agent"}</h1>
              <p>{agent?.description}</p>
            </div>
            {composer}
          </div>
        ) : (
          <>
            <ChatView agent={agent} items={items} busy={busy} status={status} onDecide={decide} />
            {composer}
          </>
        )}
      </main>
    </div>
  );
}
