import { useState } from "react";
import { api } from "../api";

interface Props {
  onSignedIn: () => void;
}

/** Shown on other devices (e.g. your phone) until they sign in with the access token. */
export default function Login({ onSignedIn }: Props) {
  const linkFailed = new URLSearchParams(location.search).get("login") === "failed";
  const [token, setToken] = useState("");
  const [error, setError] = useState(linkFailed ? "That sign-in link is no longer valid." : "");
  const [busy, setBusy] = useState(false);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!token.trim() || busy) return;
    setBusy(true);
    setError("");
    try {
      await api.login(token.trim());
      history.replaceState(null, "", "/");
      onSignedIn();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login-screen">
      <form className="login-card" onSubmit={submit}>
        <div className="avatar large">🔒</div>
        <h1>Sign in to your agents</h1>
        <p>
          Scan the QR code printed by <code>run_ui.ps1</code> on your computer, or paste the access token
          from <code>agent-ui/backend/data/remote_token.txt</code>.
        </p>
        <input
          className="login-input"
          type="password"
          autoComplete="current-password"
          placeholder="Access token"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          autoFocus
        />
        {error && <div className="login-error">{error}</div>}
        <button className="login-button" type="submit" disabled={!token.trim() || busy}>
          {busy ? "Signing in..." : "Sign in"}
        </button>
      </form>
    </div>
  );
}
