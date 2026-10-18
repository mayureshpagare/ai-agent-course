import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import rehypeHighlight from "rehype-highlight";
import rehypeKatex from "rehype-katex";

interface Props {
  kind: "user" | "assistant" | "error";
  content: string;
  agentInitial?: string;
}

export default function Message({ kind, content, agentInitial }: Props) {
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
      <div className="avatar">{agentInitial ?? "A"}</div>
      <div className="markdown">
        <ReactMarkdown remarkPlugins={[remarkGfm, remarkMath]} rehypePlugins={[rehypeKatex, rehypeHighlight]}>
          {content}
        </ReactMarkdown>
      </div>
    </div>
  );
}
