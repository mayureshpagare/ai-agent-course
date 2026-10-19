import { useEffect, useState } from "react";
import { api, type RemoteInfo } from "../api";

interface Props {
  onClose: () => void;
}

/** QR code for pairing a phone. Only the host computer's own browser can load it. */
export default function ConnectPhone({ onClose }: Props) {
  const [info, setInfo] = useState<RemoteInfo | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api.remote().then(setInfo).catch((e) => setError(e.message));
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" role="dialog" aria-label="Use on your phone" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Use on your phone</h2>
          <button className="icon-button" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </div>
        {error && <p className="login-error">{error}</p>}
        {!info && !error && <p className="muted">Loading...</p>}
        {info && !info.enabled && (
          <>
            <p>Remote access is off. Restart the UI without -LocalOnly:</p>
            <pre className="modal-code">.\run_ui.ps1</pre>
            <p className="muted">Then open this dialog again to get a QR code for your phone.</p>
          </>
        )}
        {info?.enabled && info.qr && (
          <>
            <p>Connect your phone to the same Wi-Fi, then scan this with its camera:</p>
            <div className="qr" dangerouslySetInnerHTML={{ __html: info.qr }} />
            <p className="muted">
              In your phone's browser menu, choose <b>Add to Home Screen</b> to open it like an app.
            </p>
            <details>
              <summary>Other addresses</summary>
              {info.urls.map((url) => (
                <div key={url} className="modal-url">
                  {url}
                </div>
              ))}
            </details>
            <p className="muted small">Anyone with this code can use your agents. Delete remote_token.txt and restart to revoke it.</p>
          </>
        )}
        {info?.enabled && !info.qr && <p>No network address found. Is this computer connected to Wi-Fi?</p>}
      </div>
    </div>
  );
}
