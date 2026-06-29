--!strict
--[[
  MissionService.lua
  Servico de dominio que gerencia missoes (V1/V2/V3 minigames).
  Gerencia:
    - Estado das 10 missoes ativas por partida
    - Validacao server-side de progresso (anti-exploit)
    - Sinais: missionStarted, missionCancelled, missionCompleted

  Tipos de missao:
    V1 Breaker  - 4 alavancas para direita, 4x repeticoes
    V2 Generator - 5 cabos, conectar em sequencia, 4x repeticoes
    V3 Oil Machine - 1x ponteiro/zona de acerto

  Init/Start pattern.
  Referencias: GDD M1, GameConstants.Missions
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)

local MissionService = {}
MissionService.Name = "MissionService"

-- ============================================================
-- Sinais do servico
-- ============================================================
MissionService.missionStarted = Signal.new()     -- (player: Player, missionId: string, missionType: string)
MissionService.missionCancelled = Signal.new()   -- (player: Player, missionId: string, missionType: string, reason: string)
MissionService.missionCompleted = Signal.new()   -- (player: Player, missionId: string, missionType: string)

-- ============================================================
-- Referencias a outros servicos (injetadas no Init)
-- ============================================================
local MatchService = nil
local MapService = nil

-- ============================================================
-- Estado interno das missoes
-- ============================================================
type MissionState = "PENDING" | "IN_PROGRESS" | "COMPLETED"

type MissionData = {
	id: string,
	type: string,             -- "V1" | "V2" | "V3"
	position: Vector3,
	repetitions: number,      -- Total de repeticoes (V1=4, V2=4, V3=1)
	completedReps: number,    -- Repeticoes ja concluidas
	assignedPlayer: Player?, -- Jogador atualmente executando (nil se livre)
	state: MissionState,
	startTime: number,        -- os.clock() de quando IN_PROGRESS comecou
	minCompletionTime: number, -- Tempo minimo anti-exploit (s)
	interactRange: number,     -- Range de interacao (studs)
	-- Progresso especifico por tipo
	progress: number,          -- V1: levers toggled (0-4); V2: cables connected (0-5); V3: 0 or 1
}

-- Tabela de missoes: missionId -> MissionData
local _missions: { [string]: MissionData } = {}

-- ============================================================
-- Constantes de validacao (anti-exploit)
-- ============================================================
local MISSION_RANGES = {
	INTERACT = 12,   -- Distancia maxima para interagir (studs)
	CANCEL = 20,     -- Distancia para cancelar automatico (studs)
}

local MIN_COMPLETION_TIMES = {
	V1 = 60/10,  -- 4 levers x 4 reps = minimo ~6s (1.5s por rep)
	V2 = 80/10,  -- 5 cables x 4 reps = minimo ~8s (2s por rep)
	V3 = 25/10,  -- 1x ponteiro = minimo ~2.5s
}

-- ============================================================
-- Funcoes auxiliares
-- ============================================================

--[[
  Obtem a configuracao de uma missao a partir do MapService.
  Procura nas missoes ativas pelo ID.
]]
local function getMissionCandidate(missionId: string)?
	if not MapService then
		return nil
	end
	local activeMissions = MapService.getActiveMissions()
	for _, candidate in ipairs(activeMissions) do
		if candidate.id == missionId then
			return candidate
		end
	end
	return nil
end

--[[
  Calcula a distancia entre um jogador e uma missao.
]]
local function getPlayerDistanceToMission(player: Player, missionData: MissionData): number?
	local character = player.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	return (rootPart.Position - missionData.position).Magnitude
end

--[[
  Verifica se um jogador pode interagir com uma missao.
  - Vivo
  - Role = Survivor
  - Nao esta em outra missao
  - Missao existe e esta PENDING
  - Dentro do range
]]
local function canInteractWithMission(player: Player, missionId: string): (boolean, string?)
	-- Verificar dados do jogador
	if not MatchService then
		return false, "MatchService indisponivel"
	end

	local playerData = MatchService.getPlayerData(player)
	if not playerData then
		return false, "Jogador nao registrado"
	end
	if not playerData.isAlive then
		return false, "Jogador morto"
	end
	if playerData.role ~= "Survivor" then
		return false, "Nao e Sobrevivente"
	end

	-- Verificar se ja esta em uma missao
	for _, mission in pairs(_missions) do
		if mission.assignedPlayer == player then
			return false, "Ja esta em uma missao (" .. mission.id .. ")"
		end
	end

	-- Verificar se a missao existe
	local mission = _missions[missionId]
	if not mission then
		return false, "Missao nao encontrada"
	end
	if mission.state ~= "PENDING" then
		return false, "Missao nao disponivel (estado: " .. tostring(mission.state) .. ")"
	end

	-- Verificar distancia
	local distance = getPlayerDistanceToMission(player, mission)
	if not distance then
		return false, "Personagem nao carregado"
	end
	if distance > MISSION_RANGES.INTERACT then
		return false, "Muito longe da missao"
	end

	-- Verificar se a missao ainda existe nas ativas
	local candidate = getMissionCandidate(missionId)
	if not candidate then
		return false, "Missao removida do mapa"
	end

	return true, nil
end

-- ============================================================
-- API: Inicializacao das missoes da partida
-- ============================================================

--[[
  Inicializa as missoes a partir dos candidatos ativos do MapService.
  Chamado quando a partida comeca (Playing).
]]
function MissionService.initializeMissions(): ()
	_missions = {}

	if not MapService then
		warn("[TheBrokenBox] MissionService: MapService indisponivel! Nao e possivel inicializar missoes.")
		return
	end

	local activeMissions = MapService.getActiveMissions()
	if #activeMissions == 0 then
		-- Gerar missoes se ainda nao foram geradas
		activeMissions = MapService.generateMissions()
	end

	for _, candidate in ipairs(activeMissions) do
		local missionType = candidate.type
		local missionConfig: {any}? = nil

		if missionType == "V1" then
			missionConfig = GameConstants.Missions.V1_BREAKER
		elseif missionType == "V2" then
			missionConfig = GameConstants.Missions.V2_GENERATOR
		elseif missionType == "V3" then
			missionConfig = GameConstants.Missions.V3_OIL
		end

		if missionConfig then
			local missionData: MissionData = {
				id = candidate.id,
				type = missionType,
				position = require(ReplicatedStorage.MapData.MapData).toVector3(candidate.position),
				repetitions = missionConfig.REPETITIONS or 1,
				completedReps = 0,
				assignedPlayer = nil,
				state = "PENDING",
				startTime = 0,
				minCompletionTime = MIN_COMPLETION_TIMES[missionType] or 30/10,
				interactRange = MISSION_RANGES.INTERACT,
				progress = 0,
			}
			_missions[candidate.id] = missionData
		end
	end

	print("[TheBrokenBox] MissionService: " .. #activeMissions .. " missoes inicializadas.")
end

-- ============================================================
-- API: Interacao com missoes
-- ============================================================

--[[
  Tenta iniciar uma missao para um jogador.
  Chamado quando o servidor recebe INTERACT_MISSION.
  Retorna true se a missao foi iniciada.
]]
function MissionService.startMission(player: Player, missionId: string): (boolean, string?)
	local canStart, reason = canInteractWithMission(player, missionId)
	if not canStart then
		return false, reason
	end

	local mission = _missions[missionId]
	if not mission then
		return false, "Missao nao encontrada"
	end

	-- Marcar missao como em progresso
	mission.state = "IN_PROGRESS"
	mission.assignedPlayer = player
	mission.startTime = os.clock()
	mission.progress = 0

	print("[TheBrokenBox] MissionService: Missao iniciada - " .. missionId .. " (" .. mission.type .. ") por " .. player.Name)
	MissionService.missionStarted:Fire(player, missionId, mission.type)

	return true, nil
end

--[[
  Cancela a missao ativa de um jogador.
  Pode ser chamado por movimento (cliente) ou por desistencia.
]]
function MissionService.cancelMission(player: Player, reason: string?): ()
	for missionId, mission in pairs(_missions) do
		if mission.assignedPlayer == player and mission.state == "IN_PROGRESS" then
			local missionType = mission.type
			mission.state = "PENDING"
			mission.assignedPlayer = nil
			mission.progress = 0
			mission.startTime = 0

			print("[TheBrokenBox] MissionService: Missao cancelada - " .. missionId .. " (" .. missionType .. ") por " .. player.Name .. " (" .. (reason or "desconhecido") .. ")")
			MissionService.missionCancelled:Fire(player, missionId, missionType, reason or "cancel")

			return
		end
	end
end

--[[
  Processa o progresso de uma missao.
  Chamado quando o servidor recebe MISSION_PROGRESS.
  Valida server-side e, quando completo, dispara missionCompleted.
]]
function MissionService.processProgress(player: Player, missionId: string, progressData: {any}?): (boolean, string?)
	-- Encontrar a missao
	local mission = _missions[missionId]
	if not mission then
		return false, "Missao nao encontrada"
	end

	-- Validar que o jogador e o dono da missao
	if mission.assignedPlayer ~= player then
		return false, "Voce nao esta executando esta missao"
	end

	-- Validar estado
	if mission.state ~= "IN_PROGRESS" then
		return false, "Missao nao esta em progresso"
	end

	-- Verificar distancia (anti-cheat)
	local distance = getPlayerDistanceToMission(player, mission)
	if not distance then
		return false, "Personagem nao carregado"
	end
	if distance > MISSION_RANGES.CANCEL then
		-- Muito longe, cancelar automaticamente
		MissionService.cancelMission(player, "range_exceeded")
		return false, "Muito longe da missao"
	end

	-- Validar progresso
	if not progressData then
		return false, "Dados de progresso ausentes"
	end

	local newProgress = progressData.progress
	if type(newProgress) ~= "number" then
		return false, "Progresso invalido"
	end

	-- Validar que o progresso avanca (nao retrocede nem pula)
	if newProgress <= mission.progress then
		return false, "Progresso nao avancou"
	end

	-- Validar anti-exploit: progresso maximo por tipo
	local maxProgress = 1 -- default
	if mission.type == "V1" then
		maxProgress = GameConstants.Missions.V1_BREAKER.REPETITIONS or 4
	elseif mission.type == "V2" then
		maxProgress = GameConstants.Missions.V2_GENERATOR.REPETITIONS or 4
	elseif mission.type == "V3" then
		maxProgress = 1
	end

	if newProgress > maxProgress then
		warn("[TheBrokenBox] MissionService: Progresso suspeito de " .. player.Name .. " - " .. newProgress .. " > " .. maxProgress)
		return false, "Progresso invalido"
	end

	-- Atualizar progresso
	mission.progress = newProgress

	-- Verificar completude
	if newProgress >= maxProgress then
		-- Verificar tempo minimo (anti-exploit)
		local elapsed = os.clock() - mission.startTime
		if elapsed < mission.minCompletionTime then
			warn("[TheBrokenBox] MissionService: Completou rapido demais! " .. player.Name .. " - " .. string.format("%.2f", elapsed) .. "s < " .. mission.minCompletionTime .. "s")
			-- Nao completar, aguardar mais
			return true, "ok" -- Aceita o progresso mas nao completa ainda
		end

		-- Completar a missao
		mission.state = "COMPLETED"
		mission.completedReps = mission.completedReps + 1

		print("[TheBrokenBox] MissionService: Missao COMPLETA - " .. missionId .. " (" .. mission.type .. ") por " .. player.Name)
		MissionService.missionCompleted:Fire(player, missionId, mission.type)

		return true, "completed"
	end

	return true, "ok"
end

-- ============================================================
-- API: Consulta de estado
-- ============================================================

--[[
  Retorna os dados de uma missao especifica.
]]
function MissionService.getMission(missionId: string): MissionData?
	return _missions[missionId]
end

--[[
  Retorna todas as missoes (para HUD / debug).
]]
function MissionService.getAllMissions(): { [string]: MissionData }
	return _missions
end

--[[
  Retorna a missao que um jogador esta executando, ou nil.
]]
function MissionService.getPlayerMission(player: Player): (string, MissionData)?
	for missionId, mission in pairs(_missions) do
		if mission.assignedPlayer == player and mission.state == "IN_PROGRESS" then
			return missionId, mission
		end
	end
	return nil
end

--[[
  Verifica se uma missao esta completa.
]]
function MissionService.isMissionCompleted(missionId: string): boolean
	local mission = _missions[missionId]
	return mission ~= nil and mission.state == "COMPLETED"
end

--[[
  Retorna a contagem de missoes por estado.
]]
function MissionService.getMissionCountByState(state: MissionState): number
	local count = 0
	for _, mission in pairs(_missions) do
		if mission.state == state then
			count = count + 1
		end
	end
	return count
end

--[[
  Retorna a contagem de missoes completadas.
]]
function MissionService.getCompletedCount(): number
	local count = 0
	for _, mission in pairs(_missions) do
		if mission.state == "COMPLETED" then
			count = count + 1
		end
	end
	return count
end

--[[
  Retorna uma lista de missoes pendentes (nao completadas).
  Usado pelo EscapeService para calcular a janela de fuga
  e ativar perigos das missoes nao concluidas.

  Retorna: { { id, type, position }, ... }
]]
function MissionService.getPendingMissions()
	local pendingList = {}
	for _, mission in pairs(_missions) do
		if mission.state ~= "COMPLETED" then
			table.insert(pendingList, {
				id = mission.id,
				type = mission.type,
				position = mission.position,
			})
		end
	end
	return pendingList
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono. Recebe referencias de servicos.
]]
function MissionService.Init(
	matchService: any,
	mapService: any
): ()
	print("[TheBrokenBox] MissionService.Init()")

	MatchService = matchService
	MapService = mapService
	_missions = {}
end

--[[
  Start(): inicializacao assincrona.
]]
function MissionService.Start(): ()
	print("[TheBrokenBox] MissionService.Start() - pronto.")
	-- Missoes sao inicializadas quando a partida atinge Playing
end

return MissionService
