--!strict
--[[
  MissionEvents.lua
  Handler de eventos de interacao com missoes.
  Escuta PlayerActionEvent para INTERACT_MISSION e MISSION_PROGRESS
  e roteia para o MissionService.

  Referencias: GDD M1, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.GameConstants)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local MissionEvents = {}
MissionEvents.Name = "MissionEvents"

-- Referencias injetadas
local _missionService = nil
local _playerActionEvent: RemoteEvent = nil

-- ============================================================
-- Handlers de interacao com missoes
-- ============================================================

--[[
  INTERACT_MISSION: jogador pressionou E perto de uma missao.
  O servidor decide qual missao esta mais proxima e inicia.
]]
local function onInteractMission(player: Player, data: {any}): ()
	-- Validar dados basicos
	local data = data or {}

	-- Se o cliente enviou missionId, usa-lo
	-- Senao, procurar a missao mais proxima
	local missionId = data.missionId

	if not missionId then
		-- Procurar missao mais proxima
		missionId = findNearestMission(player)
		if not missionId then
			-- Nenhuma missao proxima
			return
		end
	end

	-- Tentar iniciar a missao
	local success, reason = _missionService.startMission(player, missionId)
	if not success then
		-- Enviar feedback ao cliente (futuro: mensagem na tela)
		-- Por enquanto, apenas log
		if reason then
			print("[TheBrokenBox] MissionEvents: Interacao recusada para " .. player.Name .. " - " .. reason)
		end
		return
	end

	print("[TheBrokenBox] MissionEvents: INTERACT_MISSION - " .. player.Name .. " iniciou " .. missionId)
end

--[[
  MISSION_PROGRESS: jogador enviou progresso do minigame.
  Valida server-side e, se completo, dispara missionCompleted.
]]
local function onMissionProgress(player: Player, data: {any}): ()
	if not data or not data.missionId then
		warn("[TheBrokenBox] MissionEvents: MISSION_PROGRESS sem missionId de " .. player.Name)
		return
	end

	local missionId = data.missionId
	local progressData = data

	local success, reason = _missionService.processProgress(player, missionId, progressData)

	if not success then
		if reason then
			print("[TheBrokenBox] MissionEvents: Progresso recusado de " .. player.Name .. " - " .. reason)
		end
		return
	end

	if reason == "completed" then
		print("[TheBrokenBox] MissionEvents: MISSION_PROGRESS - " .. player.Name .. " completou " .. missionId)
	else
		-- Progresso aceito, mas ainda nao completo
		-- (log silencioso para nao poluir)
	end
end

--[[
  Encontra a missao mais proxima de um jogador.
  Usado quando o cliente nao especifica qual missao interagir.
]]
function findNearestMission(player: Player): string
	if not _missionService then
		return nil
	end

	local character = player.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local playerPos = rootPart.Position
	local nearestId: string = nil
	local nearestDist = math.huge
	local interactRange = 12 -- mesmo de MissionService

	local allMissions = _missionService.getAllMissions()
	for missionId, mission in pairs(allMissions) do
		if mission.state == "PENDING" then
			local dist = (mission.position - playerPos).Magnitude
			if dist < interactRange and dist < nearestDist then
				nearestDist = dist
				nearestId = missionId
			end
		end
	end

	return nearestId
end

--[[
  Cancela a missao atual do jogador.
  Chamado externamente (ex.: quando jogador se move durante missao).
]]
local function onMissionCancel(player: Player, data: {any}?): ()
	if not _missionService then
		return
	end

	local reason = (data and data.reason) or "movement"
	_missionService.cancelMission(player, reason)
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): configura referencias e conecta handlers.
]]
function MissionEvents.Init(
	missionService: any,
	playerActionEvent: RemoteEvent
): ()
	print("[TheBrokenBox] MissionEvents.Init()")

	_missionService = missionService
	_playerActionEvent = playerActionEvent

	-- Conectar ao PlayerActionEvent para INTERACT_MISSION e MISSION_PROGRESS
	if _playerActionEvent then
		_playerActionEvent.OnServerEvent:Connect(function(player: Player, message: {any})
			local messageType = message.type
			local data = message.data

			if messageType == "INTERACT_MISSION" then
				onInteractMission(player, data)
			elseif messageType == "MISSION_PROGRESS" then
				onMissionProgress(player, data)
			elseif messageType == "MISSION_CANCEL" then
				onMissionCancel(player, data)
			end
		end)
		print("[TheBrokenBox] MissionEvents: Handlers conectados ao PlayerActionEvent.")
	end

	print("[TheBrokenBox] MissionEvents.Init() concluido.")
end

--[[
  Start(): inicializacao assincrona (vazia).
]]
function MissionEvents.Start(): ()
	print("[TheBrokenBox] MissionEvents.Start() - pronto.")
end

return MissionEvents
