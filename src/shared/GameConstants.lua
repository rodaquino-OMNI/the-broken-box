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

  Referencias: GDD v20/10 (tabela-mestra de balanceamento)
]]

local GameConstants = {}

-- ============================================================
-- DADOS GERAIS DA PARTIDA (ref: GDD M1-M4, Tabela-Mestra)
-- ============================================================
GameConstants.Game = {
	SURVIVORS_PER_MATCH = 4,
	PREPARATION_TIME = 5,
	CYCLE_BASE_DURATION = 240,
	CYCLE_EXTEND_PER_DEATH = 20,
	CYCLE_REDUCE_PER_MISSION = 10,
	ESCAPE_WINDOW_BASE = 60,
	ESCAPE_WINDOW_REDUCE_PER_MISSION = 5,
	ESCAPE_WINDOW_FLOOR = 10,
	RAGE_PAUSES_CYCLE = true,
}

-- ============================================================
-- STAMINA E MOVIMENTO (ref: GDD M4)
-- ============================================================
GameConstants.Stamina = {
	SPEND_PER_SECOND = 7,
	REGEN_PER_SECOND = 9,
	EXHAUST_DELAY  = 1/2,
	JUMP_COST = 10,
	JUMP_COOLDOWN = 2,
}

-- ============================================================
-- VELOCIDADE BASE DOS SOBREVIVENTES (ref: GDD Personagens)
-- ============================================================
GameConstants.Survivors = {
	BASE_SPEED = 22,

	MEDICO = {
		NAME = "Medico",
		MAX_HP = 80,
		SPEED = 22,
		STAMINA = 100,
		FREE = true,
		ROLE = "Suporte/Cura",
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
			RADIUS = 10,
			DAMAGE = {0, 10, 20, 30},
		},
	},

	SOLDADO = {
		NAME = "Soldado",
		MAX_HP = 120,
		SPEED = 20,
		STAMINA = 110,
		FREE = false,
		ROLE = "Controle a Distancia",
		DASH = {
			WINDUP  = 1/2,
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
			HITBOX = {3, 3, 100},
		},
	},

	SACKBOY = {
		NAME = "Sackboy",
		MAX_HP = 110,
		SPEED = 26,
		STAMINA = 70,
		FREE = true,
		ROLE = "Hit & Run / Controle",
		INK = {
			WINDUP = {1, 2, 3},
			COOLDOWN = 30,
			MAX_CHARGES = 3,
			HITBOX = {3, 3, 100},
			DAMAGE = {5, 10, 15},
			SLOW = {30, 40, 0},
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
		FREE = false,
		ROLE = "Tanque / Sacrificio",
		CAN_BE_HEALED_BY_MEDICO = false,
		GRAB = {
			WINDUP = 1,
			COOLDOWN = 22,
			SPEED = 15,
			DURATION = 2,
			RANGE = 30,
			INVINCIBILITY_DURATION = 8,
		},
		BLOCK = {
			WINDOW  = 3/2,
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
-- CACADOR - O DISTORCIDO (ref: GDD M5-M7, Design de Inimigo)
-- ============================================================
GameConstants.Hunter = {
	NAME = "O Distorcido",
	MAX_HP = 2000,
	BASE_SPEED = 26,
	RAGE_SPEED = 28,
	STAMINA = 110,

	FURY = {
		MAX = 100,
		RAGE_THRESHOLD = 80,
		GAIN_ON_ATTACKED = 10,
		GAIN_PER_SECOND_PROXIMITY = 1,
		PROXIMITY_RADIUS = 40,
		PROXIMITY_TIME = 20,
		RAGE_WINDUP = 5,
		RAGE_DURATION_BASE = 30,
		RAGE_EXTEND_PER_KILL = 10,
		RAGE_PULSE_DAMAGE = 20,
		RAGE_PULSE_RADIUS = 30,
	},

	STUN_I_FRAMES = 2,

	M1 = {
		DAMAGE = 20,
		RAGE_DAMAGE = 25,
		HITBOX_COUNT = 5,
		HITBOX_DURATION  = 1/2,
		WINDUP  = 3/5,
		COOLDOWN  = 4/5,
		KNOCKBACK = 3,
	},
	PULL = {
		WINDUP = 1,
		COOLDOWN = 12,
		SPEED = 15,
		DURATION = 2,
		RANGE = 30,
		STUN_DURATION  = 1/2,
	},
	ROAR = {
		WINDUP = 2,
		COOLDOWN = 25,
		SLOW_AMOUNT = 40,
		SLOW_DURATION = 3,
		SLOW_RADIUS = 60,
		REVEAL_DURATION = 4,
		REVEAL_RADIUS = 100,
		RAGE_DAMAGE = 10,
	},
}

-- ============================================================
-- MISSOES (ref: GDD M1)
-- ============================================================
GameConstants.Missions = {
	TOTAL_PER_MATCH = 10,
	MIN_EACH_VARIANT = 1,

	V1_BREAKER = {
		NAME = "Disjuntor de Energia",
		REPETITIONS = 4,
		PERIGO = "Escuridao localizada",
	},
	V2_GENERATOR = {
		NAME = "Gerador",
		CABLES = 5,
		REPETITIONS = 4,
		PERIGO = "Barreira eletrica",
		BARRIER_DAMAGE = 10,
		BARRIER_IMMUNITY = 5,
	},
	V3_OIL = {
		NAME = "Maquina de Petroleo",
		REPETITIONS = 1,
		PERIGO = "Poca de oleo",
		SLOW_PERCENT = 35,
	},
}

-- ============================================================
-- ECONOMIA (ref: GDD Progressao de Jogador)
-- ============================================================
GameConstants.Economy = {
	COIN_MISSAO = 15,
	COIN_FUGA = 40,
	UNLOCK_COST_SOLDADO = 150,
	UNLOCK_COST_ROBO = 200,
}

-- ============================================================
-- HITBOXES E LAYERS (ref: GDD Sistema de Hitboxes e Layers)
-- ============================================================
GameConstants.Hitbox = {
	FORMS = {
		PROJECTILE = "Projetil",
		INSTANT_LINE = "Linha",
		AREA_CUBE = "Cubo",
		BODY = "Corpo",
		REACTION_AREA = "Reacao",
	},

	WALL_RULES = {
		PROJECTILES_STOP = true,
		AREA_CUBES_IGNORE = true,
	},

	LAYERS = {
		HUNTER_ATTACK = "HunterAttack",
		SURVIVOR_ATTACK = "SurvivorAttack",
		ENVIRONMENT = "Environment",
		INVINCIBLE = "Invincible",
	},
}

-- ============================================================
-- AUDIO (ref: GDD Design de Audio de Tensao)
-- ============================================================
GameConstants.Audio = {
	-- 1 musica compartilhada + 4 trechos sequenciais de chase + 2 fugas
	-- SAME_MUSIC: mesma faixa no Lobby, Loja e Mapa ambiente
	-- CHASE: 1 musica em 4 TRECHOS sequenciais (NAO camadas - crossfade entre eles)
	--   Trecho 1 (>60 studs), Trecho 2 (30-60), Trecho 3 (5-30), Trecho 4 (<=5/Rage)
	-- FUGA_PRESTES: ciclo acabando
	-- FUGA_ABRIU: portoes abertos (substitui tudo)
	CHASE_SEGMENT_1_MAX = 60,     -- >60 = Trecho 1 (intro/base)
	CHASE_SEGMENT_2_MAX = 30,     -- 30-60 = Trecho 2 (build)
	CHASE_SEGMENT_3_MAX = 5,      -- 5-30 = Trecho 3 (climax); <=5 = Trecho 4 (peak)
	CROSSFADE_DURATION = 2,       -- Duracao do crossfade entre trechos (s)
	FUGA_PRESTES_TIME = 15,       -- Tempo restante para ativar FUGA_PRESTES (s)
	HEARTBEAT_RADIUS = 40,
	DISTORTION_RADIUS = 20,
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
