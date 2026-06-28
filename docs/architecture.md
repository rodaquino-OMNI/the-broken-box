---
title: "The broken box — Arquitetura do Jogo"
project: "The broken box"
engine: "Roblox (Luau)"
sync: "Rojo 7.6.1"
version: "1.0"
created: "2026-06-28"
author: "familia"
references:
  - "docs/gdd.md (Game Design Document v2.0)"
  - "project-context.md (Contexto do Projeto)"
---

# The broken box — Documento de Arquitetura

**Autor:** familia
**Plataforma:** Roblox (Luau, Rojo 7.6.1)
**Nível do Desenvolvedor:** Iniciante
**Idioma da Documentação:** PT-BR
**Data:** 28 de Junho de 2026

> **Referência canônica de design:** [docs/gdd.md](gdd.md) — Game Design Document v2.0.
> Este documento de arquitetura é a **segunda etapa** do pipeline BMAD: GDD → Arquitetura → Épicos e Histórias.
> Toda decisão de implementação deve seguir o que está definido aqui e no GDD.

---

## 1. Visão Geral da Arquitetura

### 1.1 Filosofia Técnica

The broken box segue os seguintes princípios arquiteturais, adaptados para um desenvolvedor iniciante:

| Princípio | Descrição | Motivação |
|-----------|-----------|-----------|
| **Server-Authoritative** | Toda lógica de jogo (dano, colisão, estado) roda no servidor. Cliente envia input, recebe estado. | Segurança anti-exploit; consistência entre jogadores. |
| **Single Source of Truth** | `GameConstants.lua` contém TODO dado numérico do jogo. Nenhum número hardcoded em serviços. | Ajuste de balanceamento centralizado; evita inconsistências. |
| **Signal Pub/Sub** | Serviços se comunicam via `Signal.lua` (padrão observer), nunca por acoplamento direto. | Desacoplamento; cada serviço é testável isoladamente. |
| **Init/Start Pattern** | `Init()` = setup síncrono (requires, cache de services). `Start()` = setup assíncrono (listeners, `task.spawn()`). | Ordem de inicialização previsível; fácil de dar wire em novos serviços. |
| **RemoteEvent > RemoteFunction** | Comunicação cliente↔servidor usa RemoteEvents (assíncronos). Apenas `GetMatchInfo` usa RemoteFunction. | Performance; evita bloqueio de thread por timeout. |
| **Módulos Puros** | Sem frameworks externos (Knit, AeroGameFramework). Apenas ModuleScripts vanilla. | Curva de aprendizado baixa; controle total. |
| **Comentários em PT-BR** | Todo comentário e documentação em português brasileiro. Identificadores em ASCII (inglês técnico). | Consistência; o dev é falante nativo de PT-BR. |
| **`--!strict` obrigatório** | Todo arquivo `.lua` começa com `--!strict`. | Type-checking do Luau; menos bugs em tempo de execução. |

### 1.2 Diagrama de Alto Nível

```
┌──────────────────────────────────────────────────────────────────────┐
│                        THE BROKEN BOX                                │
│                    Arquitetura Cliente-Servidor                       │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────┐          ┌─────────────────────────────┐   │
│  │      CLIENTE         │          │         SERVIDOR             │   │
│  │  (StarterPlayer)     │          │   (ServerScriptService)      │   │
│  │                      │  Remote  │                              │   │
│  │  ClientManager ◄─────┼─Events──┼─► GameManager (entry point)  │   │
│  │  ├─ InputManager     │          │   ├─ MatchService            │   │
│  │  ├─ CameraManager    │          │   ├─ HunterService           │   │
│  │  ├─ UIManager        │          │   ├─ SurvivorService         │   │
│  │  │  ├─ SurvivorHUD   │          │   ├─ MissionService          │   │
│  │  │  ├─ KillerHUD     │          │   ├─ CycleService            │   │
│  │  │  ├─ CharSelectUI  │          │   ├─ EscapeService           │   │
│  │  │  ├─ MissionUI     │          │   ├─ MapService              │   │
│  │  │  └─ GameOverUI    │          │   ├─ LobbyService            │   │
│  │  └─ AudioManager     │          │   ├─ ShopService             │   │
│  │                      │          │   └─ AudioService            │   │
│  └──────────────────────┘          └──────────────┬──────────────┘   │
│                                                   │                  │
│  ┌────────────────────────────────────────────────┼──────────────┐   │
│  │          COMPARTILHADO (ReplicatedStorage)      │              │   │
│  │                                                 │              │   │
│  │  GameConstants.lua  ◄────────── FONTE ÚNICA ───┘              │   │
│  │  Events/                                                       │   │
│  │  ├─ PlayerActionEvent.lua    (Cliente → Servidor)              │   │
│  │  ├─ GameStateEvent.lua       (Servidor → Cliente)              │   │
│  │  └─ UISyncEvent.lua          (Servidor → Cliente, HUD)         │   │
│  │  Util/                                                         │   │
│  │  ├─ Signal.lua               (Pub/Sub)                         │   │
│  │  ├─ MathUtil.lua             (Distância, clamp, cone)          │   │
│  │  └─ RemoteEventUtils.lua     (FireAll/Filter helpers)          │   │
│  │  MapData/                                                     │   │
│  │  └─ MapData.lua              (Spawns, estruturas, candidatos)  │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  ARMAZENAMENTO (ServerStorage)                                │   │
│  │  assets/  — Modelos, animações, sons, texturas                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Estrutura de Diretórios

```
the-broken-box/
├── default.project.json          ← Configuração Rojo (sync com Roblox Studio)
├── .gitignore                    ← Ignora build/, .rbxlx, .DS_Store
├── README.md                     ← Visão geral do projeto
├── project-context.md            ← Contexto técnico para agentes de IA
├── docs/
│   ├── gdd.md                    ← Game Design Document (fonte canônica de design)
│   ├── architecture.md           ← ESTE DOCUMENTO — Arquitetura técnica
│   └── epics.md                  ← Épicos e histórias de desenvolvimento
├── src/
│   ├── server/                   → ServerScriptService
│   │   ├── GameManager.server.lua         ← Ponto de entrada do servidor
│   │   ├── Services/                      ← Serviços de domínio (lógica de jogo)
│   │   │   ├── MatchService.lua           ← Estado da partida, papéis, vitória
│   │   │   ├── HunterService.lua          ← Lógica do Distorcido (Caçador)
│   │   │   ├── SurvivorService.lua        ← Lógica dos 4 Sobreviventes
│   │   │   ├── MissionService.lua         ← Missões V1/V2/V3 e distribuição
│   │   │   ├── CycleService.lua           ← Cronômetro do Ciclo (240s)
│   │   │   ├── EscapeService.lua          ← Fuga: portões, janela, perigos
│   │   │   ├── MapService.lua             ← Mapa: spawns, estruturas, dados
│   │   │   ├── LobbyService.lua           ← Lobby A Caixa, seleção, início
│   │   │   ├── ShopService.lua            ← Loja, moedas, DataStore
│   │   │   └── AudioService.lua           ← Áudio dinâmico server-side
│   │   ├── Events/                        ← Handlers de RemoteEvent
│   │   │   ├── PlayerEvents.lua           ← Spawn, morte, disconnect
│   │   │   ├── HunterEvents.lua           ← Inputs do Caçador
│   │   │   └── SurvivorEvents.lua         ← Inputs dos Sobreviventes
│   │   └── Data/                          ← (futuro) Módulos de DataStore
│   │       └── DataStoreManager.lua       ← Wrapper com retry para DataStore
│   ├── client/                   → StarterPlayerScripts
│   │   ├── ClientManager.client.lua       ← Ponto de entrada do cliente
│   │   ├── Input/
│   │   │   └── InputManager.lua           ← WASD, binds de habilidade
│   │   ├── Camera/
│   │   │   └── CameraManager.lua          ← 3ª pessoa padrão, toggle 1ª
│   │   ├── UI/
│   │   │   ├── UIManager.lua              ← Orquestrador de telas
│   │   │   ├── SurvivorHUD.lua            ← HP, stamina, aliados vivos
│   │   │   ├── KillerHUD.lua              ← Fúria, cooldowns, vivos
│   │   │   ├── CharacterSelectUI.lua      ← Seleção de personagem no lobby
│   │   │   ├── MissionUI.lua              ← Minigame de missão (V1/V2/V3)
│   │   │   ├── GameOverUI.lua             ← Resultado, stats, voltar
│   │   │   └── ShopUI.lua                 ← Interface da loja (O Vendedor)
│   │   └── Audio/
│   │       └── AudioManager.lua           ← Playback de stems, SFX, batimentos
│   ├── shared/                   → ReplicatedStorage
│   │   ├── GameConstants.lua              ← FONTE ÚNICA DE VERDADE (todos os números)
│   │   ├── Events/                        ← Definições de RemoteEvent
│   │   │   ├── PlayerActionEvent.lua      ← Cliente → Servidor
│   │   │   ├── GameStateEvent.lua         ← Servidor → Cliente (estado)
│   │   │   └── UISyncEvent.lua            ← Servidor → Cliente (HUD)
│   │   ├── Util/                          ← Utilitários compartilhados
│   │   │   ├── Signal.lua                 ← Pub/Sub (implementação própria)
│   │   │   ├── MathUtil.lua               ← Distância, clamp, cone, raycast
│   │   │   └── RemoteEventUtils.lua       ← Helpers: FireAll, FireFilter
│   │   └── MapData/                       ← Dados do mapa
│   │       └── MapData.lua                ← Coordenadas, spawns, candidatos
│   └── assets/                   → ServerStorage
│       ├── Models/                        ← Modelos R6 do Caçador, Sobreviventes
│       ├── Animations/                    ← Animações (~35: pulo, habilidades, morte)
│       ├── Audio/                         ← Stems (3 camadas) + SFX bitcrushed
│       ├── Textures/                      ← Texturas retraux/papelão
│       └── MapParts/                      ← Partes do mapa Criatividade Morta
└── _bmad/                        ← Artefatos de planejamento BMAD
    └── gds/
        └── config.yaml                    ← Configuração do pipeline GDS
