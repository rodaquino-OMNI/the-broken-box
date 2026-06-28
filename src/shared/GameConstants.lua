--!strict
--[[
  GameConstants.lua
  Fonte unica de verdade para TODOS os dados numericos do jogo.
  Referenciado por servicos (server/) e UIs (client/).
  Compartilhado via ReplicatedStorage.

  Convencao de nomenclatura:
    - Chaves: PascalCase para tabelas, UPPER_SNAKE para valores escalares
    - Sub-tabelas organizadas por dominio: Hunter, Survivors, Game, Missions, Stamina
    - Comentarios em PT-BR

  Referencias: GDD v2.0 (tabela-mestra de balanceamento)
]]

local GameConstants = {}

-- ============================================================
-- DADOS GERAIS DA PARTIDA (ref: GDD M1-M4, Tabela-Mestra)
-- ============================================================
GameConstants.Game = {
	SURVIVORS_PER_MATCH = 4,          -- Minimo de Sobreviventes (max. 7)
	PREPARATION_TIME = 5,             -- Tempo de preparacao antes da cacada (s)
	CYCLE_BASE_DURATION = 240,        -- Duracao base do Ciclo (s)
	CYCLE_EXTEND_PER_DEATH = 20,      -- +20s no Ciclo por morte de Sobrevivente
	CYCLE_REDUCE_PER_MISSION = 10,    -- -10s no Ciclo por missao concluida
	ESCAPE_WINDOW_BASE = 60,         -- Janela de Fuga base (s)
	ESCAPE_WINDOW_REDUCE_PER_MISSION = 5,  -- -5s por missao pendente
	ESCAPE_WINDOW_FLOOR = 10,        -- Piso da janela de Fuga (s)
	RAGE_PAUSES_CYCLE = true,        -- Rage pausa o cronometro do Ciclo
}

-- ============================================================
-- STAMINA E MOVIMENTO (ref: GDD M4)
-- ============================================================
GameConstants.Stamina = {
	SPEND_PER_SECOND = 7,            -- Gasto de stamina ao correr (/s)
	REGEN_PER_SECOND = 9,            -- Regeneracao de stamina (/s)
	EXHAUST_DELAY = 0.5,             -- Atraso pos-esgotamento antes de regenerar (s)
	JUMP_COST = 10,                  -- Custo de stamina por pulo
	JUMP_COOLDOWN = 2,               -- Cooldown entre pulos (s)
}

