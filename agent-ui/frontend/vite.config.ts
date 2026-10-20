import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  // run_ui.ps1 sets AGENT_UI_REMOTE=1 so phones on the same network can connect.
  const remote = loadEnv(mode, ".", "AGENT_UI_").AGENT_UI_REMOTE === "1";
  return {
    plugins: [react()],
    server: {
      port: 5173,
      strictPort: true, // phones are given this port in the QR code, so never drift to another
      host: remote ? "0.0.0.0" : "localhost",
      // xfwd tells the backend who the real client is, so a phone reaching this dev
      // server over the network still has to sign in (see backend/remote.py).
      proxy: { "/api": { target: "http://localhost:8000", xfwd: true } },
    },
  };
});
