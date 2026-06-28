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
		-- }
}

return UISyncEvent
