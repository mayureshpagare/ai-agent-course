import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import rehypeHighlight from "rehype-highlight";
import rehypeKatex from "rehype-katex";
import type { Agent } from "../api";
import Avatar from "./Avatar";

interface Props {
  kind: "user" | "assistant" | "error";
  content: string;
  agent?: Agent | null;
}

export default function Message({ kind, content, agent }: Props) {
  if (kind === "user") {
    return (
      <div className="message user">
        <div className="bubble">{content}</div>
      </div>
    );
  }

  if (kind === "error") {
    return <div className="message error">⚠ {content}</div>;
  }

  return (
    <div className="message assistant">
      <Avatar agent={agent} fallback="A" />
      <div className="markdown">
        <ReactMarkdown remarkPlugins={[remarkGfm, remarkMath]} rehypePlugins={[rehypeKatex, rehypeHighlight]}>
          {content}
        </ReactMarkdown>
      </div>
    </div>
  );
}
