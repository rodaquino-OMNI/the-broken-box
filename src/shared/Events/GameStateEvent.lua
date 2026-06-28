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

	-- Sistema
	DATASTORE_LOADED = "DATASTORE_LOADED",
		-- data: { coins = number, unlocked = {...} }
	ERROR = "ERROR",
		-- data: { message = string }
}

return GameStateEvent
