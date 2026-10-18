import { useEffect, useRef, useState } from "react";

interface Props {
  disabled: boolean;
  busy: boolean;
  agentName: string;
  onSend: (text: string) => void;
  onStop: () => void;
}

export default function Composer({ disabled, busy, agentName, onSend, onStop }: Props) {
  const [text, setText] = useState("");
  const ref = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
  }, [text]);

  const submit = () => {
    const value = text.trim();
    if (!value || busy || disabled) return;
    onSend(value);
    setText("");
  };

  return (
    <div className="composer-wrap">
      <div className="composer">
        <textarea
          ref={ref}
          rows={1}
          value={text}
          placeholder={`Message ${agentName}`}
          disabled={disabled}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault();
              submit();
            }
          }}
        />
        {busy ? (
          <button className="send-button stop" onClick={onStop} aria-label="Stop">
            ■
          </button>
        ) : (
          <button className="send-button" onClick={submit} disabled={!text.trim() || disabled} aria-label="Send">
            ↑
          </button>
        )}
      </div>
      <div className="composer-hint">Runs locally with Ollama. Agents can make mistakes.</div>
    </div>
  );
}
