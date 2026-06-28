# The broken box — Project Context

## Overview
- **Name:** The broken box
- **Genre:** Terror Assimétrico (Horror PvP)
- **Platform:** Roblox (exclusive)
- **Engine:** Roblox Engine / Luau
- **Inspiration:** Pwned by 14:00, Dead by Daylight, Flee the Facility
- **Developer:** familia (beginner Roblox/Luau)

## Core Loop
Resistência (Cycle 240s) → Caçador caça, Sobreviventes fazem missões opcionais (-10s/missão)
→ Cycle zera → 3 Portões abrem → Fuga (60s janela, -5s/missão pendente)

## MVP Scope
- 1 Hunter: O Distorcido (HP 2000, Fury/Rage system)
- 4 Survivors: Médico, Soldado, Sackboy, Robô
- 1 Map: Criatividade Morta (cardboard toy world, 3 structures)
- 10 Missions: V1 Breaker, V2 Generator, V3 Oil Machine
- Lobby: A Caixa + O Vendedor (coin shop)
- DataStore: coins + unlocks

## Technical Stack
- **Sync:** Rojo 7.x (build .rbxlx)
- **VCS:** Git + GitHub
- **Patterns:** server-authoritative, RemoteEvents, GameConstants single source of truth, Signal pub/sub, Init/Start pattern
- **Code style:** --!strict, PT-BR comments, ASCII-only identifiers

## Project Structure
```
src/
├── server/          # ServerScriptService
│   ├── GameManager.server.lua
│   ├── Services/    # Domain services
│   └── Events/      # RemoteEvent handlers
├── client/          # StarterPlayerScripts
│   ├── ClientManager.client.lua
│   ├── UI/          # ScreenGuis
│   ├── Input/       # Input processing
│   ├── Camera/      # Camera management
│   └── Audio/       # Audio playback
└── shared/          # ReplicatedStorage
    ├── GameConstants.lua
    ├── Events/      # RemoteEvent definitions
    ├── Util/        # Signal, MathUtil
    └── MapData/     # Map data
```

## Key Design Decisions
- No Derrubado/capture/rescue — death is permanent (HP→0 = spectate/lobby)
- Both sides have stamina (covers running + jumping)
- Jump can dodge M1 hitbox (10 stamina, 2s cd)
- Hunter doesn't see Survivor classes/HP (only alive count)
- Missions don't lock player position (only attention via UI minigame)
- Mission penalties only activate during Escape phase
- Hunter stun → 2s i-frames (anti-stunlock)
- Rage pauses Cycle timer

## References
- GDD: docs/gdd.md (full game design)
- Architecture: docs/architecture.md (technical architecture)
- Epics: docs/epics.md (development epics & stories)
