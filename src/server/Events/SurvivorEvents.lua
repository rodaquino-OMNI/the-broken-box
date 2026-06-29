--!strict
--[[
  SurvivorEvents.lua
  Handler de eventos de habilidade dos Sobreviventes.
  Escuta PlayerActionEvent para SURVIVOR_A1/A2/A3
  e roteia para o SurvivorService.

  Referencias: GameConstants.Survivors, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.GameConstants)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local SurvivorEvents = {}

-- Referencias injetadas
local _survivorService = nil
local _playerActionEvent = nil
local _uiSyncEvent = nil

-- ============================================================
-- Handlers de habilidade do cliente
-- ============================================================

--[[
  SURVIVOR_A1: Habilidade 1 (Q)
  - Medico: Pocao em Area
  - Soldado: Dash Tatico
  - Sackboy: Arma de Tinta (com chargeLevel)
  - Robo: Agarrar
]]
local function onAbility1(player: Player, data: {any}): ()
	local state = _survivorService.getSurvivorExt(player)
	if not state then
		return
	end

	local chargeLevel: number = nil
	if data and data.chargeLevel then
		chargeLevel = data.chargeLevel
	end

	_survivorService.handleAbilityAction(player, "SURVIVOR_A1", chargeLevel)
end

--[[
  SURVIVOR_A2: Habilidade 2 (E)
  - Medico: Investida Medicinal
  - Soldado: Bazuca
  - Sackboy: Surto
  - Robo: Block
]]
local function onAbility2(player: Player, data: {any}): ()
	local state = _survivorService.getSurvivorExt(player)
	if not state then
		return
	end

	_survivorService.handleAbilityAction(player, "SURVIVOR_A2", nil)
end

--[[
  SURVIVOR_A3: Habilidade 3 (R) - apenas Robo
  - Robo: Autodestruicao
]]
local function onAbility3(player: Player, data: {any}): ()
	local state = _survivorService.getSurvivorExt(player)
	if not state then
		return
	end

	_survivorService.handleAbilityAction(player, "SURVIVOR_A3", nil)
end

-- ============================================================
-- Init/Start
-- ============================================================

--[[
  Init(): configura referencias e conecta handlers.
]]
function SurvivorEvents.Init(
	survivorService: any,
	playerActionEvent: RemoteEvent,
	uiSyncEvent: RemoteEvent
): ()
	print("[TheBrokenBox] SurvivorEvents.Init()")

	_survivorService = survivorService
	_playerActionEvent = playerActionEvent
	_uiSyncEvent = uiSyncEvent

	-- Conectar ao PlayerActionEvent para SURVIVOR_A1/A2/A3
	if _playerActionEvent then
		_playerActionEvent.OnServerEvent:Connect(function(player: Player, message: {any})
			local messageType = message.type
			local data = message.data

			if messageType == "SURVIVOR_A1" then
				onAbility1(player, data)
			elseif messageType == "SURVIVOR_A2" then
				onAbility2(player, data)
			elseif messageType == "SURVIVOR_A3" then
				onAbility3(player, data)
			end
		end)
	end

	print("[TheBrokenBox] SurvivorEvents.Init() concluido.")
end

--[[
  Start(): inicializacao assincrona (vazia por enquanto).
]]
function SurvivorEvents.Start(): ()
	print("[TheBrokenBox] SurvivorEvents.Start() - pronto.")
end

return SurvivorEvents
