"""Discover agents: every top-level folder of the repo that contains ui_entry.py.

Agents are not imported here (their dependencies live in their own venvs), so
NAME / DESCRIPTION / MODEL are read statically from the source with `ast`.
"""

import ast
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ENTRY_FILE = "ui_entry.py"
# Agent logos: agent-ui/logos/<agent folder name>.<ext> (see logos/README.md).
LOGO_DIR = REPO_ROOT / "agent-ui" / "logos"
LOGO_EXTENSIONS = (".svg", ".png", ".webp", ".jpg", ".jpeg")  # first match wins


@dataclass
class AgentInfo:
    id: str
    name: str
    description: str
    model: str
    path: Path

    @property
    def python(self) -> str:
        """The agent's own venv interpreter, falling back to the backend's."""
        for candidate in (self.path / ".venv" / "Scripts" / "python.exe",
                          self.path / ".venv" / "bin" / "python"):
            if candidate.exists():
                return str(candidate)
        return sys.executable

    @property
    def logo(self) -> Path | None:
        for extension in LOGO_EXTENSIONS:
            candidate = LOGO_DIR / f"{self.id}{extension}"
            if candidate.is_file():
                return candidate
        return None

    def to_json(self) -> dict:
        logo = self.logo
        # The version query makes browsers reload a logo after you replace the file.
        logo_url = f"/api/agents/{self.id}/logo?v={int(logo.stat().st_mtime)}" if logo else None
        return {"id": self.id, "name": self.name,
                "description": self.description, "model": self.model, "logo": logo_url}


def _string_constants(path: Path) -> dict:
    """Return top-level `NAME = "literal"` assignments from a Python file."""
    if not path.exists():
        return {}
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"))
    except (SyntaxError, UnicodeDecodeError):
        return {}
    values = {}
    for node in tree.body:
        if (isinstance(node, ast.Assign) and isinstance(node.value, ast.Constant)
                and isinstance(node.value.value, str)):
            for target in node.targets:
                if isinstance(target, ast.Name):
                    values[target.id] = node.value.value
    return values


def discover_agents() -> dict[str, AgentInfo]:
    agents = {}
    for folder in sorted(REPO_ROOT.iterdir()):
        if not (folder / ENTRY_FILE).is_file():
            continue
        entry = _string_constants(folder / ENTRY_FILE)
        model = (entry.get("MODEL")
                 or _string_constants(folder / "config.py").get("MODEL")
                 or _string_constants(folder / "agent.py").get("MODEL")
                 or "")
        agents[folder.name] = AgentInfo(
            id=folder.name,
            name=entry.get("NAME", folder.name),
            description=entry.get("DESCRIPTION", ""),
            model=model,
            path=folder,
        )
    return agents
