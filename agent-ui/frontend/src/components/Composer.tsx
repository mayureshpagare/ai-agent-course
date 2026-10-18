import { useEffect, useRef, useState } from "react";

interface Props {
  disabled: boolean;
  busy: boolean;
  agentName: string;
  /** New chat: a larger rectangular box shown in the middle of the screen. */
  centered?: boolean;
  onSend: (text: string) => void;
  onStop: () => void;
}

const isTouch = window.matchMedia("(pointer: coarse)").matches;

export default function Composer({ disabled, busy, agentName, centered = false, onSend, onStop }: Props) {
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
    <div className={`composer-wrap ${centered ? "centered" : ""}`}>
      <div className={`composer ${centered ? "centered" : ""}`}>
        <textarea
          ref={ref}
          rows={centered ? 3 : 1}
          value={text}
          // Don't pop the keyboard open on phones before you ask for it.
          autoFocus={centered && !isTouch}
          placeholder={centered ? `Ask ${agentName} anything...` : `Message ${agentName}`}
          disabled={disabled}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            // On touch screens Enter adds a new line; the send button sends.
            if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing && !isTouch) {
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
