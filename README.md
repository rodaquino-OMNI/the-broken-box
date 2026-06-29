# 📦 The Broken Box

> *An asymmetric horror survival game for Roblox — 1 Hunter vs 1–7 Survivors.*

[![Roblox](https://img.shields.io/badge/Platform-Roblox-E2231A?logo=roblox&logoColor=white)](https://www.roblox.com)
[![Luau](https://img.shields.io/badge/Language-Luau-00A2FF)](https://luau-lang.org)
[![Rojo](https://img.shields.io/badge/Sync-Rojo%207.x-4E9A3E)](https://rojo.space)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 🎮 What is The Broken Box?

**The Broken Box** is an asymmetric horror PvP multiplayer game built exclusively for Roblox. One player takes the role of **the Hunter** — a supernatural creature with terrifying unique abilities — while 1 to 7 players cooperate as **Survivors**, fighting not to fix generators and escape, but to simply **stay alive** until the match timer runs out.

When the Cycle ends, three gates burst open. Every living Survivor has **60 seconds** to sprint to freedom before the map crumbles. Missions were optional — but the ones nobody finished just became the escape's biggest obstacles.

Inspired by **Pwned by 14:00**, **Dead by Daylight**, and **Flee the Facility**, The Broken Box carves its own lane: the tension of resistance-and-flight, not repair-and-escape.

---

## 🕹️ Core Gameplay Loop

```
PREPARATION  →  RESISTANCE (240s)  →  ESCAPE (60s window)  →  RESULTS
```

### 🔴 Phase 1 — Resistance

- The **Hunter** patrols, hunts, and uses supernatural abilities
- **Survivors** evade, jump-dodge attacks, and optionally complete **Missions**
- Each completed mission: **−10s on the Cycle** (speeds up escape), **+coins**, and **disarms a hazard** for the escape phase
- Death is permanent — eliminated players spectate or return to the lobby

### 🟡 Phase 2 — Escape

- Triggered when the **Cycle timer hits zero**
- All **3 gates open simultaneously**
- Survivors have a **60-second window** (−5s for each incomplete mission, minimum 10s)
- Incomplete missions spawn environmental hazards; the map begins to crumble
- **Victory conditions:** Full Escape (all survive), Partial Escape (some survive), or Containment (Hunter wins)

---

## 👥 Characters (MVP)

### 🗡️ The Hunter

| Character | HP | Key Mechanics |
|---|---|---|
| **O Distorcido** | 2000 | Fury/Rage system — grows stronger as players fight back. Stretched Arm (ranged grab), Scream (AoE slow), Rage Mode (speed burst, empowered attacks) |

### 🏃 Survivors

| Character | HP | Speed | Playstyle |
|---|---|---|---|
| **Médico** | 80 | 22 | Healer — Healing Potion & Charge ability |
| **Soldado** | 120 | 20 | Disabler — Tactical Dash & Bazooka (stuns Hunter) |
| **Sackboy** | 110 | 26 | Disruptor — Ink (3 charges, blinds Hunter) & Surge |
| **Robô** | 150 | 18 | Tank — Shield Block, Grab, Sacrifice (self-destruct) |

---

## 🗺️ Map — Criatividade Morta *(Dead Creativity)*

A cardboard toy-world gone wrong. Three handcrafted structures define the map's identity:

| Structure | Role | Description |
|---|---|---|
| **O Castelo** *(The Castle)* | Chase loops | Tall climbable exterior, walkable interior with towers and a drawbridge |
| **A Caverna** *(The Cave)* | Hiding | Dimly lit grotto with toy bodies littering the interior |
| **O Estoque de Materiais** *(The Stockroom)* | Evasion | A maze of shelves and corridors — mannequins fused to the shelving |

**10 missions** per match, randomized in type and position every game:
- **V1 — Breaker** (circuit-flip mini-game)
- **V2 — Generator** (timing challenge)
- **V3 — Oil Machine** (Flee the Facility-style hacking)

---

## 🎨 Aesthetic

The Broken Box leans into **retraux Roblox-first** visuals — not a port, an identity:

- **R6 rigs**, studs, flat textures, low-poly models (~1000–1500 tris)
- Washed-out, desaturated color palette drifting into darkness
- **Bitcrushed / lo-fi audio** — SFX and soundtrack feel like old Roblox sounds processed through a toy speaker
- Dynamic 3-layer music stems: *Calm → Alert (60s of Hunter nearby) → Chase (30s active pursuit)*
- Heartbeat audio + screen-edge distortion when the Hunter is within 20–40 studs

No blood. No gore. No cheap jump-scares. Just dread.

---

## 🧱 Technical Architecture

The Broken Box is built on a clean, beginner-friendly server-authoritative architecture:

```
the-broken-box/
├── src/
│   ├── server/          # ServerScriptService — game logic lives here
│   │   ├── GameManager.server.lua
│   │   └── Services/    # MatchService, HunterService, SurvivorService,
│   │                    # MissionService, CycleService, EscapeService...
│   ├── client/          # StarterPlayerScripts — UI, input, camera, audio
│   │   ├── ClientManager.client.lua
│   │   ├── UI/
│   │   ├── Input/
│   │   ├── Camera/
│   │   └── Audio/
│   └── shared/          # ReplicatedStorage — constants, events, utilities
│       ├── GameConstants.lua   ← single source of truth for ALL numbers
│       ├── Events/
│       └── Util/              # Signal (pub/sub), MathUtil
├── docs/                      # GDD, Architecture, Epics, Asset guides
├── default.project.json       # Rojo sync config
└── TheBrokenBox.rbxlx         # Roblox place file (build artifact)
```

**Key principles:**
- 🔒 **Server-authoritative** — all game logic (damage, collision, state) runs on the server
- 📖 **Single source of truth** — `GameConstants.lua` holds every numeric value; nothing is hardcoded
- 📡 **Signal pub/sub** — services communicate via `Signal.lua`, never by direct coupling
- ⚡ **RemoteEvents over RemoteFunctions** — async communication, no thread-blocking
- 🚫 **No external frameworks** — vanilla ModuleScripts only (Knit-free, AeroGameFramework-free)
- ✅ **`--!strict` everywhere** — Luau type-checking enforced in every file

---

## 🚀 Getting Started

### Prerequisites

- [Roblox Studio](https://www.roblox.com/create) installed
- [Rojo 7.x](https://rojo.space) installed

### Setup

```bash
# Clone the repository
git clone https://github.com/rodaquino-OMNI/the-broken-box.git
cd the-broken-box

# Option A — Live sync (edit code in VS Code, see changes instantly in Studio)
rojo serve
# Then in Roblox Studio: Plugins → Rojo → Connect → localhost:34872

# Option B — Build a standalone place file
rojo build -o TheBrokenBox.rbxlx
# Then open TheBrokenBox.rbxlx in Roblox Studio and press F5
```

### Daily Dev Workflow

```bash
# Run live sync
rojo serve

# Edit Lua files in VS Code → changes sync to Studio instantly
# Press F5 in Studio to test

# For multiplayer testing:
# Studio → Test → Clients and Servers → 1 server + N clients
```

> **Tip:** If a server-side ModuleScript fails, RemoteEvents won't be created and you'll see "RemoteEvent not found" on the client. **Always fix server errors first.**

---

## 📚 Documentation

| Document | Description |
|---|---|
| [`docs/gdd.md`](docs/gdd.md) | Full Game Design Document (v2.0) — canonical source for all mechanics |
| [`docs/architecture.md`](docs/architecture.md) | Technical architecture — services, patterns, data flow |
| [`docs/epics.md`](docs/epics.md) | Development epics & user stories (E1–E9) |
| [`docs/assets-guide.md`](docs/assets-guide.md) | Visual asset guide — models, map, UI specs |
| [`docs/audio-asset-guide.md`](docs/audio-asset-guide.md) | Audio asset guide — SFX and music specs |
| [`docs/workflow-roblox.md`](docs/workflow-roblox.md) | Development workflow — Rojo, debugging, Git |
| [`project-context.md`](project-context.md) | Project overview and quick reference |

---

## 🗺️ Roadmap

**MVP (current scope):**
- [x] Project structure and architecture
- [ ] Core movement, stamina, and jump-dodge system (E1)
- [ ] O Distorcido — Hunter with Fury/Rage system (E2)
- [ ] 4 Survivor classes (E3)
- [ ] Map — Criatividade Morta (E4)
- [ ] 10 missions + Cycle system (E5)
- [ ] Escape phase + victory conditions (E6)
- [ ] Coins, DataStore, shop (E7)
- [ ] Dynamic audio system (E8)
- [ ] Balancing + playtesting (E9)

**Post-MVP:**
- New Hunters with unique mechanics
- New maps and biomes
- Expanded cosmetics and shop
- Ranked/competitive mode

---

## 🤝 Contributing

This is a solo learning project. Issues and suggestions are welcome — open a [GitHub Issue](https://github.com/rodaquino-OMNI/the-broken-box/issues) if you spot a bug or have an idea.

---

## 📄 License

[MIT](LICENSE) — see the LICENSE file for details.

---

<p align="center">
  <em>Built on Roblox. Coded in Luau. Made with cardboard and dread.</em>
</p>
