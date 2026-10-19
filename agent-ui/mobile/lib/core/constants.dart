/// App-wide constants. Server addresses never live here: they come from the
/// saved `ConnectionProfile`.
library;

/// Port suggested when a typed server address has none (`run_ui.ps1 -Prod`).
/// Dev mode uses 5173 instead, which the QR code already includes.
const int defaultServerPort = 8000;

/// Time allowed for an ordinary JSON request, from sending to the full body.
const Duration requestTimeout = Duration(seconds: 10);

/// Time allowed to open a TCP connection to the server.
const Duration connectTimeout = Duration(seconds: 6);

const String composerHint = 'Runs locally with Ollama. Agents can make mistakes.';

/// Status line shown while waiting for the first stream event.
const String thinkingStatus = 'Thinking...';
