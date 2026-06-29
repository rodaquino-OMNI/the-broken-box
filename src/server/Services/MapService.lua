--!strict
--[[
  MapService.lua
  Servico de dominio que fornece dados do mapa Criatividade Morta.
  Le MapData (shared) e expoe:
    - Sorteio de locais de missao (10 de ~14, >=1 de cada tipo)
    - Posicoes dos portoes
    - Spawn points (aleatorios para Sobreviventes)
    - Checks de area (isPlayerInCastle, isPlayerInCavern, isPlayerInEstoque)

  Init/Start pattern.
  Referencias: GDD Design do Mapa, architecture.md 118/10
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local MapData = require(ReplicatedStorage.MapData.MapData)
local Signal = require(ReplicatedStorage.Util.Signal)

local MapService = {}
MapService.Name = "MapService"

-- ============================================================
-- Estado interno
-- ============================================================

-- Missoes ativas nesta partida (10 selecionadas dos ~14 candidatos)
local _activeMissions: {} = {}

-- Indice do proximo spawn de Sobrevivente (round-robin)
local _nextSurvivorSpawnIndex: number = 1

-- ============================================================
-- API: Dados do mapa (passivo, sem sinais)
-- ============================================================

--[[
  Retorna os 3 portoes de fuga com posicoes.
]]
function MapService.getGates(): { any }
	return MapData.GATES
end

--[[
  Retorna a posicao de um portao especifico por ID.
]]
function MapService.getGatePosition(gateId: string): Vector3?
	for _, gate in ipairs(MapData.GATES) do
		if gate.id == gateId then
			return MapData.toVector3(gate.position)
		end
	end
	return nil
end

-- ============================================================
-- API: Spawn points
-- ============================================================

--[[
  Retorna o spawn fixo do Cacador como Vector3.
]]
function MapService.getHunterSpawn(): Vector3
	return MapData.toVector3(MapData.HUNTER_SPAWN)
end

--[[
  Retorna um spawn de Sobrevivente (round-robin entre os 8).
  Garante distribuicao uniforme dos jogadores.
]]
function MapService.getNextSurvivorSpawn(): Vector3
	local spawns = MapData.SURVIVOR_SPAWNS
	local spawn = spawns[_nextSurvivorSpawnIndex]
	local pos = MapData.toVector3(spawn)

	-- Avanca o indice (circular)
	_nextSurvivorSpawnIndex = _nextSurvivorSpawnIndex + 1
	if _nextSurvivorSpawnIndex > #spawns then
		_nextSurvivorSpawnIndex = 1
	end

	return pos
end

--[[
  Retorna um spawn de Sobrevivente aleatorio.
  Usado para spawn inicial (nao sequencial).
]]
function MapService.getRandomSurvivorSpawn(): Vector3
	local spawns = MapData.SURVIVOR_SPAWNS
	local randomIndex = math.random(1, #spawns)
	return MapData.toVector3(spawns[randomIndex])
end

--[[
  Reseta o indice de spawn (chamado no inicio de cada partida).
]]
function MapService.resetSpawnIndex(): ()
	_nextSurvivorSpawnIndex = 1
end

-- ============================================================
-- API: Missoes
-- ============================================================

--[[
  Sorteia 10 missoes dos ~14 candidatos.
  Garante >=1 de cada tipo (V1, V2, V3).
  Chamado no inicio de cada partida.
]]
function MapService.generateMissions(): { any }
	local candidates = MapData.MISSION_CANDIDATES
	local totalNeeded = GameConstants.Missions.TOTAL_PER_MATCH  -- 10
	local minEachVariant = GameConstants.Missions.MIN_EACH_VARIANT  -- 1

	-- Separar candidatos por tipo
	local byType: { [string]: { any } } = {
		V1 = {},
		V2 = {},
		V3 = {},
	}

	for _, candidate in ipairs(candidates) do
		local t = candidate.type
		if byType[t] then
			table.insert(byType[t], candidate)
		end
	end

	-- Resultado: missoes selecionadas
	local selected: { any } = {}

	-- Funcao auxiliar: remover um candidato especifico da pool
	local function removeCandidate(pool: { any }, candidate: any): ()
		for i, c in ipairs(pool) do
			if c.id == candidate.id then
				table.remove(pool, i)
				return
			end
		end
	end

	-- Fase 1: Garantir minimo de cada tipo
	for variant, pool in pairs(byType) do
		for _ = 1, minEachVariant do
			if #pool == 0 then
				warn("[TheBrokenBox] MapService: Sem candidatos suficientes do tipo " .. variant)
				break
			end
			local randomIndex = math.random(1, #pool)
			local chosen = pool[randomIndex]
			table.insert(selected, chosen)
			table.remove(pool, randomIndex)
		end
	end

	-- Fase 2: Preencher o resto (ate totalNeeded) de qualquer tipo
	-- Juntar todos os candidatos restantes em uma unica pool
	local remainingPool: { any } = {}
	for _, pool in pairs(byType) do
		for _, candidate in ipairs(pool) do
			table.insert(remainingPool, candidate)
		end
	end

	while #selected < totalNeeded and #remainingPool > 0 do
		local randomIndex = math.random(1, #remainingPool)
		local chosen = remainingPool[randomIndex]
		table.insert(selected, chosen)
		table.remove(remainingPool, randomIndex)
	end

	-- Embaralhar a ordem final
	for i = #selected, 2, -1 do
		local j = math.random(1, i)
		selected[i], selected[j] = selected[j], selected[i]
	end

	_activeMissions = selected

	print("[TheBrokenBox] MapService: " .. #selected .. " missoes geradas para a partida.")
	return selected
end

--[[
  Retorna as missoes ativas da partida atual.
]]
function MapService.getActiveMissions(): { any }
	return _activeMissions
end

--[[
  Retorna todas as posicoes de missoes ativas como Vector3.
]]
function MapService.getMissionPositions(): { Vector3 }
	local positions = {}
	for _, mission in ipairs(_activeMissions) do
		table.insert(positions, MapData.toVector3(mission.position))
	end
	return positions
end

-- ============================================================
-- API: Checks de area (estruturas)
-- ============================================================

--[[
  Verifica se uma posicao (Vector3) esta dentro do Castelo.
]]
function MapService.isPositionInCastle(pos: Vector3): boolean
	local s = MapData.STRUCTURES.CASTLE
	return pos.X >= s.min.x and pos.X <= s.max.x
		and pos.Y >= s.min.y and pos.Y <= s.max.y
		and pos.Z >= s.min.z and pos.Z <= s.max.z
end

--[[
  Verifica se uma posicao (Vector3) esta dentro da Caverna.
]]
function MapService.isPositionInCavern(pos: Vector3): boolean
	local s = MapData.STRUCTURES.CAVERN
	return pos.X >= s.min.x and pos.X <= s.max.x
		and pos.Y >= s.min.y and pos.Y <= s.max.y
		and pos.Z >= s.min.z and pos.Z <= s.max.z
end

--[[
  Verifica se uma posicao (Vector3) esta dentro do Estoque.
]]
function MapService.isPositionInEstoque(pos: Vector3): boolean
	local s = MapData.STRUCTURES.WAREHOUSE
	return pos.X >= s.min.x and pos.X <= s.max.x
		and pos.Y >= s.min.y and pos.Y <= s.max.y
		and pos.Z >= s.min.z and pos.Z <= s.max.z
end

--[[
  Verifica se um jogador esta no Castelo.
]]
function MapService.isPlayerInCastle(player: Player): boolean
	local char = player.Character
	if not char or not char.PrimaryPart then
		return false
	end
	return MapService.isPositionInCastle(char.PrimaryPart.Position)
end

--[[
  Verifica se um jogador esta na Caverna.
]]
function MapService.isPlayerInCavern(player: Player): boolean
	local char = player.Character
	if not char or not char.PrimaryPart then
		return false
	end
	return MapService.isPositionInCavern(char.PrimaryPart.Position)
end

--[[
  Verifica se um jogador esta no Estoque.
]]
function MapService.isPlayerInEstoque(player: Player): boolean
	local char = player.Character
	if not char or not char.PrimaryPart then
		return false
	end
	return MapService.isPositionInEstoque(char.PrimaryPart.Position)
end

--[[
  Retorna o nome da estrutura onde o jogador esta, ou nil.
]]
function MapService.getPlayerStructure(player: Player): string?
	local char = player.Character
	if not char or not char.PrimaryPart then
		return nil
	end
	return MapData.getStructureAtPosition(char.PrimaryPart.Position)
end

-- ============================================================
-- API: Obstaculos
-- ============================================================

--[[
  Retorna todas as posicoes de obstaculos como Vector3.
]]
function MapService.getObstaclePositions(): { Vector3 }
	local positions = {}
	for _, obs in ipairs(MapData.OBSTACLES) do
		table.insert(positions, MapData.toVector3(obs.position))
	end
	return positions
end

--[[
  Retorna os dados completos dos obstaculos (posicao + tamanho).
]]
function MapService.getObstacles(): { any }
	return MapData.OBSTACLES
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono.
]]
function MapService.Init(): ()
	print("[TheBrokenBox] MapService.Init()")
	_activeMissions = {}
	_nextSurvivorSpawnIndex = 1
end

--[[
  Start(): geracao inicial de missoes para a partida.
  Chamado quando a partida comeca (estado PREPARING -> PLAYING).
]]
function MapService.Start(): ()
	print("[TheBrokenBox] MapService.Start()")
	-- Missoes serao geradas quando a partida iniciar
	-- (chamado externamente por LobbyService/GameManager)
end

return MapService
