import { useEffect, useRef } from "react";
import type { Agent, ChatItem } from "../api";
import Message from "./Message";
import ToolCallCard from "./ToolCallCard";

interface Props {
  agent: Agent | null;
  items: ChatItem[];
  busy: boolean;
  status: string;
  onDecide: (callId: string, approved: boolean) => void;
}

export default function ChatView({ agent, items, busy, status, onDecide }: Props) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [items, busy]);

  if (items.length === 0 && !busy) {
    return (
      <div className="chat-scroll">
        <div className="empty-state">
          <div className="avatar large">{agent?.name.charAt(0) ?? "?"}</div>
          <h1>{agent ? agent.name : "Pick an agent"}</h1>
          <p>{agent?.description}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="chat-scroll">
      <div className="chat-column">
        {items.map((item, index) =>
          item.kind === "tool" ? (
            <ToolCallCard key={item.id} item={item} onDecide={onDecide} />
          ) : (
            <Message key={index} kind={item.kind} content={item.content} agentInitial={agent?.name.charAt(0)} />
          ),
        )}
        {busy && (
          <div className="status-line">
            <span className="dots">
              <i />
              <i />
              <i />
            </span>
            {status}
          </div>
        )}
        <div ref={bottomRef} />
      </div>
    </div>
  );
}
