--!strict
--[[
  PlayerActionEvent.lua
  Definicao do RemoteEvent para inputs do jogador.
  Direcao: Cliente -> Servidor
  Todo input do jogador e enviado por este canal.

  Mensagens:
    MOVE, JUMP, TOGGLE_CAMERA,
    HUNTER_M1, HUNTER_PULL, HUNTER_ROAR, HUNTER_RAGE,
    SURVIVOR_A1, SURVIVOR_A2, SURVIVOR_A3,
    INTERACT_MISSION, INTERACT_PORTAL,
    SELECT_CHARACTER, READY_UP, BUY_UNLOCK,
    SPECTATE_NEXT, RETURN_TO_LOBBY
]]

local PlayerActionEvent = {}

PlayerActionEvent.NAME = "PlayerActionEvent"

-- Tipos de mensagem (Cliente -> Servidor)
PlayerActionEvent.MESSAGES = {
	-- Movimento
	MOVE = "MOVE",
		-- data: { direction = Vector3, sprinting = boolean }
	JUMP = "JUMP",
		-- data: {}
	TOGGLE_CAMERA = "TOGGLE_CAMERA",
		-- data: { mode = "FirstPerson" | "ThirdPerson" }

	-- Cacador
	HUNTER_M1 = "HUNTER_M1",
		-- data: { aimPosition = Vector3 }
	HUNTER_PULL = "HUNTER_PULL",
		-- data: { aimDirection = Vector3 }
	HUNTER_ROAR = "HUNTER_ROAR",
		-- data: {}
	HUNTER_RAGE = "HUNTER_RAGE",
		-- data: {}

	-- Sobreviventes
	SURVIVOR_A1 = "SURVIVOR_A1",
		-- data: { aimPosition = Vector3 }
	SURVIVOR_A2 = "SURVIVOR_A2",
		-- data: { aimPosition = Vector3 }
	SURVIVOR_A3 = "SURVIVOR_A3",
		-- data: { aimPosition = Vector3 } (Robo)

	-- Interacao
	INTERACT_MISSION = "INTERACT_MISSION",
		-- data: { missionId = string }
	INTERACT_PORTAL = "INTERACT_PORTAL",
		-- data: { portalId = string }

	-- Lobby
	SELECT_CHARACTER = "SELECT_CHARACTER",
		-- data: { characterClass = string }
	READY_UP = "READY_UP",
		-- data: {}
	BUY_UNLOCK = "BUY_UNLOCK",
		-- data: { characterClass = string }

	-- Pos-morte
	SPECTATE_NEXT = "SPECTATE_NEXT",
		-- data: {}
	RETURN_TO_LOBBY = "RETURN_TO_LOBBY",
		-- data: {}
}

return PlayerActionEvent