```

---

## 3. GameConstants.lua — Fonte Única de Verdade

### 3.1 Propósito

`GameConstants.lua` é o módulo compartilhado (ReplicatedStorage) que contém **todos os dados numéricos do jogo**: HP, velocidades, danos, cooldowns, durações, custos de stamina, raios de hitbox e configurações de partida. Nenhum outro arquivo contém números hardcoded — todos referenciam `GameConstants`.

**Regra de ouro:** se um número aparece na [tabela-mestra do GDD](../docs/gdd.md#tabela-mestra-de-balanceamento-protótipo), ele vive em `GameConstants.lua`.

### 3.2 Estrutura do Módulo

```lua
--!strict
--[[
  GameConstants.lua
  Fonte única de verdade para TODOS os dados numéricos do jogo.
  Referenciado por serviços (server/) e UIs (client/).
  Compartilhado via ReplicatedStorage.

  Convenção de nomenclatura:
    - Chaves: PascalCase para tabelas, UPPER_SNAKE para valores escalares
    - Sub-tabelas organizadas por domínio: Hunter, Survivors, Game, Missions, Stamina
    - Comentários em PT-BR
]]

local GameConstants = {}

-- ============================================================
-- DADOS GERAIS DA PARTIDA (ref: GDD §M1-M4, §Tabela-Mestra)
-- ============================================================
GameConstants.Game = {
	SURVIVORS_PER_MATCH = 4,          -- Mínimo de Sobreviventes (máx. 7)
	PREPARATION_TIME = 5,             -- Tempo de preparação antes da caçada (s)
	CYCLE_BASE_DURATION = 240,        -- Duração base do Ciclo (s)
	CYCLE_EXTEND_PER_DEATH = 20,      -- +20s no Ciclo por morte de Sobrevivente
	CYCLE_REDUCE_PER_MISSION = 10,    -- -10s no Ciclo por missão concluída
	ESCAPE_WINDOW_BASE = 60,         -- Janela de Fuga base (s)
	ESCAPE_WINDOW_REDUCE_PER_MISSION = 5,  -- -5s por missão pendente
	ESCAPE_WINDOW_FLOOR = 10,        -- Piso da janela de Fuga (s)
	RAGE_PAUSES_CYCLE = true,        -- Rage pausa o cronômetro do Ciclo
}

-- ============================================================
-- STAMINA E MOVIMENTO (ref: GDD §M4)
-- ============================================================
GameConstants.Stamina = {
	SPEND_PER_SECOND = 7,            -- Gasto de stamina ao correr (/s)
	REGEN_PER_SECOND = 9,            -- Regeneração de stamina (/s)
	EXHAUST_DELAY = 0.5,             -- Atraso pós-esgotamento antes de regenerar (s)
	JUMP_COST = 10,                  -- Custo de stamina por pulo
	JUMP_COOLDOWN = 2,               -- Cooldown entre pulos (s)
}

-- ============================================================
-- CAÇADOR — O DISTORCIDO (ref: GDD §M5-M7, §Design de Inimigo)
-- ============================================================
GameConstants.Hunter = {
	NAME = "O Distorcido",
	MAX_HP = 2000,
	BASE_SPEED = 26,                  -- studs/s
	RAGE_SPEED = 28,                  -- studs/s durante Rage
	STAMINA = 110,

	-- Fúria e Rage (ref: GDD §M5)
	FURY = {
		MAX = 100,                    -- Medidor vai de 0 a 100+
		RAGE_THRESHOLD = 80,          -- Limiar para ativar Rage
		GAIN_ON_ATTACKED = 10,        -- Fúria ao ser atacado/atordoado
		GAIN_PER_SECOND_PROXIMITY = 1, -- Fúria/s após 20s a ≤40 studs
		PROXIMITY_RADIUS = 40,        -- Raio de proximidade (studs)
		PROXIMITY_TIME = 20,          -- Tempo para começar a ganhar (s)
		RAGE_WINDUP = 5,              -- Windup da transformação (s)
		RAGE_DURATION_BASE = 30,      -- Duração base do Rage (s)
		RAGE_EXTEND_PER_KILL = 10,    -- +10s por morte durante Rage
		RAGE_PULSE_DAMAGE = 20,       -- Dano em área ao ativar Rage
		RAGE_PULSE_RADIUS = 30,       -- Raio do pulso de ativação (studs)
	},

	-- Stun e I-frames (ref: GDD §M6)
	STUN_I_FRAMES = 2,                -- Invencibilidade pós-stun (s)

	-- Habilidades (ref: GDD §Design de Inimigo, §Tabela-Mestra)
	M1 = {
		DAMAGE = 20,                  -- Dano base do Tapa
		RAGE_DAMAGE = 25,             -- Dano em Rage
		HITBOX_COUNT = 5,             -- Quantidade de hitboxes
		HITBOX_DURATION = 0.5,        -- Duração total das hitboxes (s)
		WINDUP = 0.6,                 -- Tempo de preparação (s)
		COOLDOWN = 0.8,               -- Tempo entre ataques (s)
		KNOCKBACK = 3,                -- Empurrão (studs)
	},
	PULL = {
		WINDUP = 1,                   -- Tempo de preparação (s)
		COOLDOWN = 12,                -- Tempo de recarga (s)
		SPEED = 15,                   -- Velocidade do projétil (studs/s)
		DURATION = 2,                 -- Duração máxima do braço (s)
		RANGE = 30,                   -- Alcance máximo (studs)
		STUN_DURATION = 0.5,          -- Duração do stun ao puxar (s)
	},
	ROAR = {
		WINDUP = 2,                   -- Tempo de preparação (s)
		COOLDOWN = 25,                -- Tempo de recarga (s)
		SLOW_AMOUNT = 40,             -- Porcentagem de lentidão (%)
		SLOW_DURATION = 3,            -- Duração da lentidão (s)
		SLOW_RADIUS = 60,             -- Raio da lentidão (studs)
		REVEAL_DURATION = 4,          -- Duração da revelação (s)
		REVEAL_RADIUS = 100,          -- Raio da revelação (studs)
		RAGE_DAMAGE = 10,             -- Dano adicional em Rage
	},
}

-- ============================================================
-- SOBREVIVENTES (ref: GDD §Personagens — Elenco Completo)
-- ============================================================
GameConstants.Survivors = {
	-- Valores compartilhados entre todos os Sobreviventes
	BASE_SPEED = 22,                  -- Velocidade base padrão (studs/s)

	MEDICO = {
		NAME = "Médico",
		MAX_HP = 80,
		SPEED = 22,
		STAMINA = 100,
		FREE = true,                  -- Grátis no MVP
		ROLE = "Suporte/Cura",
		-- Habilidades (ref: GDD §Médico)
		POTION = {
			WINDUP = 2,
			COOLDOWN = 15,
			HEAL = 25,
			RADIUS = 12,
		},
		CHARGE = {
			WINDUP = 1,
			COOLDOWN = 10,
			DASH_DISTANCE = 15,
			RADIUS = 10,              -- Cubo 10×10×10 ao redor
			DAMAGE = {0, 10, 20, 30}, -- Escala por aliados curados
		},
	},

	SOLDADO = {
		NAME = "Soldado",
		MAX_HP = 120,
		SPEED = 20,
		STAMINA = 110,
		FREE = false,                 -- Pago (moedas)
		ROLE = "Controle à Distância",
		-- Habilidades (ref: GDD §Soldado)
		DASH = {
			WINDUP = 0.5,
			COOLDOWN = 20,
			DURATION_MAX = 15,
			DAMAGE = 20,
			KNOCKBACK = 10,
			SILENCE_DURATION = 3,
		},
		BAZOOKA = {
			WINDUP = 2,
			COOLDOWN = 30,
			CANCEL_COOLDOWN = 15,
			AIM_MAX = 10,
			DAMAGE = 40,
			HITBOX = {3, 3, 100},     -- Largura, Altura, Comprimento (studs)
		},
		-- LMS condicional: vs Soldado Fundido → SPEED 22, +30% dano Bazuca
	},

	SACKBOY = {
		NAME = "Sackboy",
		MAX_HP = 110,
		SPEED = 26,
		STAMINA = 70,
		FREE = true,                  -- Grátis no MVP
		ROLE = "Hit & Run / Controle",
		-- Habilidades (ref: GDD §Sackboy)
		INK = {
			WINDUP = {1, 2, 3},       -- Por carga
			COOLDOWN = 30,
			MAX_CHARGES = 3,
			HITBOX = {3, 3, 100},
			DAMAGE = {5, 10, 15},      -- Por carga
			SLOW = {30, 40, 0},       -- % por carga
			SLOW_DURATION = 2,
			SILENCE_DURATION = {0, 4, 0},
			STUN_DURATION = {0, 0, 2},
			BLUR = {false, false, true},
		},
		SURGE = {
			COOLDOWN = 20,
			DURATION = 5,
			SPEED_BONUS = 6,
		},
	},

	ROBO = {
		NAME = "Robô",
		MAX_HP = 150,
		SPEED = 18,
		STAMINA = 110,
		FREE = false,                 -- Pago (moedas)
		ROLE = "Tanque / Sacrifício",
		CAN_BE_HEALED_BY_MEDICO = false, -- Só se cura pelo próprio Block
		-- Habilidades (ref: GDD §Robô)
		GRAB = {
			WINDUP = 1,
			COOLDOWN = 22,
			SPEED = 15,
			DURATION = 2,
			RANGE = 30,
			INVINCIBILITY_DURATION = 8, -- Invencibilidade que dá ao Caçador
		},
		BLOCK = {
			WINDOW = 1.5,
			COOLDOWN = 14,
			SILENCE_DURATION = 3,
			SELF_HEAL = 10,
			DAMAGE = 10,
		},
		SELFDESTRUCT = {
			WINDUP = 3,
			COOLDOWN = 60,
			BOOST_DURATION = 5,
			SELF_DAMAGE = 40,
			SLOW_DURATION = 8,
			THROW_DISTANCE = 100,
			STUN_DURATION = 6,
			DAMAGE = 100,
		},
	},
}

-- ============================================================
-- MISSÕES (ref: GDD §M1)
-- ============================================================
GameConstants.Missions = {
	TOTAL_PER_MATCH = 10,             -- Total de missões por partida
	MIN_EACH_VARIANT = 1,             -- Mínimo de 1 de cada variável

	V1_BREAKER = {
		NAME = "Disjuntor de Energia",
		REPETITIONS = 4,              -- Completar 4 vezes
		PERIGO = "Escuridão localizada",
	},
	V2_GENERATOR = {
		NAME = "Gerador",
		CABLES = 5,                   -- Conectar 5 cabos
		REPETITIONS = 4,
		PERIGO = "Barreira elétrica",
		BARRIER_DAMAGE = 10,          -- Dano por travessia
		BARRIER_IMMUNITY = 5,         -- Janela de imunidade (s)
	},
	V3_OIL = {
		NAME = "Máquina de Petróleo",
		REPETITIONS = 1,              -- Uma vez (minigame de ponteiro)
		PERIGO = "Poça de óleo",
		SLOW_PERCENT = 35,            -- Lentidão ao pisar (%)
	},
}