-- ============================================================
-- VELOCIDADE BASE DOS SOBREVIVENTES (ref: GDD Personagens)
-- ============================================================
GameConstants.Survivors = {
	BASE_SPEED = 22,                  -- Velocidade base padrao (studs/s)

	MEDICO = {
		NAME = "Medico",
		MAX_HP = 80,
		SPEED = 22,
		STAMINA = 100,
		FREE = true,                  -- Gratis no MVP
		ROLE = "Suporte/Cura",
		-- Habilidades (ref: GDD Medico)
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
			RADIUS = 10,              -- Cubo 10x10x10 ao redor
			DAMAGE = {0, 10, 20, 30}, -- Escala por aliados curados
		},
	},

	SOLDADO = {
		NAME = "Soldado",
		MAX_HP = 120,
		SPEED = 20,
		STAMINA = 110,
		FREE = false,                 -- Pago (moedas)
		ROLE = "Controle a Distancia",
		-- Habilidades (ref: GDD Soldado)
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
		-- LMS condicional: vs Soldado Fundido -> SPEED 22, +30% dano Bazuca
	},

	SACKBOY = {
		NAME = "Sackboy",
		MAX_HP = 110,
		SPEED = 26,
		STAMINA = 70,
		FREE = true,                  -- Gratis no MVP
		ROLE = "Hit & Run / Controle",
		-- Habilidades (ref: GDD Sackboy)
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
		NAME = "Robo",
		MAX_HP = 150,
		SPEED = 18,
		STAMINA = 110,
		FREE = false,                 -- Pago (moedas)
		ROLE = "Tanque / Sacrificio",
		CAN_BE_HEALED_BY_MEDICO = false, -- So se cura pelo proprio Block
		-- Habilidades (ref: GDD Robo)
		GRAB = {
			WINDUP = 1,
			COOLDOWN = 22,
			SPEED = 15,
			DURATION = 2,
			RANGE = 30,
			INVINCIBILITY_DURATION = 8, -- Invencibilidade que da ao Cacador
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
-- CACADOR — O DISTORCIDO (ref: GDD M5-M7, Design de Inimigo)
-- ============================================================
GameConstants.Hunter = {
	NAME = "O Distorcido",
	MAX_HP = 2000,
	BASE_SPEED = 26,                  -- studs/s
	RAGE_SPEED = 28,                  -- studs/s durante Rage
	STAMINA = 110,

	-- Furia e Rage (ref: GDD M5)
	FURY = {
		MAX = 100,                    -- Medidor vai de 0 a 100+
		RAGE_THRESHOLD = 80,          -- Limiar para ativar Rage
		GAIN_ON_ATTACKED = 10,        -- Furia ao ser atacado/atordoado
		GAIN_PER_SECOND_PROXIMITY = 1, -- Furia/s apos 20s a <=40 studs
		PROXIMITY_RADIUS = 40,        -- Raio de proximidade (studs)
		PROXIMITY_TIME = 20,          -- Tempo para comecar a ganhar (s)
		RAGE_WINDUP = 5,              -- Windup da transformacao (s)
		RAGE_DURATION_BASE = 30,      -- Duracao base do Rage (s)
		RAGE_EXTEND_PER_KILL = 10,    -- +10s por morte durante Rage
		RAGE_PULSE_DAMAGE = 20,       -- Dano em area ao ativar Rage
		RAGE_PULSE_RADIUS = 30,       -- Raio do pulso de ativacao (studs)
	},

	-- Stun e I-frames (ref: GDD M6)
	STUN_I_FRAMES = 2,                -- Invencibilidade pos-stun (s)

	-- Habilidades (ref: GDD Design de Inimigo, Tabela-Mestra)
	M1 = {
		DAMAGE = 20,                  -- Dano base do Tapa
		RAGE_DAMAGE = 25,             -- Dano em Rage
		HITBOX_COUNT = 5,             -- Quantidade de hitboxes
		HITBOX_DURATION = 0.5,        -- Duracao total das hitboxes (s)
		WINDUP = 0.6,                 -- Tempo de preparacao (s)
		COOLDOWN = 0.8,               -- Tempo entre ataques (s)
		KNOCKBACK = 3,                -- Empurrao (studs)
	},
	PULL = {
		WINDUP = 1,                   -- Tempo de preparacao (s)
		COOLDOWN = 12,                -- Tempo de recarga (s)
		SPEED = 15,                   -- Velocidade do projetil (studs/s)
		DURATION = 2,                 -- Duracao maxima do braco (s)
		RANGE = 30,                   -- Alcance maximo (studs)
		STUN_DURATION = 0.5,          -- Duracao do stun ao puxar (s)
	},
	ROAR = {
		WINDUP = 2,                   -- Tempo de preparacao (s)
		COOLDOWN = 25,                -- Tempo de recarga (s)
		SLOW_AMOUNT = 40,             -- Porcentagem de lentidao (%)
		SLOW_DURATION = 3,            -- Duracao da lentidao (s)
		SLOW_RADIUS = 60,             -- Raio da lentidao (studs)
		REVEAL_DURATION = 4,          -- Duracao da revelacao (s)
		REVEAL_RADIUS = 100,          -- Raio da revelacao (studs)
		RAGE_DAMAGE = 10,             -- Dano adicional em Rage
	},
}

-- ============================================================
-- MISSOES (ref: GDD M1)
-- ============================================================
GameConstants.Missions = {
	TOTAL_PER_MATCH = 10,             -- Total de missoes por partida
	MIN_EACH_VARIANT = 1,             -- Minimo de 1 de cada variavel

	V1_BREAKER = {
		NAME = "Disjuntor de Energia",
		REPETITIONS = 4,              -- Completar 4 vezes
		PERIGO = "Escuridao localizada",
	},
	V2_GENERATOR = {
		NAME = "Gerador",
		CABLES = 5,                   -- Conectar 5 cabos
		REPETITIONS = 4,
		PERIGO = "Barreira eletrica",
		BARRIER_DAMAGE = 10,          -- Dano por travessia
		BARRIER_IMMUNITY = 5,         -- Janela de imunidade (s)
	},
	V3_OIL = {
		NAME = "Maquina de Petroleo",
		REPETITIONS = 1,              -- Uma vez (minigame de ponteiro)
		PERIGO = "Poca de oleo",
		SLOW_PERCENT = 35,            -- Lentidao ao pisar (%)
	},
}

-- ============================================================
-- ECONOMIA (ref: GDD Progressao de Jogador)
-- ============================================================
GameConstants.Economy = {
	COIN_MISSAO = 15,                -- Moedas por missao concluida
	COIN_FUGA = 40,                  -- Moedas por fuga bem-sucedida (so quem escapou)
	UNLOCK_COST_SOLDADO = 150,       -- Custo de desbloqueio do Soldado
	UNLOCK_COST_ROBO = 200,          -- Custo de desbloqueio do Robo
}

-- ============================================================
-- HITBOXES E LAYERS (ref: GDD Sistema de Hitboxes e Layers)
-- ============================================================
GameConstants.Hitbox = {
	-- Regra: dano aplicado 1 vez por alvo colidido (nunca empilha no mesmo alvo)

	-- Tipos de hitbox
	FORMS = {
		PROJECTILE = "Projetil",       -- Viaja, para em parede/alvo
		INSTANT_LINE = "Linha",        -- Instantanea, para na parede
		AREA_CUBE = "Cubo",            -- Cubo unico grande, atravessa parede
		BODY = "Corpo",                -- Hitbox de corpo do personagem
		REACTION_AREA = "Reacao",      -- Area reativa (ex.: Block do Robo)
	},

	-- Regras de parede
	WALL_RULES = {
		PROJECTILES_STOP = true,       -- Projeteis/misseis param na parede/chao
		AREA_CUBES_IGNORE = true,      -- Cubos grandes ignoram ambiente (atravessam)
	},

	-- Layers de colisao (nomes semanticos)
	LAYERS = {
		HUNTER_ATTACK = "HunterAttack",      -- Ataques do Cacador -> Sobreviventes
		SURVIVOR_ATTACK = "SurvivorAttack",  -- Ataques dos Sobreviventes -> Cacador
		ENVIRONMENT = "Environment",          -- Paredes, chao, obstaculos
		INVINCIBLE = "Invincible",            -- Durante i-frames (Cacador)
	},
}

-- ============================================================
-- AUDIO (ref: GDD Design de Audio de Tensao)
-- ============================================================
GameConstants.Audio = {
	-- Trilha dinamica: distancias de crossfade
	LAYER_CALM_MAX = 60,              -- Ate 60 studs: camada Calma
	LAYER_ALERT_MAX = 30,             -- Ate 30 studs: camada Alerta
	-- Abaixo de 30 studs: camada Perseguicao
	CROSSFADE_DURATION = 2,           -- Duracao do crossfade entre camadas (s)

	-- Efeitos de proximidade
	HEARTBEAT_RADIUS = 40,            -- Raio para batimentos audiveis (studs)
	DISTORTION_RADIUS = 20,           -- Raio para distorcao de borda (studs)
}

-- ============================================================
-- DESEMPENHO (ref: GDD Requisitos de Desempenho)
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
