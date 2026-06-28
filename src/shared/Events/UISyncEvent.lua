--!strict
--[[
  UISyncEvent.lua
  Definicao do RemoteEvent para sincronizacao de HUD em tempo real.
  Direcao: Servidor -> Cliente
  Taxa: ~60Hz (a cada Heartbeat do servidor)

  Mensagens:
    HUD_UPDATE = {
      hp, stamina, fury, cycleTime,
      aliveCount, cooldowns, proximityLevel
    }
]]

local UISyncEvent = {}

UISyncEvent.NAME = "UISyncEvent"

-- Tipos de mensagem
UISyncEvent.MESSAGES = {
	-- Enviado a cada frame (~60Hz) com estado completo do HUD
	HUD_UPDATE = "HUD_UPDATE",
		-- data: {
		--   hp = number,
		--   stamina = number,
		--   fury = number,
		--   cycleTime = number,
		--   aliveCount = number,
		--   cooldowns = { [abilityName] = number },
		--   proximityLevel = number, -- 0=Calma, 1=Alerta, 2=Perseguicao
		--   allyHP = { [userId] = { name, hp, maxHp, class } },
		-- }

	-- Sobreviventes: cooldowns e estado
	COOLDOWN_START = "COOLDOWN_START",
		-- data: { ability = string, duration = number }
	COOLDOWN_END = "COOLDOWN_END",
		-- data: { ability = string }

	-- LMS (Last Man Standing)
	LMS_ACTIVATED = "LMS_ACTIVATED",
		-- data: { className = string, bonus = string }

	-- Habilidades: SFX / efeitos visuais (futuro)
	SURVIVOR_ABILITY_VFX = "SURVIVOR_ABILITY_VFX",
		-- data: { className = string, abilityName = string, position = Vector3 }
}

return UISyncEvent
