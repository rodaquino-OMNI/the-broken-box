--!strict
--[[
  GameStateEvent.lua
  Definicao do RemoteEvent para mudancas de estado do jogo.
  Direcao: Servidor -> Cliente
  Usado para eventos discretos (nao por frame).

  Mensagens:
    MATCH_STATE, ROLE_ASSIGNED, PLAYER_DIED, PLAYER_ESCAPED,
    ESCAPE_STARTED, MATCH_ENDED, etc.
]]

local GameStateEvent = {}

GameStateEvent.NAME = "GameStateEvent"

-- Tipos de mensagem (Servidor -> Cliente)
GameStateEvent.MESSAGES = {
	-- Lobby / Selecao
	MATCH_STATE = "MATCH_STATE",
		-- data: { state = "Lobby" | "Selecting" | "Playing" | "Escaping" | "Ended" }
	CHARACTER_SELECT = "CHARACTER_SELECT",
		-- data: { availableCharacters = {...}, timer = number }
	CHARACTER_SELECTED = "CHARACTER_SELECTED",
		-- data: { userId = number, characterClass = string }
	YOUR_CHARACTER = "YOUR_CHARACTER",
		-- data: { characterClass = string, isHunter = boolean }

	-- Partida
	MATCH_STARTED = "MATCH_STARTED",
		-- data: { cycleDuration = number, missionCount = number }
	ROLE_ASSIGNED = "ROLE_ASSIGNED",
		-- data: { role = "Hunter" | "Survivor", survivorsCount = number }
	PLAYER_DIED = "PLAYER_DIED",
		-- data: { userId = number, killerId = number }
	PLAYER_ESCAPED = "PLAYER_ESCAPED",
		-- data: { userId = number, portalId = number }
	ESCAPE_STARTED = "ESCAPE_STARTED",
		-- data: { windowDuration = number, portals = {...}, hazards = {...} }
	ESCAPE_ENDED = "ESCAPE_ENDED",
		-- data: {}
	MATCH_ENDED = "MATCH_ENDED",
		-- data: { winner = "Survivors" | "Hunter", result = "FugaTotal" | "FugaParcial" | "Contencao", rewards = {...} }

	-- Audio (Servidor -> Cliente)
	AUDIO_MUSIC_STATE = "AUDIO_MUSIC_STATE",
		-- data: { layerState = "Lobby" | "Playing" | "FugaPrestes" | "FugaAbriu", chaseSegment = number, isRage = boolean }
		-- layerState: fase do jogo para audio
		--   "Lobby": SAME_MUSIC (lobby, loja, mapa)
		--   "Playing": SAME_MUSIC + chase segment (apenas 1 trecho toca por vez, crossfade)
		--   "FugaPrestes": FUGA_PRESTES (ciclo acabando)
		--   "FugaAbriu": FUGA_ABRIU (portoes abertos, substitui tudo)
		-- chaseSegment: 0=sem chase, 1=intro >60s, 2=build 30-60s, 3=climax <30s, 4=peak colado/Rage
		-- isRage: true durante Rage (forca Trecho 4)
	AUDIO_SFX = "AUDIO_SFX",
		-- data: { sfx = string, data = {...} }
		-- sfx: "mission_complete" | "player_died" | "player_damaged" | "rage_activate" | "gate_open" | "fire"
	AUDIO_HEARTBEAT = "AUDIO_HEARTBEAT",
		-- data: { proximity = number, intensity = string? }

	-- Sistema
	DATASTORE_LOADED = "DATASTORE_LOADED",
		-- data: { coins = number, unlocked = {...} }
	ERROR = "ERROR",
		-- data: { message = string }
}

return GameStateEvent