-- ============================================================
-- ECONOMIA (ref: GDD §Progressão de Jogador)
-- ============================================================
GameConstants.Economy = {
	COIN_MISSAO = 15,                -- Moedas por missão concluída
	COIN_FUGA = 40,                  -- Moedas por fuga bem-sucedida (só quem escapou)
	UNLOCK_COST_SOLDADO = 150,       -- Custo de desbloqueio do Soldado
	UNLOCK_COST_ROBO = 200,          -- Custo de desbloqueio do Robô
}

-- ============================================================
-- HITBOXES E LAYERS (ref: GDD §Sistema de Hitboxes e Layers)
-- ============================================================
GameConstants.Hitbox = {
	-- Regra: dano aplicado 1 vez por alvo colidido (nunca empilha no mesmo alvo)

	-- Tipos de hitbox
	FORMS = {
		PROJECTILE = "Projétil",       -- Viaja, para em parede/alvo
		INSTANT_LINE = "Linha",        -- Instantânea, para na parede
		AREA_CUBE = "Cubo",            -- Cubo único grande, atravessa parede
		BODY = "Corpo",                -- Hitbox de corpo do personagem
	},

	-- Regras de parede
	WALL_RULES = {
		PROJECTILES_STOP = true,       -- Projéteis/mísseis param na parede/chão
		AREA_CUBES_IGNORE = true,      -- Cubos grandes ignoram ambiente (atravessam)
	},

	-- Layers de colisão (nomes semânticos)
	LAYERS = {
		HUNTER_ATTACK = "HunterAttack",      -- Ataques do Caçador → Sobreviventes
		SURVIVOR_ATTACK = "SurvivorAttack",  -- Ataques dos Sobreviventes → Caçador
		ENVIRONMENT = "Environment",          -- Paredes, chão, obstáculos
		INVINCIBLE = "Invincible",            -- Durante i-frames (Caçador)
	},
}

-- ============================================================
-- ÁUDIO (ref: GDD §Design de Áudio de Tensão)
-- ============================================================
GameConstants.Audio = {
	-- Trilha dinâmica: distâncias de crossfade
	LAYER_CALM_MAX = 60,              -- Até 60 studs: camada Calma
	LAYER_ALERT_MAX = 30,             -- Até 30 studs: camada Alerta
	-- Abaixo de 30 studs: camada Perseguição
	CROSSFADE_DURATION = 2,           -- Duração do crossfade entre camadas (s)

	-- Efeitos de proximidade
	HEARTBEAT_RADIUS = 40,            -- Raio para batimentos audíveis (studs)
	DISTORTION_RADIUS = 20,           -- Raio para distorção de borda (studs)
}

-- ============================================================
-- DESEMPENHO (ref: GDD §Requisitos de Desempenho)
-- ============================================================
GameConstants.Performance = {
	TARGET_FPS_PC = 60,
	TARGET_FPS_MOBILE = 30,
	MAX_PING_MS = 100,
	MAX_MEMORY_MB = 500,
	MAX_LOAD_TIME_S = 15,
	MAX_PARTICLES_MOBILE = 200,
	MAX_TRIS_PER_MODEL = 2000,
}

