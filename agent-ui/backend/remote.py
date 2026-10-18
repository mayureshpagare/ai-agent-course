"""Remote access: use the UI from your phone (or any device) on the same network.

Enabled by `run_ui.ps1 -Remote`, which sets AGENT_UI_REMOTE=1 and binds to 0.0.0.0.
Every /api request from another device must then carry the access token, either
as the cookie set by /api/login or as an `Authorization: Bearer <token>` header.
The token is generated once and kept in data/remote_token.txt (or set
AGENT_UI_TOKEN yourself). Requests from this computer's own browser don't need it.
"""

import hmac
import io
import os
import secrets
import socket
import sys
from pathlib import Path

import qrcode
import qrcode.image.svg

COOKIE = "agent_ui_token"
TOKEN_FILE = Path(__file__).resolve().parent / "data" / "remote_token.txt"
LOCAL_HOSTS = {"127.0.0.1", "::1", "localhost"}
# A reverse proxy (e.g. `tailscale serve`) makes every request look local, so
# forwarded requests never get the localhost exemption.
FORWARD_HEADERS = ("x-forwarded-for", "forwarded", "x-real-ip")

ENABLED = os.environ.get("AGENT_UI_REMOTE") == "1" or bool(os.environ.get("AGENT_UI_TOKEN"))
PORT = int(os.environ.get("AGENT_UI_PORT", "8000"))


def _load_token() -> str:
    if os.environ.get("AGENT_UI_TOKEN"):
        return os.environ["AGENT_UI_TOKEN"]
    if TOKEN_FILE.exists() and TOKEN_FILE.read_text().strip():
        return TOKEN_FILE.read_text().strip()
    token = secrets.token_urlsafe(24)
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(token)
    return token


TOKEN = _load_token() if ENABLED else ""


def token_matches(candidate: str | None) -> bool:
    return bool(TOKEN and candidate) and hmac.compare_digest(candidate.encode(), TOKEN.encode())


def is_local(request) -> bool:
    host = request.client.host if request.client else ""
    return host in LOCAL_HOSTS and not any(h in request.headers for h in FORWARD_HEADERS)


def is_authorized(request) -> bool:
    if not ENABLED or is_local(request):
        return True
    header = request.headers.get("authorization", "")
    bearer = header[7:] if header.lower().startswith("bearer ") else None
    return token_matches(request.cookies.get(COOKIE)) or token_matches(bearer)


def lan_addresses() -> list[str]:
    """IPv4 addresses other devices can use to reach this machine (LAN, Tailscale, ...)."""
    found = []
    try:  # The interface used for outbound traffic; no packet is actually sent.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            found.append(s.getsockname()[0])
    except OSError:
        pass
    try:
        found += socket.gethostbyname_ex(socket.gethostname())[2]
    except OSError:
        pass
    usable = [ip for ip in found if not ip.startswith(("127.", "169.254."))]
    return list(dict.fromkeys(usable))


def login_urls() -> list[str]:
    return [f"http://{ip}:{PORT}/api/login?token={TOKEN}" for ip in lan_addresses()]


def qr_svg(text: str) -> str:
    image = qrcode.make(text, image_factory=qrcode.image.svg.SvgPathImage, border=2)
    return image.to_string(encoding="unicode")


def print_banner() -> None:
    urls = login_urls()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print("\n" + "=" * 64)
    print(" Remote access is ON. On your phone (same Wi-Fi), scan or open:")
    if not urls:
        print("   (no network address found: is this computer online?)")
    for url in urls:
        print(f"   {url}")
    if urls:
        qr = qrcode.QRCode(border=1)
        qr.add_data(urls[0])
        out = io.StringIO()
        qr.print_ascii(out=out, invert=True)
        print(out.getvalue())
    print(" Keep this link private: it grants full access to your agents.")
    print(f" Token file: {TOKEN_FILE}  (delete it and restart to revoke all phones)")
    print("=" * 64 + "\n", flush=True)
