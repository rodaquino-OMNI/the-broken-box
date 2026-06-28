--!strict
--[[
  SpawnService.lua
  Servico de teleporte de spawn no inicio da partida.
  Quando o estado muda para "Playing", teleporta:
    - Cacador (Hunter) -> centro do mapa (posicao fixa)
    - Sobreviventes -> posicoes aleatorias do mapa

  Usa MapService para obter as coordenadas de spawn.
  Dependencias injetadas pelo GameManager: MatchService, MapService.

  Init/Start pattern. Sem sinais proprios — opera por chamada direta.
  Referencias: GDD Design do Mapa, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnService = {}
SpawnService.Name = "SpawnService"

-- ============================================================
-- Referencias a outros servicos (injetadas pelo GameManager)
-- ============================================================
local MatchService = nil
local MapService = nil

-- ============================================================
-- API: Teleporte de jogadores
-- ============================================================

--[[
  Aguarda o personagem de um jogador carregar.
  Retorna o character ou nil apos timeout.
]]
local function waitForCharacter(player: Player, timeout: number): Model?
	local startTime = os.clock()
	while os.clock() - startTime < timeout do
		local character = player.Character
		if character and character.PrimaryPart then
			return character
		end
		task.wait(0.1)
	end
	return player.Character -- Ultima tentativa (pode ser nil)
end

--[[
  Teleporta um jogador para uma posicao Vector3.
  Usa PivotTo (API moderna do Roblox) para mover o personagem.
]]
local function teleportPlayer(player: Player, position: Vector3): ()
	local character = player.Character
	if not character then
		warn("[TheBrokenBox] SpawnService: Personagem nao encontrado para " .. player.Name .. " — aguardando...")
		character = waitForCharacter(player, 5)
	end

	if not character then
		warn("[TheBrokenBox] SpawnService: NAO foi possivel obter personagem de " .. player.Name .. " apos timeout!")
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("[TheBrokenBox] SpawnService: HumanoidRootPart nao encontrado para " .. player.Name)
		return
	end

	-- Criar CFrame na posicao de destino (mantendo orientacao original)
	local targetCFrame = CFrame.new(position)
	character:PivotTo(targetCFrame)

	print("[TheBrokenBox] SpawnService: " .. player.Name .. " teleportado para " .. tostring(position))
end

--[[
  Teleporta todos os jogadores para suas posicoes de spawn.
  - Hunter -> centro do mapa (getHunterSpawn)
  - Survivors -> posicoes aleatorias (getRandomSurvivorSpawn)

  Chamado quando o estado da partida muda para "Playing".
]]
function SpawnService.teleportAllPlayers(): ()
	if not MatchService or not MapService then
		warn("[TheBrokenBox] SpawnService: Dependencias nao injetadas! MatchService=" .. tostring(MatchService) .. " MapService=" .. tostring(MapService))
		return
	end

	print("[TheBrokenBox] SpawnService: Teleportando jogadores para posicoes de spawn...")

	local hunterSpawn = MapService.getHunterSpawn()
	local survivorsTeleported = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local role = MatchService.getPlayerRole(player)

		if role == "Hunter" then
			-- Spawn fixo do Cacador (centro do mapa)
			teleportPlayer(player, hunterSpawn)
			print("[TheBrokenBox] SpawnService: Cacador " .. player.Name .. " -> centro " .. tostring(hunterSpawn))

		elseif role == "Survivor" then
			-- Spawn aleatorio do Sobrevivente
			local spawnPos = MapService.getRandomSurvivorSpawn()
			teleportPlayer(player, spawnPos)
			survivorsTeleported = survivorsTeleported + 1
			print("[TheBrokenBox] SpawnService: Sobrevivente " .. player.Name .. " -> " .. tostring(spawnPos))
		end
	end

	print("[TheBrokenBox] SpawnService: Teleporte concluido. " .. survivorsTeleported .. " Sobreviventes teleportados.")
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono.
]]
function SpawnService.Init(): ()
	print("[TheBrokenBox] SpawnService.Init()")
end

--[[
  Start(): listeners (se necessario).
  O wiring real e feito pelo GameManager em wireServiceSignals().
]]
function SpawnService.Start(): ()
	print("[TheBrokenBox] SpawnService.Start()")
end

-- ============================================================
-- Injecao de dependencias (chamado pelo GameManager)
-- ============================================================

--[[
  Injeta referencias aos servicos necessarios.
  Chamado pelo GameManager durante wireServiceSignals().
]]
function SpawnService.injectDependencies(
	matchSvc: {},
	mapSvc: {}
): ()
	MatchService = matchSvc
	MapService = mapSvc
	print("[TheBrokenBox] SpawnService: Dependencias injetadas (MatchService, MapService).")
end

return SpawnService
