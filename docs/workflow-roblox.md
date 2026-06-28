# The broken box — Workflow de Desenvolvimento

## Setup Inicial

```bash
# 1. Clone
git clone https://github.com/rodaquino-OMNI/the-broken-box.git
cd the-broken-box

# 2. Rojo live sync
rojo serve

# 3. Build standalone (.rbxlx)
rojo build -o TheBrokenBox.rbxlx
```

## Ciclo Diário de Desenvolvimento

### Fluxo com Rojo Live Sync
1. Terminal: `rojo serve` (deixa rodando)
2. Roblox Studio: Plugins → Rojo → Connect → `localhost:34872`
3. Editar código no VS Code → salva → aparece no Studio instantaneamente
4. Testar: F5 no Roblox Studio (Play)
5. Para multiplayer: Test → Clients and Servers → 1 server + N clients

### Fluxo com Build (.rbxlx)
1. `rojo build -o TheBrokenBox.rbxlx`
2. Abrir `TheBrokenBox.rbxlx` no Roblox Studio
3. Testar: F5
4. **Nota:** Build é snapshot — não sincroniza com mudanças no código

### Teste Rápido (Recomendado)
```
⌘Q fecha Studio → abre .rbxlx → F5 → envia Output
```
Rojo live sync não é confiável para testes — prefira build direto.

## Debugging

### Output Window
- **Edit mode:** mostra apenas syntax errors (parse)
- **Play mode (F5):** mostra `print()` e runtime errors
- PT-BR: `Exibir → Saída`

### Client-Server Error Cascade
Se o servidor crasha (algum ModuleScript falha), RemoteEvents NUNCA são criados.
Isso causa erros no cliente como "RemoteEvent not found".
**Sempre corrija erros do servidor primeiro** — erros do cliente desaparecem quando o servidor inicia.

## Git Workflow

```bash
# Commitar
git add -A
git commit -m "feat: descrição da feature"

# Push
git push origin main

# Ver status
git status --short
```

## Estrutura de Arquivos

```
src/
├── server/                          → ServerScriptService
│   ├── GameManager.server.lua       → Entry point (Init/Start wiring)
│   ├── Services/                    → Domain services
│   │   ├── MatchService.lua
│   │   ├── HunterService.lua
│   │   ├── SurvivorService.lua
│   │   ├── MissionService.lua
│   │   ├── CycleService.lua
│   │   ├── EscapeService.lua
│   │   ├── MapService.lua
│   │   ├── LobbyService.lua
│   │   ├── ShopService.lua
│   │   └── AudioService.lua
│   └── Events/                      → RemoteEvent handlers
│       ├── PlayerEvents.lua
│       ├── HunterEvents.lua
│       ├── SurvivorEvents.lua
│       ├── MissionEvents.lua
│       └── EscapeEvents.lua
├── client/                          → StarterPlayerScripts
│   ├── ClientManager.client.lua     → Entry point
│   ├── UI/                          → ScreenGuis
│   ├── Input/                       → InputManager
│   ├── Camera/                      → CameraManager
│   └── Audio/                       → AudioManager
└── shared/                          → ReplicatedStorage
    ├── GameConstants.lua            → SINGLE SOURCE OF TRUTH
    ├── Events/                      → RemoteEvent definitions
    ├── Util/                        → Signal, MathUtil
    └── MapData/                     → Map coordinates
```

## Padrões de Código

### Server Scripts
```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.GameConstants)
```

### Client LocalScripts
```lua
--!strict
-- ATENÇÃO: em Rojo, use script.Parent para módulos irmãos
local InputManager = require(script.Parent.Input.InputManager)
local CameraManager = require(script.Parent.Camera.CameraManager)
```

### Require Paths (Rojo)
| Alvo | Path |
|------|------|
| Server service | `require(ServerScriptService.Services.X)` |
| Client module | `require(script.Parent.X)` |
| Shared module | `require(ReplicatedStorage.X)` |

## Convenções

- `--!strict` no topo de TODO .lua
- `print("[TheBrokenBox] ...")` para logging
- `task.wait()` em vez de `wait()`
- `RunService.Heartbeat` para game loop (NUNCA `while true do wait()`)
- Identificadores ASCII-only (sem acentos)
- Comentários em PT-BR
- Server-authoritative: toda lógica validada no servidor
- RemoteEvents > RemoteFunctions (comunicação assíncrona)
- Pattern Init/Start em todos os serviços
- Signal pub/sub para comunicação entre serviços

## Pitfalls Comuns (Luau/Rojo)

1. **`require(script.X)` em LocalScripts** → use `require(script.Parent.X)`
2. **`as Type` assertions** → use `: Type` annotations
3. **Acentos em identificadores** → ASCII-only
4. **`goto continue`** → `continue` é keyword reservada
5. **`FindFirstChild("Event")`** → use `IsA("RemoteEvent")` para filtrar
6. **`TextLineSpacing`** → não existe no Roblox
7. **M1 hitbox atravessa parede** → por design; não é bug
8. **Projéteis param na parede** → apenas Bazuca, Tinta, agarrões
