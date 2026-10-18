# Agent logos

Put an image in this folder to show it instead of an agent's initial letter. The logo appears in the sidebar, the agent picker, the new-chat screen and next to the agent's replies.

## File name

Name the file after the agent's folder name in the repo root, for example:

```
logos/01-calc-agent.svg
logos/02-file-notes-agent.png
logos/03-csv-analysis-agent.webp
```

If an agent has more than one logo, the UI uses the first match in this order: `.svg`, `.png`, `.webp`, `.jpg`/`.jpeg`. Agents without a logo keep showing their initial letter.

## Ideal format

| | Recommended |
|---|---|
| **Format** | **SVG** is best because it stays sharp at every size. Otherwise use **PNG** or **WebP**. |
| **Shape** | **Square (1:1).** If the image isn't square, it is scaled down to fit inside the square, with empty space at the sides. |
| **Size (PNG/WebP)** | **256 × 256 px**. 128 × 128 px is the minimum. |
| **File size** | Under 100 KB. Logos are loaded on every page view, including on phones. |
| **Background** | Either fill the whole square edge to edge, or use a transparent background. A transparent logo must be readable on both light (#ffffff) and dark (#212121) backgrounds. |
| **Corners** | Square corners. The UI rounds them for you (about 22% of the width). |
| **Padding** | Keep the important parts inside the middle ~80%, so the rounded corners don't cut them off. |
| **Detail** | Keep it simple. The smallest place the logo appears is **20 × 20 px**, in the chat list. |

Logos are displayed at 20 px (chat list), 28 px (picker, replies) and 56 px (new-chat screen).

## Updating

Add or replace a file, then refresh the browser. You don't need to restart. Phones pick up the new logo on their next refresh.
