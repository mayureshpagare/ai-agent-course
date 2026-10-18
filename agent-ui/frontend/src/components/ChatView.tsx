import { useEffect, useRef } from "react";
import type { Agent, ChatItem } from "../api";
import ActivityGroup, { type ActivityStep } from "./ActivityGroup";
import Avatar from "./Avatar";
import Message from "./Message";

interface Props {
  agent: Agent | null;
  items: ChatItem[];
  busy: boolean;
  status: string;
  onDecide: (callId: string, approved: boolean) => void;
}

type Block =
  | { type: "message"; item: Exclude<ChatItem, ActivityStep>; key: string }
  | { type: "activity"; steps: ActivityStep[]; key: string };

/** Merge each run of consecutive thinking / tool items into one activity block. */
function toBlocks(items: ChatItem[]): Block[] {
  const blocks: Block[] = [];
  items.forEach((item, index) => {
    if (item.kind === "thinking" || item.kind === "tool") {
      const last = blocks[blocks.length - 1];
      if (last?.type === "activity") last.steps.push(item);
      else blocks.push({ type: "activity", steps: [item], key: `a${index}` });
    } else {
      blocks.push({ type: "message", item, key: `m${index}` });
    }
  });
  return blocks;
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
          <Avatar agent={agent} size="large" />
          <h1>{agent ? agent.name : "Pick an agent"}</h1>
          <p>{agent?.description}</p>
        </div>
      </div>
    );
  }

  const blocks = toBlocks(items);
  const lastIsActivity = blocks[blocks.length - 1]?.type === "activity";

  return (
    <div className="chat-scroll">
      <div className="chat-column">
        {blocks.map((block, index) =>
          block.type === "activity" ? (
            <ActivityGroup
              key={block.key}
              steps={block.steps}
              liveStatus={busy && index === blocks.length - 1 ? status : undefined}
              onDecide={onDecide}
            />
          ) : (
            <Message
              key={block.key}
              kind={block.item.kind}
              content={block.item.content}
              agent={agent}
            />
          ),
        )}
        {busy && !lastIsActivity && (
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
