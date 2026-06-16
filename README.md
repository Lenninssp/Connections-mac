# Connections

A minimalist macOS mind-map app. Paste a paragraph, extract keywords with AI or a local algorithm, then build a graph entirely from the keyboard.

---

## Features

- **AI keyword extraction** via DeepSeek, or a local TF-IDF algorithm when offline
- **Force-directed graph** — nodes repel each other and spring toward their connections, settling like Obsidian's graph view
- **Fully keyboard-driven** — select, connect, color, and delete nodes without touching the mouse
- **Four edge styles** — line, arrow, dashed, dashed arrow
- **Node colors** — 9 vibrant palette colors, persisted per node
- **Infinite canvas** — zoom and pan with keyboard or trackpad
- **Sessions** — multiple named workspaces, with duplicate and rename support
- **SQLite persistence** — everything survives restarts, zero cloud dependency
- **Minimalist design** — black + one accent color you choose

---

## Requirements

- macOS 13 or later
- Xcode command-line tools (`xcode-select --install`)
- A DeepSeek API key (get one at [platform.deepseek.com](https://platform.deepseek.com))

---

## Setup

1. Clone the repo:
   ```bash
   git clone <repo-url>
   cd connections
   ```

2. Add your DeepSeek API key to `.env`:
   ```bash
   echo "DEEPSEEK_API_KEY=sk-..." > .env
   ```

3. Build and launch:
   ```bash
   ./build.sh
   ```
   This compiles a release build, wraps it in `Connections.app`, and opens it.

4. **Optional** — add to your PATH for quick access:
   ```bash
   # Already done if ~/bin is in your PATH
   connections   # launches the app from any terminal
   ```

---

## How to Use

### 1 — Start a session
Press `⌘N` or click **+ New Session** in the sidebar.

### 2 — Generate a graph
Paste any paragraph into the input panel at the bottom, choose the number of keywords (2–7), pick **AI** or **Local**, and press **Generate** (or `⌘↩`).

Nodes appear on the canvas and the physics simulation settles them automatically.

### 3 — Add nodes manually
Press `n` anywhere on the canvas, type a word, press `↩` to confirm or `Esc` to cancel.

### 4 — Connect nodes
```
1        →  select node [1]
c        →  enter connect mode
2        →  target node [2]
1        →  choose edge style: line
```
Edge styles: `1` line · `2` arrow · `3` dashed · `4` dashed arrow

### 5 — Color a node
```
1        →  select node [1]
p        →  open color picker
3        →  apply Yellow
0        →  clear color (back to default)
```

### 6 — Delete a node
```
1        →  select node [1]
d        →  delete (removes attached edges too)
```

### 7 — Navigate the canvas
| Action | Keyboard | Trackpad |
|--------|----------|----------|
| Zoom in | `⌘=` or `⌘+` | Pinch out |
| Zoom out | `⌘-` | Pinch in |
| Reset view | `⌘0` | — |
| Pan | `⌘←` `⌘→` `⌘↑` `⌘↓` | Two-finger scroll |
| Drag node | — | Click & drag |

---

## Keyboard Reference

### Global
| Key | Action |
|-----|--------|
| `⌘N` | New session |
| `⌘Z` | Undo |
| `⌘I` | Toggle input panel |
| `⌘,` | Settings |
| `⌘=` / `⌘+` | Zoom in |
| `⌘-` | Zoom out |
| `⌘0` | Reset zoom & pan |
| `⌘←↑→↓` | Pan canvas |

### Node selection (idle)
| Key | Action |
|-----|--------|
| `n` | Add new node |
| `1`–`9` | Select node by label |
| `a`–`z` *(skip c, d, n)* | Select node by label (nodes 10–32) |

### Node selected
| Key | Action |
|-----|--------|
| `c` | Connect to another node |
| `p` | Open color picker |
| `d` | Delete node |
| `Esc` | Deselect |

### Color picker
| Key | Action |
|-----|--------|
| `1` Red · `2` Orange · `3` Yellow | Apply color |
| `4` Green · `5` Cyan · `6` Blue | Apply color |
| `7` Indigo · `8` Purple · `9` Pink | Apply color |
| `0` | Clear color |
| `Esc` | Back to selected |

### Connecting
| Key | Action |
|-----|--------|
| Node label key | Pick target |
| `Esc` | Cancel |

### Edge style
| Key | Style |
|-----|-------|
| `1` | ────── line |
| `2` | ──────> arrow |
| `3` | - - - - dashed |
| `4` | - - - -> dashed arrow |

---

## Node Labels

Nodes are labeled in this order as you add them:

| Range | Labels |
|-------|--------|
| 1–9 | `1` `2` `3` `4` `5` `6` `7` `8` `9` |
| 10–32 | `a` `b` `e` `f` `g` `h` `i` `j` `k` `l` `m` `o` `p` `q` `r` `s` `t` `u` `v` `w` `x` `y` `z` |
| 33+ | `!` `@` `#` `$` `%` `^` `&` `*` … |

Letters `c`, `d`, and `n` are skipped as they are reserved as commands.

---

## Settings

Open with `⌘,`:

- **Accent color** — the primary UI color used for borders, buttons, and selections. Six presets + a custom color well.
- **Default word count** — how many keywords to extract (2–7).
- **AI toggle** — switch between DeepSeek and the local algorithm.

---

## Architecture

```
Sources/Connections/
├── ConnectionsApp.swift          # @main App entry
├── AppState.swift                # Central ObservableObject + keyboard state machine
├── Models/
│   ├── WordNode.swift            # Node: position, velocity, colorIndex
│   ├── Edge.swift                # Connection between two nodes
│   ├── EdgeStyle.swift           # line / arrow / dashed / dashedArrow
│   ├── Session.swift             # Named workspace with nodes and edges
│   ├── NodeLabel.swift           # Maps node number → keyboard key
│   └── NodeColor.swift           # 9-color vibrant palette
├── Services/
│   ├── DeepSeekService.swift     # URLSession REST client (no SDK)
│   ├── KeywordExtractor.swift    # Local TF-IDF + stop-word removal
│   └── DatabaseManager.swift     # Raw SQLite3 — no ORM
├── Physics/
│   └── ForceDirectedLayout.swift # Spring simulation at 60 fps, auto-pauses
└── Views/
    ├── ContentView.swift         # NavigationSplitView root
    ├── SidebarView.swift         # Session list
    ├── MainGraphView.swift       # Graph + toolbar
    ├── GraphCanvas.swift         # SwiftUI Canvas rendering + overlays
    ├── InputPanelView.swift      # Paragraph input + controls
    └── SettingsView.swift        # Preferences
```

**Zero third-party dependencies.** Network calls use `URLSession`, the database uses the system `libsqlite3`, keyword extraction is pure Swift, and the physics engine is a hand-rolled force-directed simulation.

Data is stored at:
```
~/Library/Application Support/Connections/connections.db
```

---

## Building from Source

```bash
# Debug build (fast compile)
swift build

# Release build + app bundle (use this to run)
./build.sh
```

The `build.sh` script:
1. Loads `DEEPSEEK_API_KEY` from `.env`
2. Compiles a release binary with `swift build -c release`
3. Generates `AppIcon.icns` from a CoreGraphics Swift script
4. Wraps everything into `Connections.app`
5. Opens the app with `open`