return GameConstants
```

### 3.3 Como Referenciar GameConstants

**No servidor (todo serviço):**
```lua
local GameConstants = require(game:GetService("ReplicatedStorage").GameConstants)
local MEDICO_HP = GameConstants.Survivors.MEDICO.MAX_HP  -- 80
```

**No cliente (toda UI e manager):**
```lua
local GameConstants = require(game:GetService("ReplicatedStorage").GameConstants)
local TARGET_FPS = GameConstants.Performance.TARGET_FPS_PC  -- 60
```

---

## 4. Padrão Init/Start

### 4.1 Conceito

Inspirado no lifecycle do Roblox, todo serviço (server) e módulo do cliente implementa duas fases:

| Fase | Responsabilidade | Síncrono? |
|------|-----------------|-----------|
| **`Init()`** | `require()` de dependências, cache de serviços Roblox (`Players`, `ReplicatedStorage`), criação de sinais, setup de estruturas de dados. | Sim |
| **`Start()`** | Registro de listeners (`PlayerAdded`, `PlayerRemoving`, sinais de outros serviços), `task.spawn()` para loops, conexão de RemoteEvents. | Pode usar `task.spawn()` |

### 4.2 Template de Serviço

```lua
--!strict
--[[
  NomeDoServico.lua
  Descrição do serviço em PT-BR.
  Referências: GDD §X.Y
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependências compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

local NomeDoServico = {}
NomeDoServico.Name = "NomeDoServico"

-- Sinais do serviço (outros serviços podem escutar)
NomeDoServico.somethingHappened = Signal.new()

-- Estado interno
local _state = {}

--[[
  Init()
  Setup síncrono: requires, cache, criação de estruturas.
  Chamado pelo GameManager em initServices().
]]
function NomeDoServico.Init()
	print("[TheBrokenBox] NomeDoServico.Init()")
	-- Cache de referências, requires adicionais
end

--[[
  Start()
  Setup assíncrono: listeners, RemoteEvents, task.spawn().
  Chamado pelo GameManager em startServices().
]]
function NomeDoServico.Start()
	print("[TheBrokenBox] NomeDoServico.Start()")
	-- Conexão de Players.PlayerAdded, sinais de outros serviços
end

return NomeDoServico
```

### 4.3 Template do GameManager (Orquestrador)

```lua
--!strict
-- GameManager.server.lua — Ponto de entrada do servidor
local services = {}

-- Lista de serviços na ordem de Init
local serviceModules = {
	{ name = "MatchService",    path = "server.Services.MatchService" },
	{ name = "MapService",      path = "server.Services.MapService" },
	{ name = "HunterService",   path = "server.Services.HunterService" },
	{ name = "SurvivorService", path = "server.Services.SurvivorService" },
	{ name = "MissionService",  path = "server.Services.MissionService" },
	{ name = "CycleService",    path = "server.Services.CycleService" },
	{ name = "EscapeService",   path = "server.Services.EscapeService" },
	{ name = "LobbyService",    path = "server.Services.LobbyService" },
	{ name = "ShopService",     path = "server.Services.ShopService" },
	{ name = "AudioService",    path = "server.Services.AudioService" },
}

-- Fase 1: Init síncrono de todos os serviços
local function initServices()
	for _, mod in ipairs(serviceModules) do
		local svc = require(script.Services[mod.name])
		svc.Init()
		services[mod.name] = svc
	end
end

-- Fase 2: Conexão de sinais entre serviços (wiring)
local function wireServiceSignals()
	-- Exemplo: MatchService avisa outros serviços sobre mudança de estado
	services.MatchService.matchStateChanged:Connect(function(newState)
		-- Roteia para serviços interessados
	end)
end

-- Fase 3: Start assíncrono de todos os serviços
local function startServices()
	for _, mod in ipairs(serviceModules) do
		services[mod.name].Start()
	end
end

-- Execução
initServices()
wireServiceSignals()
startServices()

print("[TheBrokenBox] GameManager pronto. Aguardando jogadores...")
```

---

## 5. Sistema de Comunicação (Networking)

### 5.1 Modelo Server-Authoritative

```
┌──────────────────────────────────────────────────────────────┐
│                  FLUXO DE COMUNICAÇÃO                         │
│                                                              │
│  CLIENTE                         SERVIDOR                    │
│  ┌──────────┐                   ┌──────────────┐             │
│  │ Input do │  PlayerActionEvent │ Validação    │             │
│  │ jogador  │ ───FireServer()──► │ do input     │             │
│  │ (WASD,   │                   │ (anti-cheat) │             │
│  │  skill)  │                   └──────┬───────┘             │
│  └──────────┘                          │                     │
│                                        ▼                     │
│                              ┌──────────────────┐            │
│                              │ Lógica de jogo   │            │
│                              │ (serviços)       │            │
│                              │ - Dano/Colisão   │            │
│                              │ - Estado          │            │
│                              │ - Vitória         │            │
│                              └────┬─────────────┘            │
│                                   │                          │
│  ┌──────────┐    GameStateEvent  │    UISyncEvent            │
│  │ Renderiza│ ◄──FireClient()───┘ ◄──FireClient()──┐        │
│  │ estado   │    (mudanças de     (HUD: HP,         │        │
│  │ visual   │     estado Macro)    stamina, timer)  │        │
│  └──────────┘                                       │        │
│                                                     │        │
│  CLIENTE                          SERVIDOR          │        │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 RemoteEvents — Os 3 Canais

| RemoteEvent | Direção | Propósito | Localização |
|-------------|---------|-----------|-------------|
| `PlayerActionEvent` | Cliente → Servidor | Input do jogador: mover, pular, usar habilidade, interagir com missão | `ReplicatedStorage.Events.PlayerActionEvent` |
| `GameStateEvent` | Servidor → Cliente | Mudanças macro de estado: início/fim de partida, papéis atribuídos, morte, fuga | `ReplicatedStorage.Events.GameStateEvent` |
| `UISyncEvent` | Servidor → Cliente | Sincronização de HUD em tempo real: HP, stamina, Fúria, cooldowns, timer do Ciclo | `ReplicatedStorage.Events.UISyncEvent` |

### 5.3 Definição de Mensagens

#### PlayerActionEvent (Cliente → Servidor)

```lua
-- PlayerActionEvent.MESSAGES
local MESSAGES = {
	-- Movimento
	MOVE = "MOVE",                      -- { direction: Vector3, sprinting: bool }
	JUMP = "JUMP",                      -- {}
	TOGGLE_CAMERA = "TOGGLE_CAMERA",   -- { mode: "FirstPerson" | "ThirdPerson" }

	-- Caçador
	HUNTER_M1 = "HUNTER_M1",           -- { aimPosition: Vector3 }
	HUNTER_PULL = "HUNTER_PULL",       -- { aimDirection: Vector3 }
	HUNTER_ROAR = "HUNTER_ROAR",       -- {}
	HUNTER_RAGE = "HUNTER_RAGE",       -- {}

	-- Sobreviventes
	SURVIVOR_ABILITY_1 = "SURVIVOR_A1", -- { aimPosition: Vector3 }
	SURVIVOR_ABILITY_2 = "SURVIVOR_A2", -- { aimPosition: Vector3 }
	SURVIVOR_ABILITY_3 = "SURVIVOR_A3", -- { aimPosition: Vector3 } (Robô)

	-- Interação
	INTERACT_MISSION = "INTERACT_MISSION", -- { missionId: string }
	INTERACT_PORTAL = "INTERACT_PORTAL",   -- { portalId: string }

	-- Lobby
	SELECT_CHARACTER = "SELECT_CHARACTER", -- { characterClass: string }
	READY_UP = "READY_UP",                -- {}
	BUY_UNLOCK = "BUY_UNLOCK",            -- { characterClass: string }

	-- Pós-morte
	SPECTATE_NEXT = "SPECTATE_NEXT",      -- {}
	RETURN_TO_LOBBY = "RETURN_TO_LOBBY",  -- {}
}
```

#### GameStateEvent (Servidor → Cliente)

```lua
-- GameStateEvent.MESSAGES
local MESSAGES = {
	-- Lobby
	MATCH_STATE = "MATCH_STATE",           -- { state: "Lobby"|"Selecting"|"Playing"|"Escaping"|"Ended" }
	CHARACTER_SELECT = "CHARACTER_SELECT", -- { availableCharacters: {...}, timer: number }
	CHARACTER_SELECTED = "CHARACTER_SELECTED", -- { userId: number, characterClass: string }
	YOUR_CHARACTER = "YOUR_CHARACTER",     -- { characterClass: string, isHunter: bool }

	-- Partida
	MATCH_STARTED = "MATCH_STARTED",       -- { cycleDuration: number, missionCount: number }
	ROLE_ASSIGNED = "ROLE_ASSIGNED",       -- { role: "Hunter"|"Survivor", survivorsCount: number }
	PLAYER_DIED = "PLAYER_DIED",           -- { userId: number, killerId: number }
	PLAYER_ESCAPED = "PLAYER_ESCAPED",     -- { userId: number, portalId: number }
	ESCAPE_STARTED = "ESCAPE_STARTED",     -- { windowDuration: number, portals: {...}, hazards: {...} }
	ESCAPE_ENDED = "ESCAPE_ENDED",         -- {}
	MATCH_ENDED = "MATCH_ENDED",           -- { winner: "Survivors"|"Hunter", result: "FugaTotal"|"FugaParcial"|"Contencao", rewards: {...} }

	-- Sistema
	DATASTORE_LOADED = "DATASTORE_LOADED", -- { coins: number, unlocked: {...} }
	ERROR = "ERROR",                       -- { message: string }
}
```

#### UISyncEvent (Servidor → Cliente)

```lua
-- UISyncEvent.MESSAGES
-- Enviado a cada frame (~60Hz) via RunService.Heartbeat no servidor
local MESSAGES = {
	HUD_UPDATE = "HUD_UPDATE",  -- {
		-- { hp: number, stamina: number, fury: number, cycleTime: number,
		--   aliveCount: number, cooldowns: {...}, proximityLevel: number }
	}
}
```

### 5.4 RemoteEventUtils.lua

Utilitário para enviar RemoteEvents de forma tipada e segura:

```lua
--!strict
-- RemoteEventUtils.lua — Helpers para enviar RemoteEvents
local RemoteEventUtils = {}

-- Envia para todos os clientes
function RemoteEventUtils.fireAll(remoteEvent: RemoteEvent, messageType: string, data: any)
	remoteEvent:FireAllClients({ type = messageType, data = data })
end

-- Envia para um jogador específico
function RemoteEventUtils.firePlayer(remoteEvent: RemoteEvent, player: Player, messageType: string, data: any)
	remoteEvent:FireClient(player, { type = messageType, data = data })
end

-- Envia para todos exceto um jogador
function RemoteEventUtils.fireAllExcept(remoteEvent: RemoteEvent, exceptPlayer: Player, messageType: string, data: any)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if player ~= exceptPlayer then
			remoteEvent:FireClient(player, { type = messageType, data = data })
		end
	end
end

-- Filtra por papel (Hunter/Survivor)
function RemoteEventUtils.fireByRole(remoteEvent: RemoteEvent, role: string, messageType: string, data: any)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		-- Acessa role do player via MatchService ou atributo
		-- (implementação real usa MatchService:getPlayerRole())
	end
end

return RemoteEventUtils
```

### 5.5 Eventos de Roblox Usados

| Evento Roblox | Uso | Onde |
|---------------|-----|------|
| `Players.PlayerAdded` | Spawn do jogador, carregar DataStore | GameManager, MatchService, LobbyService |
| `Players.PlayerRemoving` | Cleanup, salvar DataStore, ajustar partida | MatchService, ShopService |
| `RunService.Heartbeat` | Game loop (~60Hz): lógica de servidor, sync de HUD | Server: CycleService, Client: UISyncEvent |
| `RunService.RenderStepped` | Lógica do cliente pré-renderização | CameraManager |
| `Workspace.Touched` | Colisão de hitboxes, detecção de portão | Hitbox system, EscapeService |

---

## 6. Sistema Signal (Pub/Sub)

### 6.1 Signal.lua — Implementação

```lua
--!strict
--[[
  Signal.lua
  Implementação simples do padrão Observer (Pub/Sub).
  Usado para comunicação desacoplada entre serviços do servidor.
  Inspirado em: GoodSignal (Roblox community pattern)
]]
local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self._listeners = {}
	self._onceListeners = {}
	return self
end

-- Registra um listener permanente
function Signal:Connect(callback: (...any) -> ())
	table.insert(self._listeners, callback)
	return {
		Disconnect = function()
			for i, cb in ipairs(self._listeners) do
				if cb == callback then
					table.remove(self._listeners, i)
					break
				end
			end
		end,
	}
end

-- Registra um listener que dispara apenas uma vez
function Signal:Once(callback: (...any) -> ())
	table.insert(self._onceListeners, callback)
end

-- Dispara o sinal, chamando todos os listeners
function Signal:Fire(...)
	for _, callback in ipairs(self._listeners) do
		task.spawn(callback, ...)  -- task.spawn evita que um listener bloqueie os outros
	end
	for _, callback in ipairs(self._onceListeners) do
		task.spawn(callback, ...)
	end
	table.clear(self._onceListeners)
end

-- Remove todos os listeners
function Signal:Destroy()
	table.clear(self._listeners)
	table.clear(self._onceListeners)
end

return Signal
```

### 6.2 Sinais do Sistema (Catálogo)

Cada serviço expõe sinais para que outros serviços possam reagir a eventos sem acoplamento direto.

| Serviço | Sinal | Quando Dispara | Quem Escuta |
|---------|-------|---------------|-------------|
| **MatchService** | `matchStateChanged` | Estado da partida muda (Lobby→Selecting→Playing→Escaping→Ended) | Todos os serviços |
| **MatchService** | `rolesAssigned` | Papéis atribuídos (Hunter/Survivor) | HunterService, SurvivorService, UISync |
| **MatchService** | `playerDied` | Jogador morre (HP→0) | CycleService, EscapeService, UISync |
| **MatchService** | `playerEscaped` | Jogador atravessa portão | EscapeService, Economy |
| **HunterService** | `hunterStunned` | Caçador sofre stun | HunterService (i-frames), AudioService |
| **HunterService** | `rageActivated` | Rage ativado | CycleService (pausa), AudioService, UISync |
| **HunterService** | `rageDeactivated` | Rage termina | CycleService (resume), AudioService, UISync |
| **SurvivorService** | `survivorDamaged` | Sobrevivente recebe dano | AudioService (batimentos), UISync |
| **MissionService** | `missionCompleted` | Missão concluída | CycleService (-10s), UISync, ShopService (moedas) |
| **MissionService** | `allMissionsGenerated` | Missões da partida geradas | UISync (mostrar no mapa) |
| **CycleService** | `cycleTick` | Tick do Ciclo (1/s) | UISync, AudioService |
| **CycleService** | `cycleZero` | Ciclo chega a zero | EscapeService, MatchService |
| **EscapeService** | `escapeStarted` | Fuga inicia | AudioService, UISync, MapService |
| **EscapeService** | `escapeEnded` | Janela de Fuga fecha | MatchService (resolver vitória) |
| **LobbyService** | `characterSelected` | Jogador seleciona personagem | MatchService |
| **LobbyService** | `readyToStart` | Todos prontos/timer expirou | MatchService (iniciar partida) |
| **ShopService** | `coinsUpdated` | Moedas do jogador alteradas | UISync (atualizar HUD da loja) |

---

## 7. Sistema de Hitboxes

### 7.1 Arquitetura do Sistema

O sistema de hitboxes é **inteiramente server-side** para anti-exploit. O servidor cria regiões de detecção (usando `WorldRoot:GetPartBoundsInBox()` ou partes de colisão invisíveis) que representam cada ataque. Quando uma hitbox de ataque intersecta uma hitbox de corpo, o dano é aplicado.

```
┌──────────────────────────────────────────────────────────┐
│                 FLUXO DE HITBOX (SERVER)                  │
│                                                          │
│  Cliente envia input                                     │
│  (PlayerActionEvent: HUNTER_M1)                         │
│         │                                                │
│         ▼                                                │
│  Servidor valida:                                        │
│  - Cooldown disponível?                                  │
│  - Caçador está vivo?                                    │
│  - Não está stunado?                                     │
│         │                                                │
│         ▼                                                │
│  Servidor cria hitbox(es):                               │
│  - Calcula posição/orientação                            │
│  - Cria região de detecção (Box/Sphere)                  │
│  - Verifica colisão com hitboxes de corpo                │
│         │                                                │
│         ▼                                                │
│  Para cada alvo colidido:                                │
│  - Verifica layer (HunterAttack → Survivors apenas)      │
│  - Verifica i-frames/invencibilidade                     │
│  - Aplica dano (1x por alvo, nunca empilha)              │
│  - Aplica efeitos (stun, slow, knockback)                │
│  - Dispara sinais (survivorDamaged, hunterStunned)       │
│         │                                                │
│         ▼                                                │
│  Envia GameStateEvent/UISyncEvent aos clientes           │
│  afetados (HP, efeitos visuais)                          │
└──────────────────────────────────────────────────────────┘
```

### 7.2 Tipos de Hitbox e Implementação

| Ataque | Tipo | Implementação | Parâmetros (em GameConstants) |
|--------|------|---------------|-------------------------------|
| M1 (Tapa) | 5 detecções em cone | `OverlapParams` com filtro de layer; 5 verificações em 0,5s | `M1.HITBOX_COUNT`, `M1.DAMAGE` |
| Braço Esticado / Agarrar | Projétil móvel (parte que viaja) | Parte movida com `TweenService`; `Touched` event; para em parede/alvo | `PULL.SPEED`, `PULL.RANGE` |
| Bazuca / Arma de Tinta | Linha instantânea | `WorldRoot:Raycast()` na direção do olhar, alcance 100 studs | `BAZOOKA.HITBOX`, `INK.HITBOX` |
| Grito / Rage / Cura / Investida | Cubo único (área) | `WorldRoot:GetPartBoundsInRadius()` centrado no atacante | `ROAR.SLOW_RADIUS`, etc. |
| Block (Robô) | Cubo maior que corpo | `Touched` com área expandida durante janela de 1,5s | `BLOCK.WINDOW` |

### 7.3 Sistema de Layers

```lua
-- Configuração de colisão no servidor
local PhysicsService = game:GetService("PhysicsService")

-- Grupos de colisão
local COLLISION_GROUPS = {
	HUNTER_BODY = "HunterBody",
	SURVIVOR_BODY = "SurvivorBody",
	HUNTER_ATTACK = "HunterAttack",
	SURVIVOR_ATTACK = "SurvivorAttack",
	ENVIRONMENT = "Environment",
	INVINCIBLE = "Invincible",
}

-- Regras: quem colide com quem
-- HunterAttack → SurvivorBody (SIM)
-- SurvivorAttack → HunterBody (SIM)
-- HunterAttack → Invincible (NÃO — i-frames)
-- SurvivorAttack → Invincible (NÃO — i-frames)
-- Tudo → Environment (SIM, exceto cubos de área que ignoram)
```

### 7.4 Validação Server-Side

Toda colisão de hitbox é validada no servidor:

1. **Sanity check de distância:** o alvo está dentro do alcance máximo da habilidade?
2. **Sanity check de cooldown:** a habilidade está fora de cooldown?
3. **Sanity check de linha de visão:** para projéteis que param na parede, verificar se há obstrução.
4. **Layer check:** o ataque está colidindo com o tipo correto de alvo?
5. **Invincibility check:** o alvo está em i-frames ou invencibilidade?
6. **Dano único:** o mesmo alvo não pode receber dano 2+ vezes do mesmo ataque.

---

## 8. DataStore e Persistência

### 8.1 Arquitetura do DataStoreManager

```lua
--!strict
--[[
  DataStoreManager.lua
  Wrapper para Roblox DataStoreService com retry automático.
  Gerencia moedas e personagens desbloqueados.
  Referências: GDD §Progressão de Jogador, §Especificações Técnicas
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataStoreManager = {}

local MAX_RETRIES = 3
local RETRY_DELAY = 2  -- segundos entre tentativas

-- Estrutura padrão de dados do jogador
local DEFAULT_DATA = {
	coins = 0,
	unlocked = {
		["O Distorcido"] = true,
		["Sackboy"] = true,
		["Médico"] = true,
		["Soldado"] = false,
		["Robô"] = false,
	},
}

--[[
  Carrega dados do jogador com retry.
  Retorna DEFAULT_DATA em caso de falha.
]]
function DataStoreManager.loadPlayerData(player: Player): table
	local dataStore = DataStoreService:GetDataStore("PlayerData_" .. player.UserId)
	for attempt = 1, MAX_RETRIES do
		local success, data = pcall(function()
			return dataStore:GetAsync("Profile")
		end)
		if success then
			if data then
				return data
			else
				return DEFAULT_DATA
			end
		end
		warn("[TheBrokenBox] DataStore load falhou (tentativa " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(data))
		task.wait(RETRY_DELAY)
	end
	warn("[TheBrokenBox] DataStore load falhou após " .. MAX_RETRIES .. " tentativas. Usando dados padrão.")
	return DEFAULT_DATA
end

--[[
  Salva dados do jogador com retry.
  Agenda em BindToClose para evitar perda de dados.
]]
function DataStoreManager.savePlayerData(player: Player, data: table)
	local dataStore = DataStoreService:GetDataStore("PlayerData_" .. player.UserId)
	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			dataStore:SetAsync("Profile", data)
		end)
		if success then
			return true
		end
		warn("[TheBrokenBox] DataStore save falhou (tentativa " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(err))
		task.wait(RETRY_DELAY)
	end
	warn("[TheBrokenBox] DataStore save falhou após " .. MAX_RETRIES .. " tentativas.")
	return false
end

--[[
  Adiciona moedas ao jogador (server-side apenas).
  Dispara ShopService.coinsUpdated.
]]
function DataStoreManager.addCoins(player: Player, amount: number, playerData: table)
	playerData.coins = math.max(0, playerData.coins + amount)
end

--[[
  Desbloqueia personagem (server-side apenas).
  Verifica saldo de moedas.
]]
function DataStoreManager.unlockCharacter(player: Player, characterClass: string, playerData: table)
	if playerData.unlocked[characterClass] then
		return false, "Personagem já desbloqueado."
	end
	local cost = characterClass == "Soldado" and 150 or 200
	if playerData.coins < cost then
		return false, "Moedas insuficientes."
	end
	playerData.coins = playerData.coins - cost
	playerData.unlocked[characterClass] = true
	return true, nil
end

-- Salva dados de todos os jogadores ao fechar o servidor
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		-- ShopService mantém cache de playerData; salva no cleanup
	end
end)

return DataStoreManager
```

> **Nota para iniciante (familia):** DataStore **exige que o jogo esteja publicado no Roblox** para funcionar. Durante o desenvolvimento local (Roblox Studio), use um mock: armazene dados em uma tabela Lua em memória. O `DataStoreManager` pode detectar se está em Studio e alternar automaticamente.

---

## 9. Anti-Exploit

### 9.1 Medidas de Segurança

| Categoria | Medida | Onde |
|-----------|--------|------|
| **Server-Authoritative** | Toda validação de hitbox, dano e estado no servidor. Cliente é "dumb terminal". | Todos os serviços |
| **Sanity Checks** | Servidor valida cooldowns, distâncias, linha de visão antes de aplicar dano. | HunterService, SurvivorService |
| **Anti Speed-Hack** | Servidor verifica `Humanoid.WalkSpeed` periodicamente; se > máximo permitido, corrige. | MatchService (Heartbeat) |
| **Anti Teleport** | Servidor verifica `Character.Position` a cada ~0,5s; se distância percorrida > velocidade máxima × tempo, teleporta de volta. | MatchService (Heartbeat) |
| **Anti HP/Stamina Edit** | Servidor é dono dos valores de HP e stamina. Cliente recebe via UISyncEvent (read-only). | HunterService, SurvivorService |
| **Anti Moeda Fraud** | Moedas só são adicionadas via server-side (missão concluída, fuga). Nunca via RemoteEvent confiável. | MissionService, EscapeService, ShopService |
| **Assimetria de Informação** | Servidor NÃO envia classe/HP dos Sobreviventes ao cliente do Caçador (só contagem de vivos). | GameStateEvent (filtro por papel) |
| **RemoteEvent Validation** | Todo `OnServerEvent` valida: jogador está na partida? Está vivo? Papel corresponde? | Events/ handlers |
| **DataStore Lock** | Atualizações de DataStore usam `UpdateAsync` para evitar race conditions em escritas concorrentes. | DataStoreManager (futuro) |
| **Anti Exploit de Missão** | Progresso de missão validado no servidor; minigame não confia em input cru do cliente. | MissionService |

### 9.2 Template de Handler Seguro

```lua
-- Exemplo: handler de HUNTER_M1 com validação completa
local function onHunterM1(player: Player, data: { aimPosition: Vector3 })
	-- 1. Jogador está na partida?
	if not MatchService.isPlayerInMatch(player) then return end

	-- 2. Jogador é o Caçador?
	if MatchService.getPlayerRole(player) ~= "Hunter" then return end

	-- 3. Caçador está vivo?
	if not HunterService.isAlive() then return end

	-- 4. Caçador não está stunado?
	if HunterService.isStunned() then return end

	-- 5. M1 está fora de cooldown?
	if not HunterService.canUseM1() then return end

	-- 6. Distância do aim é razoável?
	local character = player.Character
	if not character then return end
	local distance = (data.aimPosition - character.PrimaryPart.Position).Magnitude
	if distance > 15 then return end  -- Sanity check

	-- 7. Executa o ataque
	HunterService.performM1(data.aimPosition)
end
```

---

## 10. Máquina de Estados da Partida

### 10.1 Estados

```
              ┌──────────┐
              │  LOBBY   │  Jogadores na Caixa (hub)
              └────┬─────┘
                   │ Host inicia / todos prontos
                   ▼
              ┌────────────┐
              │ SELECTING  │  Seleção de personagem (timer)
              └────┬───────┘
                   │ Timer expira / todos selecionaram
                   ▼
              ┌────────────┐
              │ PREPARING  │  5s de preparação, spawn no mapa
              └────┬───────┘
                   │ Timer de 5s termina
                   ▼
              ┌────────────┐
              │  PLAYING   │  Resistência: Caçador caça, Sobreviventes sobrevivem
              │  (CYCLE)   │  Ciclo conta regressivamente (240s ± eventos)
              └────┬───────┘
                   │ Ciclo chega a zero
                   ▼
              ┌────────────┐
              │  ESCAPING  │  Fuga: portões abertos, janela de 60s
              └────┬───────┘
                   │ Janela fecha OU todos escapam/morrem
                   ▼
              ┌──────────┐
              │  ENDED    │  Resultado, recompensas, tela de fim
              └────┬─────┘
                   │ Retornar ao lobby
                   ▼
              ┌──────────┐
              │  LOBBY   │  (reinicia o ciclo)
              └──────────┘
```

### 10.2 Transições e Gatilhos

| De | Para | Gatilho | Serviço Responsável |
|----|------|---------|---------------------|
| LOBBY | SELECTING | Host inicia partida (mín. 2 jogadores) | LobbyService |
| SELECTING | PREPARING | Timer de seleção expira (15s) ou todos prontos | LobbyService → MatchService |
| PREPARING | PLAYING | Timer de 5s de preparação termina | MatchService |
| PLAYING | ESCAPING | `cycleZero` (Ciclo chega a 0) | CycleService → EscapeService |
| ESCAPING | ENDED | Janela fecha OU todos escapam/morrem | EscapeService → MatchService |
| ENDED | LOBBY | Timer de resultado expira (10s) ou comando | MatchService → LobbyService |

---

## 11. Serviços — Detalhamento

### 11.1 GameManager.server.lua (Orquestrador)

**Responsabilidade:** Ponto de entrada do servidor. Inicializa todos os serviços em ordem, conecta sinais entre eles, gerencia o lifecycle.

**Localização:** `src/server/GameManager.server.lua`

**Fluxo:**
1. `initServices()` — `require` + `Init()` síncrono de todos os serviços
2. `wireServiceSignals()` — conecta sinais entre serviços (ex.: `cycleZero` → `EscapeService.startEscape`)
3. `startServices()` — `Start()` assíncrono de todos os serviços (listeners, `task.spawn()`)

### 11.2 MatchService

**Responsabilidade:** Máquina de estados da partida, atribuição de papéis (Hunter/Survivor), controle de jogadores vivos/mortos, resolução de vitória.

**Referências GDD:** §Condições de Vitória e Derrota, §M3

- Mantém a máquina de estados: LOBBY → SELECTING → PREPARING → PLAYING → ESCAPING → ENDED
- Atribui aleatoriamente 1 Hunter e N Survivors
- Rastreia jogadores vivos, mortos, escapados
- Resolve condição de vitória:
  - **Fuga Total:** todos os vivos escaparam → Sobreviventes vencem
  - **Fuga Parcial:** ao menos 1 escapou → Sobreviventes vencem (só quem escapou ganha moedas)
  - **Contenção Total:** ninguém escapou → Caçador vence
- **Assimetria de informação:** não envia classe/HP dos Sobreviventes ao Caçador

**Sinais expostos:** `matchStateChanged`, `rolesAssigned`, `playerDied`, `playerEscaped`

### 11.3 HunterService

**Responsabilidade:** Toda a lógica do Caçador (O Distorcido): M1, Braço Esticado, Grito, Rage, Fúria, Stun/I-frames.

**Referências GDD:** §M5 (Fúria e Rage), §M6 (Stun e I-frames), §M7 (Câmera e Visão), §Design de Inimigo

- **M1 (Tapa):** cria 5 hitboxes em cone em 0,5s; valida cooldown (0,8s)
- **Braço Esticado:** projétil que viaja 2s a 15 studs/s; puxa Sobrevivente; stun 0,5s
- **Grito:** cubo de área radial; slow 40% por 3s (raio 60); revelação 4s (raio 100); 10 de dano em Rage
- **Fúria:** medidor 0-100+; ganha ao ser atacado (+10), por proximidade (+1/s), por morte no Rage (+10)
- **Rage:** ativável com medidor ≥80 e fora da Fuga; windup 5s; pulso de 20 dano (raio 30); buffs M1+5, vel+2; pausa Ciclo; dura 30s +10s/morte
- **Stun:** trava Caçador por duração da habilidade; ao sair, 2s de i-frames
- **I-frames:** Caçador sai da layer "atingível" por 2s pós-stun

**Sinais expostos:** `hunterStunned`, `rageActivated`, `rageDeactivated`

### 11.4 SurvivorService

**Responsabilidade:** Lógica dos 4 Sobreviventes (Médico, Soldado, Sackboy, Robô): habilidades, dano ao Caçador, vínculos LMS, cura.

**Referências GDD:** §Personagens — Elenco Completo (Sobreviventes), §Tabela-Mestra

- **Médico:** Poção em Área (cura 25, raio 12) + Investida Medicinal (dano 0-30 escala com curados)
- **Soldado:** Dash Tático (hitbox móvel, empurra+silêncio) + Bazuca (linha 3×3×100, dano 40)
- **Sackboy:** Arma de Tinta (3 cargas, slow/stun progressivo) + Surto (+6 vel por 5s)
- **Robô:** Agarrar (puxa Caçador, dá 8s invencibilidade) + Block (contra-ataque, autocura 10) + Autodestruição (dano 100, stun 6s)
- **LMS (Last Man Standing):** buffs condicionais quando é o último vivo
- **Cura:** apenas Médico (Poção) e Robô (Block); sem regen passiva
- **Dano ao Caçador:** validado server-side; 1x por alvo colidido

**Sinais expostos:** `survivorDamaged`

### 11.5 MissionService

**Responsabilidade:** Distribuição aleatória das 10 missões, lógica dos minigames V1/V2/V3, penalidades pendentes para a Fuga.

**Referências GDD:** §M1 (Missões)

- Gera 10 missões por partida: sorteia ~14 locais candidatos; tipo sorteado por local; mínimo 1 de cada variável
- **V1 Disjuntor:** minigame de alavancas (4 repetições); pendente → escuridão localizada na Fuga
- **V2 Gerador:** minigame de cabos (5 cabos, 4 repetições); pendente → barreira elétrica (10 dano/travessia, imunidade 5s)
- **V3 Máquina de Petróleo:** minigame de ponteiro (1 repetição); pendente → poça (35% slow)
- **Vulnerabilidade atencional:** minigame ocupa UI, não trava posição; mover cancela
- Concluir missão: `missionCompleted` → CycleService (-10s) + ShopService (+15 moedas) + desarma perigo

**Sinais expostos:** `missionCompleted`, `allMissionsGenerated`

### 11.6 CycleService

**Responsabilidade:** Cronômetro do Ciclo (240s base), eventos de ±tempo, pausa durante Rage.

**Referências GDD:** §M1 (missões -10s), §M3 (mortes +20s), §M5 (Rage pausa Ciclo), §Ritmo de Tensão

- Ciclo base: 240s, contagem regressiva
- Eventos que alteram o Ciclo:
  - Missão concluída: -10s (`missionCompleted`)
  - Morte de Sobrevivente: +20s (`playerDied`)
  - Rage ativo: pausa contagem (`rageActivated` → `rageDeactivated`)
- Tick a cada 1s: dispara `cycleTick`
- Quando chega a zero: dispara `cycleZero`

**Sinais expostos:** `cycleTick`, `cycleZero`

### 11.7 EscapeService

**Responsabilidade:** Fase de Fuga: abrir 3 portões, gerenciar janela de 60s, ativar perigos de missões pendentes, incêndio estético.

**Referências GDD:** §M2 (Portões e Fuga)

- **Gatilho:** `cycleZero` do CycleService
- **Portões:** 3 fixos (P1 Caverna, P2 Castelo, P3 Estoque)
- **Janela:** base 60s, -5s por missão pendente, piso 10s
- **Perigos:** cada missão pendente ativa seu perigo na Fuga (escuridão/barreira/poça)
- **Incêndio estético:** fogo visual sem dano
- **Encerramento:** janela fecha → mapa desmorona → `escapeEnded` → MatchService resolve vitória

**Sinais expostos:** `escapeStarted`, `escapeEnded`

### 11.8 MapService

**Responsabilidade:** Dados do mapa Criatividade Morta: spawns, posições das estruturas, candidatos de missão, posições dos portões.

**Referências GDD:** §Design do Mapa — Criatividade Morta

- Spawn points: 1 fixo para Caçador, 7 aleatórios para Sobreviventes
- 3 estruturas: Castelo (loop), Caverna (esconder), Estoque (despistar)
- ~14 locais candidatos de missão (10 ativos por partida)
- 3 portões fixos
- Dados de navegação: waypoints, zonas de perigo

**Sinais expostos:** nenhum (serviço passivo, fornece dados)

### 11.9 LobbyService

**Responsabilidade:** Lobby A Caixa: seleção de personagem, controle de início de partida, host assignment.

**Referências GDD:** §Lobby — A Caixa, §Personagens

- Gerencia o estado SELECTING: timer de 15s para seleção
- Personagens disponíveis: grátis (Distorcido, Sackboy, Médico) + desbloqueados
- Host (primeiro jogador) pode iniciar partida (mín. 2 jogadores)
- Atribui papéis: 1 Caçador aleatório entre quem tem Distorcido; demais = Sobreviventes

**Sinais expostos:** `characterSelected`, `readyToStart`

### 11.10 ShopService

**Responsabilidade:** Loja da Caixa (O Vendedor): compra de personagens com moedas, interface com DataStore.

**Referências GDD:** §MVP — Loja da Caixa e Moedas, §Progressão de Jogador

- Carrega dados do DataStore ao entrar (moedas, desbloqueios)
- Moedas ganhas: 15/missão (`missionCompleted`), 40/fuga (`playerEscaped`)
- Desbloqueio: Soldado (150 moedas), Robô (200 moedas)
- Salva dados ao sair (`PlayerRemoving`) e no `BindToClose`

**Sinais expostos:** `coinsUpdated`

### 11.11 AudioService

**Responsabilidade:** Orquestração de áudio server-side: transições de stem, comandos de SFX.

**Nota:** O processamento real de áudio é client-side (AudioManager), mas o servidor decide qual camada/efeito está ativo com base no estado do jogo.

**Referências GDD:** §Design de Áudio de Tensão

- Trilha em 3 camadas: Calma (≥60 studs), Alerta (30-60 studs), Perseguição (<30 studs)
- Crossfade de 2s entre camadas
- Batimentos cardíacos: audíveis a ≤40 studs
- Distorção de borda: ativa a ≤20 studs
- SFX de eventos: missão, fuga, fogo, morte

**Sinais expostos:** nenhum (serviço reativo, escuta outros sinais)

---

## 12. Cliente — Estrutura e Fluxo

### 12.1 ClientManager.client.lua

```lua
--!strict
-- ClientManager.client.lua — Ponto de entrada do cliente
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateEvent = require(ReplicatedStorage.Events.GameStateEvent)
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)

-- Módulos do cliente
local InputManager = require(script.Input.InputManager)
local CameraManager = require(script.Camera.CameraManager)
local UIManager = require(script.UI.UIManager)
local AudioManager = require(script.Audio.AudioManager)

-- Estado local do cliente
local localRole = nil  -- "Hunter" | "Survivor" | nil

local function onGameState(message)
	if message.type == GameStateEvent.MESSAGES.ROLE_ASSIGNED then
		localRole = message.data.role
		if localRole == "Hunter" then
			UIManager.showKillerHUD()
		else
			UIManager.showSurvivorHUD()
		end
	elseif message.type == GameStateEvent.MESSAGES.MATCH_ENDED then
		UIManager.showGameOver(message.data)
	end
	-- ... outros handlers de mensagem
end

-- Init dos módulos
InputManager.Init(PlayerActionEvent)
CameraManager.Init()
UIManager.Init()
AudioManager.Init()

-- Conexão de eventos
GameStateEvent.OnClientEvent:Connect(onGameState)

print("[TheBrokenBox] ClientManager pronto.")
```

### 12.2 Fluxo das UIs

| UI | Quando Ativa | Dependências |
|----|-------------|--------------|
| **CharacterSelectUI** | Estado SELECTING | LobbyService (server) |
| **ShopUI** | Estado LOBBY (A Caixa) | ShopService (server) |
| **SurvivorHUD** | Papel Survivor + PLAYING/ESCAPING | UISyncEvent (HP, stamina, timer) |
| **KillerHUD** | Papel Hunter + PLAYING/ESCAPING | UISyncEvent (Fúria, cooldowns, vivos) |
| **MissionUI** | Interagindo com missão | MissionService (server), Input cancel |
| **GameOverUI** | Estado ENDED | GameStateEvent (resultado, recompensas) |

---

## 13. Plano de Wiring — Serviços por Épico

### 13.1 E1 — Fundação: Movimento, Câmera e Stamina

**Serviços envolvidos:** MatchService (estado base), novo sistema de Stamina no SurvivorService+HunterService

**Módulos afetados:**
- `GameConstants.lua` — Adicionar seção `Stamina`, velocidades base
- `src/shared/Util/MathUtil.lua` — Criar (distância, clamp)
- `src/shared/Util/Signal.lua` — Criar (implementação pub/sub)
- `src/server/GameManager.server.lua` — Criar (Init/Start do MatchService)
- `src/server/Services/MatchService.lua` — Criar (máquina de estados, papéis)
- `src/server/Events/PlayerEvents.lua` — Criar (spawn, movimento)
- `src/client/ClientManager.client.lua` — Criar
- `src/client/Input/InputManager.lua` — Criar (WASD, pulo, binds)
- `src/client/Camera/CameraManager.lua` — Criar (3ª pessoa, toggle 1ª)
- `src/shared/Events/PlayerActionEvent.lua` — Criar
- `src/shared/Events/GameStateEvent.lua` — Criar
- `src/shared/Events/UISyncEvent.lua` — Criar
- `src/shared/Util/RemoteEventUtils.lua` — Criar

**Wiring:**
```
InputManager ──PlayerActionEvent──► PlayerEvents (server)
                                 ► MatchService (valida movimento)
MatchService ──GameStateEvent──► ClientManager (papel, estado)
MatchService ──UISyncEvent────► SurvivorHUD / KillerHUD (HP, stamina)
```

### 13.2 E2 — O Caçador: O Distorcido

**Serviços envolvidos:** HunterService

**Módulos afetados:**
- `GameConstants.lua` — Adicionar seção `Hunter` (completa)
- `src/server/Services/HunterService.lua` — Criar
- `src/server/Events/HunterEvents.lua` — Criar (handlers de M1, Braço, Grito, Rage)
- `src/client/UI/KillerHUD.lua` — Criar
- `src/shared/Events/PlayerActionEvent.lua` — Adicionar mensagens Hunter

**Wiring:**
```
HunterEvents ──► HunterService (valida e executa habilidades)
HunterService ──hunterStunned──► AudioService (SFX de stun)
HunterService ──rageActivated──► CycleService (pausa Ciclo)
HunterService ──rageDeactivated──► CycleService (resume Ciclo)
HunterService ──UISyncEvent──► KillerHUD (Fúria, cooldowns)
```

### 13.3 E3 — Sobreviventes: 4 Classes

**Serviços envolvidos:** SurvivorService

**Módulos afetados:**
- `GameConstants.lua` — Adicionar seção `Survivors` (completa)
- `src/server/Services/SurvivorService.lua` — Criar
- `src/server/Events/SurvivorEvents.lua` — Criar (handlers de habilidades)
- `src/client/UI/SurvivorHUD.lua` — Criar
- `src/shared/Events/PlayerActionEvent.lua` — Adicionar mensagens Survivor

**Wiring:**
```
SurvivorEvents ──► SurvivorService (valida e executa habilidades)
SurvivorService ──survivorDamaged──► AudioService (batimentos)
SurvivorService ──► GameStateEvent (playerDied quando HP→0)
SurvivorService ──UISyncEvent──► SurvivorHUD (HP, stamina, aliados)
```

### 13.4 E4 — O Mundo: Criatividade Morta + A Caixa

**Serviços envolvidos:** MapService, LobbyService (parcial)

**Módulos afetados:**
- `src/shared/MapData/MapData.lua` — Criar (spawns, estruturas, candidatos)
- `src/server/Services/MapService.lua` — Criar
- `src/server/Services/LobbyService.lua` — Criar (estrutura básica)
- `src/client/UI/CharacterSelectUI.lua` — Criar
- Assets do mapa (Models, Textures) — Criar/importar

**Wiring:**
```
MapService ──► MissionService (locais candidatos)
MapService ──► MatchService (spawn points)
LobbyService ──GameStateEvent──► CharacterSelectUI
```

### 13.5 E5 — Missões e Ciclo

**Serviços envolvidos:** MissionService, CycleService

**Módulos afetados:**
- `GameConstants.lua` — Adicionar seções `Missions`, `Game` (CYCLE_BASE_DURATION)
- `src/server/Services/MissionService.lua` — Criar
- `src/server/Services/CycleService.lua` — Criar
- `src/client/UI/MissionUI.lua` — Criar (minigames V1/V2/V3)

**Wiring:**
```
MissionService ──missionCompleted──► CycleService (-10s)
MissionService ──missionCompleted──► ShopService (+15 moedas)
MissionService ──UISyncEvent──► MissionUI
CycleService ──cycleZero──► EscapeService
CycleService ──UISyncEvent──► SurvivorHUD / KillerHUD (timer)
MatchService ──playerDied──► CycleService (+20s)
HunterService ──rageActivated──► CycleService (pausa)
```

### 13.6 E6 — Fuga e Resolução

**Serviços envolvidos:** EscapeService, MatchService (resolução de vitória)

**Módulos afetados:**
- `src/server/Services/EscapeService.lua` — Criar
- `GameConstants.lua` — Adicionar ESCAPE_WINDOW_BASE, ESCAPE_WINDOW_FLOOR
- `src/client/UI/GameOverUI.lua` — Criar

**Wiring:**
```
CycleService ──cycleZero──► EscapeService (inicia Fuga)
EscapeService ──escapeStarted──► AudioService (trilha de Fuga)
EscapeService ──escapeStarted──► UISyncEvent (mostrar portões, perigos)
MissionService ──► EscapeService (quais perigos ativar)
EscapeService ──playerEscaped──► MatchService (contagem de fugas)
EscapeService ──playerEscaped──► ShopService (+40 moedas)
EscapeService ──escapeEnded──► MatchService (resolver vitória)
MatchService ──matchEnded──► GameStateEvent (resultado) → GameOverUI
```

### 13.7 E7 — Lobby, Loja e Persistência

**Serviços envolvidos:** LobbyService, ShopService, DataStoreManager

**Módulos afetados:**
- `GameConstants.lua` — Adicionar seção `Economy`
- `src/server/Services/LobbyService.lua` — Completar (seleção, início)
- `src/server/Services/ShopService.lua` — Criar
- `src/server/Data/DataStoreManager.lua` — Criar
- `src/client/UI/ShopUI.lua` — Criar

**Wiring:**
```
ShopService ──► DataStoreManager (load/save)
LobbyService ──characterSelected──► MatchService
LobbyService ──readyToStart──► MatchService (iniciar partida)
MissionService ──missionCompleted──► ShopService (+15 moedas)
EscapeService ──playerEscaped──► ShopService (+40 moedas)
ShopService ──coinsUpdated──► ShopUI (atualizar HUD da loja)
ShopService ──► GameStateEvent (DATASTORE_LOADED, unlocked characters)
Players.PlayerRemoving ──► ShopService (salvar DataStore)
```

### 13.8 E8 — Áudio e Atmosfera

**Serviços envolvidos:** AudioService (server), AudioManager (client)

**Módulos afetados:**
- `GameConstants.lua` — Adicionar seção `Audio`
- `src/server/Services/AudioService.lua` — Criar
- `src/client/Audio/AudioManager.lua` — Criar

**Wiring:**
```
AudioService escuta:
  ├─ survivorDamaged (HunterService/SurvivorService) → batimentos
  ├─ rageActivated / rageDeactivated (HunterService) → transição de stem
  ├─ escapeStarted (EscapeService) → trilha de Fuga
  ├─ cycleTick (CycleService) → ajuste de camada por distância
  └─ missionCompleted (MissionService) → SFX

AudioService ──GameStateEvent──► AudioManager (comandos: playStem, playSFX)
```

### 13.9 E9 — Polimento e Balanceamento

**Serviços envolvidos:** Todos (ajuste de números no `GameConstants.lua`)

**Escopo:**
- Ajustar todos os valores em `GameConstants.lua` com base em playtest
- Verificar performance: ≤200 partículas mobile, ~2000 tris/modelo, light baking
- Testar com 3-4 amigos (até 8 jogadores)
- Corrigir bugs de edge case (desconexão, reconexão, host migration)
- Verificar integridade do DataStore: 0 perdas em 20 partidas

---

## 14. Diagramas de Fluxo de Dados

### 14.1 Fluxo de Dano (Caçador ataca Sobrevivente)

```
Cliente (Hunter)
  │
  ├─ InputManager detecta M1 (Clique Esquerdo)
  ├─ PlayerActionEvent:FireServer(HUNTER_M1, { aimPosition })
  │
  ▼
Servidor (HunterEvents → HunterService)
  │
  ├─ 1. Valida: cooldown? vivo? não stunado?
  ├─ 2. Cria 5 hitboxes em cone na direção do aim
  ├─ 3. Para cada hitbox:
  │     ├─ WorldRoot:GetPartBoundsInBox() na região
  │     ├─ Filtra por layer "SurvivorBody"
  │     ├─ Para cada Sobrevivente colidido:
  │     │   ├─ Verifica i-frames? (não, Sobreviventes não têm)
  │     │   ├─ Aplica dano (20 ou 25 em Rage)
  │     │   ├─ Aplica knockback (3 studs)
  │     │   └─ Dispara survivorDamaged
  │     └─ Se Sobrevivente HP ≤ 0:
  │         ├─ Dispara playerDied (MatchService)
  │         ├─ MatchService: +20s no Ciclo
  │         └─ GameStateEvent:FireAll(PLAYER_DIED)
  │
  ├─ 4. Se acertou alguém: HunterService ganha +10 Fúria
  │
  └─ 5. Envia UISyncEvent aos clientes afetados:
        ├─ Sobrevivente atingido: HUD_UPDATE { hp = novoHP }
        └─ Caçador: HUD_UPDATE { fury = novaFuria }
```

### 14.2 Fluxo de Missão (Sobrevivente completa missão)

```
Cliente (Survivor)
  │
  ├─ Jogador pressiona E perto de missão
  ├─ PlayerActionEvent:FireServer(INTERACT_MISSION, { missionId })
  │
  ▼
Servidor (MissionService)
  │
  ├─ 1. Valida: missão existe? não concluída? jogador vivo? alcance?
  ├─ 2. Abre minigame: envia MissionUI ao cliente
  │
  ▼
  (Jogador completa o minigame no cliente)
  │
  ├─ PlayerActionEvent:FireServer(MISSION_PROGRESS, { missionId, progress })
  │
  ▼
Servidor (MissionService)
  │
  ├─ 3. Valida progresso (anti-exploit: timing, sequência)
  ├─ 4. Se completou N repetições:
  │     ├─ Marca missão como CONCLUÍDA
  │     ├─ Dispara missionCompleted
  │     │   ├─ CycleService: -10s no Ciclo
  │     │   ├─ ShopService: +15 moedas ao jogador
  │     │   └─ EscapeService: desarma perigo desta missão
  │     └─ GameStateEvent:FirePlayer(MISSION_COMPLETED) → atualiza UI
  │
  └─ 5. Se faltam repetições: reinicia minigame
```

### 14.3 Fluxo de Fuga

```
CycleService.cycleZero
  │
  ▼
EscapeService.startEscape()
  │
  ├─ 1. Verifica missões pendentes → lista de perigos ativos
  ├─ 2. Calcula janela: 60s - (5s × missões pendentes), piso 10s
  ├─ 3. Dispara escapeStarted
  │     ├─ AudioService: troca para trilha de Fuga
  │     ├─ UISyncEvent: timer da janela, marcadores de portão
  │     └─ MapService: ativa incêndio estético
  │
  ├─ 4. Abre 3 portões
  │
  ├─ 5. Ativa perigos:
  │     ├─ V1 pendente → escuridão na área do disjuntor
  │     ├─ V2 pendente → barreira elétrica (10 dano/travessia)
  │     └─ V3 pendente → poça de óleo (35% slow)
  │
  ├─ 6. Loop: timer da janela rodando
  │     ├─ Se jogador toca portão → playerEscaped
  │     │   ├─ MatchService: registra fuga
  │     │   └─ ShopService: +40 moedas
  │     └─ Se timer zera OU todos escaparam/morreram → escapeEnded
  │
  └─ 7. escapeEnded → MatchService.resolveVitory()
        ├─ Alguém escapou? → Sobreviventes vencem
        ├─ Ninguém escapou? → Caçador vence
        └─ GameStateEvent:FireAll(MATCH_ENDED) → GameOverUI
```

---

## 15. Desempenho e Otimização

### 15.1 Metas por Plataforma

| Métrica | PC | Mobile | Onde Medir |
|---------|----|--------|------------|
| FPS alvo | 60 | 30 | Na Fuga (pior caso: fogo + perigos + 8 jogadores) |
| Ping máximo | <100ms | <100ms | Performance Stats |
| Memória | <1GB | <500MB | Developer Console (F9) |
| Carregamento | <10s | <15s | Do "Iniciar" ao spawn |

### 15.2 Estratégias de Otimização

| Estratégia | Detalhe | Épico |
|------------|---------|-------|
| **Partículas limitadas** | Máximo 200 partículas simultâneas no mobile; fogo da Fuga usa efeito otimizado (sprite sheet) | E4, E6 |
| **Light baking** | Iluminação pré-calculada (sem sombras dinâmicas em mobile) | E4 |
| **Modelos low-poly** | ~2000 triângulos por modelo; R6 naturalmente leve | E4 |
| **RemoteEvent throttling** | UISyncEvent a cada 2 frames (~30Hz) em vez de 60Hz | E1 |
| **Streaming de áudio** | Stems pré-carregados; crossfade via volume, não múltiplas instâncias | E8 |
| **Network ownership** | Partes do mapa sem física são server-owned (reduz replicação) | E4 |
| **Occlusion culling** | Roblox faz automático; evitar transparências excessivas | E4 |
| **LOD implícito** | R6 já é low-detail; sem necessidade de LOD explícito | E4 |

### 15.3 Perfis de Carga (Server)

| Fase | Carga de CPU | Carga de Rede | Risco |
|------|-------------|---------------|-------|
| LOBBY | Baixa | Baixa | Nenhum |
| SELECTING | Baixa | Baixa | Nenhum |
| PLAYING (dispersão) | Média (hitboxes, stamina, missões) | Média (UISyncEvent ~30Hz) | OK |
| PLAYING (perseguição) | Alta (múltiplas hitboxes) | Média-alta | Verificar ping |
| ESCAPING | **Muito alta** (fogo, perigos, 3 portões, corrida final) | Alta (muitos eventos) | **Ponto crítico** — testar com 8 jogadores |

---

## 16. Convenções de Código

### 16.1 Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Arquivos de serviço | `NomeDoServico.lua` (PascalCase) | `HunterService.lua` |
| Arquivos de evento | `NomeDoEvento.lua` (PascalCase) | `PlayerActionEvent.lua` |
| Módulos compartilhados | `NomeDoModulo.lua` (PascalCase) | `GameConstants.lua` |
| Funções | `camelCase` | `performM1()`, `getPlayerRole()` |
| Variáveis locais | `camelCase` | `local maxHp = ...` |
| Constantes | `UPPER_SNAKE_CASE` | `MAX_HP`, `CYCLE_BASE_DURATION` |
| Sinais | `camelCase` (substantivo + verbo) | `playerDied`, `cycleZero` |
| Tabelas de configuração | `PascalCase` | `GameConstants.Hunter.M1` |

### 16.2 Estrutura de Arquivo Padrão

```lua
--!strict
--[[
  NomeDoArquivo.lua
  Breve descrição em PT-BR do que este módulo faz.
  Referências: GDD §X.Y
]]

-- ═══ DEPENDÊNCIAS (Roblox Services) ═══
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ═══ DEPENDÊNCIAS (Módulos) ═══
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

-- ═══ CONSTANTES LOCAIS ═══
local MAX_RETRIES = 3

-- ═══ MÓDULO ═══
local NomeDoModulo = {}
NomeDoModulo.Name = "NomeDoModulo"

-- ═══ SINAIS ═══
NomeDoModulo.somethingHappened = Signal.new()

-- ═══ ESTADO PRIVADO ═══
local _state = {}

-- ═══ FUNÇÕES PRIVADAS ═══
local function _helperFunction()
	-- ...
end

-- ═══ FUNÇÕES PÚBLICAS ═══
function NomeDoModulo.Init()
	-- Setup síncrono
end

function NomeDoModulo.Start()
	-- Setup assíncrono
end

-- ═══ RETORNO ═══
return NomeDoModulo
```

### 16.3 Logging

Todo log usa o prefixo `[TheBrokenBox]`:

```lua
print("[TheBrokenBox] HunterService: Rage ativado. Fúria=" .. fury)
warn("[TheBrokenBox] DataStore: falha ao salvar (tentativa " .. attempt .. ")")
```

### 16.4 Service Caching

No topo de cada arquivo, cachear serviços Roblox:

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsService = game:GetService("PhysicsService")
local DataStoreService = game:GetService("DataStoreService")
```

---

## 17. Dependências e Versões

| Ferramenta | Versão | Uso |
|-----------|--------|-----|
| Roblox Studio | Atual | Desenvolvimento e teste |
| Rojo | 7.6.1 | Sincronização filesystem ↔ Roblox Studio |
| Luau | (Roblox atual) | Linguagem de script |
| Git | ≥2.40 | Controle de versão |
| GitHub CLI (`gh`) | Opcional | Criação de repositório remoto |

---

## 18. Riscos Técnicos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| DataStore não funciona em dev local | Alta | Médio | Mock em memória no Studio; teste real pós-publicação |
| Mobile não atinge 30 FPS na Fuga | Média | Alto | Reduzir partículas, light baking, testar cedo |
| Dessincronização de hitbox com ping alto | Média | Alto | Validação server-side; hitboxes generosas (não pixel-perfect) |
| Race condition no DataStore | Baixa | Alto | `UpdateAsync` com locking; retry com backoff |
| Complexidade excessiva para dev iniciante | Média | Alto | Serviços modulares e independentes; documentação detalhada; começar pelo E1 |
| 8 jogadores sobrecarregam replicação | Média | Médio | UISyncEvent throttled; testar com 8 cedo (E6) |
| Áudio bitcrushed indisponível na biblioteca gratuita | Média | Baixo | Criar/comissionar; fallback para áudio padrão com filtro |

---

## 19. Glossário Técnico

| Termo | Significado |
|-------|------------|
| **Server-Authoritative** | O servidor é a fonte da verdade; cliente envia input, servidor valida e aplica. |
| **RemoteEvent** | Mecanismo de comunicação assíncrona cliente↔servidor no Roblox. |
| **ModuleScript** | Script que exporta funções/dados via `return`; equivalente a um módulo/package. |
| **Init/Start** | Padrão de duas fases: Init (síncrono) + Start (assíncrono com listeners). |
| **Signal (Pub/Sub)** | Padrão Observer: serviços publicam eventos; outros se inscrevem para reagir. |
| **GameConstants** | Módulo compartilhado com todos os dados numéricos do jogo. Fonte única de verdade. |
| **Hitbox** | Região de detecção de colisão (cubo, esfera, projétil) que determina se um ataque acertou. |
| **I-frames** | Período de invencibilidade (invincibility frames) após sofrer stun. |
| **Stun** | Estado em que o personagem não pode agir (movimento e habilidades travados). |
| **Stud** | Unidade de distância no Roblox (1 stud ≈ 28 cm). |
| **Rojo** | Ferramenta que sincroniza arquivos do sistema de arquivos com o Roblox Studio. |
| **DataStore** | Serviço de persistência do Roblox (salva dados entre sessões). |
| **Stems** | Camadas de áudio separadas (Calma, Alerta, Perseguição) mixadas dinamicamente. |

---

## 20. Referências

| Documento | Caminho | Conteúdo |
|-----------|---------|----------|
| Game Design Document | `docs/gdd.md` | Design completo do jogo, mecânicas, balanceamento |
| Project Context | `project-context.md` | Contexto técnico para agentes de IA |
| Épicos e Histórias | `docs/epics.md` | Detalhamento de épicos E1-E9 (a ser criado) |
| Exemplo Caçada Sombria | `_bmad/gds/references/` | Projeto irmão com arquitetura similar |
| Documentação Rojo | https://rojo.space | Guia de uso do Rojo |
| Documentação Luau | https://luau-lang.org | Referência da linguagem |

---

*Fim do documento — The broken box Architecture v1.0*
*Próximo passo: `gds-create-epics-and-stories` para gerar `docs/epics.md` com base neste documento de arquitetura e no GDD.*
