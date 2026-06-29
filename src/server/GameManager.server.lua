--!strict
--[[
  GameManager.server.lua
  Ponto de entrada do servidor. Orquestra a inicializacao
  de todos os servicos na ordem correta (Init/Start pattern).

  Fases:
    1. setupEvents()     - criar RemoteEvents em ReplicatedStorage
    2. initServices()    - require + Init() sincrono (injetando dependencias)
    3. wireServiceSignals() - conectar sinais entre servicos
    4. startServices()   - Start() assincrono (listeners, Heartbeat)

  Referencias: architecture.md 4. Padrao Init/Start
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local GameConstants = require(ReplicatedStorage.GameConstants)

-- Cache de servicos
local services = {}

-- Cache de RemoteEvents
local gameStateEvent
local playerActionEvent
local uiSyncEvent

-- ============================================================
-- Helpers para evitar pcall inline + function nesting
-- ============================================================

-- Wrapper seguro para pcall que loga erros
local function safePcall(func, ...)
	local ok, err = pcall(func, ...)
	if not ok then
		warn("[TheBrokenBox] GameManager: ERRO em pcall: " .. tostring(err))
	end
	return ok, err
end

-- Wrapper seguro para require (evita pcall(function() return require(...) end))
local function safeRequire(path)
	return pcall(require, path)
end

-- ============================================================
-- Fase 0: Criacao dos RemoteEvents
-- ============================================================
local function setupEvents()
	print("[TheBrokenBox] GameManager: setupEvents() - criando RemoteEvents...")

	-- Garantir que a pasta Events existe
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "Events"
		eventsFolder.Parent = ReplicatedStorage
	end

	-- Criar ou obter o GameStateEvent
	local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
	gameStateEvent = RemoteEventUtils.createRemoteEvent(eventsFolder, "GameStateEvent")
	playerActionEvent = RemoteEventUtils.createRemoteEvent(eventsFolder, "PlayerActionEvent")
	uiSyncEvent = RemoteEventUtils.createRemoteEvent(eventsFolder, "UISyncEvent")

	print("[TheBrokenBox] GameManager: RemoteEvents criados.")
end

-- ============================================================
-- Fase 1: Init sincrono de todos os servicos
-- ============================================================
local serviceModules = {
	{ name = "MatchService",     module = nil },
	{ name = "StaminaService",   module = nil },
	{ name = "HitboxService",    module = nil },
	{ name = "HunterService",    module = nil },
	{ name = "SurvivorService",  module = nil },
	{ name = "SpawnService",     module = nil },
	{ name = "MapBuilder",       module = nil },
	{ name = "MapService",       module = nil },
	{ name = "MissionService",   module = nil },
	{ name = "CycleService",     module = nil },
	{ name = "LobbyService",     module = nil },
	{ name = "DataStoreManager", module = nil },
	{ name = "ShopService",      module = nil },
	{ name = "EscapeService",    module = nil },
	{ name = "AudioService",     module = nil },
	{ name = "HunterEvents",     module = nil, isEvent = true },
	{ name = "SurvivorEvents",   module = nil, isEvent = true },
	{ name = "MissionEvents",    module = nil, isEvent = true },
}

-- Funcao helper: chama Init() com os argumentos corretos para cada servico
-- Usa if-then-end simples (sem elseif chains)
local function initServiceEntry(name, mod)
	-- SurvivorService.Init(gameStateEvent, playerActionEvent, uiSyncEvent, MatchService)
	if name == "SurvivorService" then
		safePcall(mod.Init, gameStateEvent, playerActionEvent, uiSyncEvent, services.MatchService)
		return
	end

	-- SurvivorEvents.Init(SurvivorService, playerActionEvent, uiSyncEvent)
	if name == "SurvivorEvents" then
		safePcall(mod.Init, services.SurvivorService, playerActionEvent, uiSyncEvent)
		return
	end

	-- ShopService.Init() + injectDataStoreManager(DataStoreManager)
	if name == "ShopService" then
		safePcall(mod.Init)
		if services.DataStoreManager and mod.injectDataStoreManager then
			mod.injectDataStoreManager(services.DataStoreManager)
		end
		return
	end

	-- MissionService.Init(MatchService, MapService)
	if name == "MissionService" then
		safePcall(mod.Init, services.MatchService, services.MapService)
		return
	end

	-- CycleService.Init(MatchService)
	if name == "CycleService" then
		safePcall(mod.Init, services.MatchService)
		return
	end

	-- MissionEvents.Init(MissionService, playerActionEvent)
	if name == "MissionEvents" then
		safePcall(mod.Init, services.MissionService, playerActionEvent)
		return
	end

	-- AudioService.Init(gameStateEvent, MatchService)
	if name == "AudioService" then
		safePcall(mod.Init, gameStateEvent, services.MatchService)
		return
	end

	-- Default: Init()
	safePcall(mod.Init)
end

-- Funcao helper: carrega um modulo e chama Init
local function loadAndInitService(entry)
	local requirePath

	if entry.isEvent then
		requirePath = script.Events[entry.name]
	else
		requirePath = script.Services[entry.name]
	end

	if not requirePath then
		warn("[TheBrokenBox] GameManager: Modulo nao encontrado: " .. entry.name)
		return
	end

	-- Safe require sem pcall nesting
	local ok, mod = safeRequire(requirePath)
	if not ok then
		warn("[TheBrokenBox] GameManager: ERRO ao carregar " .. entry.name .. ": " .. tostring(mod))
		return
	end

	entry.module = mod
	services[entry.name] = mod

	-- Chamar Init() com dependencias apropriadas
	if mod.Init then
		initServiceEntry(entry.name, mod)
	end

	print("[TheBrokenBox] GameManager: " .. entry.name .. " carregado.")
end

local function initServices()
	print("[TheBrokenBox] GameManager: initServices() - iniciando...")

	for _, entry in ipairs(serviceModules) do
		loadAndInitService(entry)
	end

	print("[TheBrokenBox] GameManager: initServices() - concluido.")
end

-- ============================================================
-- Fase 2: Conexao de sinais entre servicos (wiring)
-- ============================================================

-- Sub-funcao 1: Injecao de dependencias
local function wireDependencies()
	local HunterService = services.HunterService
	local HunterEvents = services.HunterEvents
	local SpawnService = services.SpawnService
	local EscapeService = services.EscapeService
	local ShopService = services.ShopService
	local DataStoreManager = services.DataStoreManager
	local MatchService = services.MatchService
	local HitboxService = services.HitboxService
	local StaminaService = services.StaminaService
	local MapService = services.MapService
	local MissionService = services.MissionService

	-- HunterService.injectDependencies(MatchService, HitboxService, StaminaService)
	if HunterService and HunterService.injectDependencies then
		HunterService.injectDependencies(MatchService, HitboxService, StaminaService)
		print("[TheBrokenBox] GameManager: HunterService dependencias injetadas.")
	end

	-- SpawnService.injectDependencies(MatchService, MapService)
	if SpawnService and SpawnService.injectDependencies then
		SpawnService.injectDependencies(MatchService, MapService)
		print("[TheBrokenBox] GameManager: SpawnService dependencias injetadas.")
	end

	-- HunterEvents.injectDependencies(HunterService, MatchService)
	if HunterEvents and HunterEvents.injectDependencies then
		HunterEvents.injectDependencies(HunterService, MatchService)
	end

	-- EscapeService.injectDependencies(MatchService, MapService, MissionService, ShopService)
	if EscapeService and EscapeService.injectDependencies then
		EscapeService.injectDependencies(MatchService, MapService, MissionService, ShopService)
		print("[TheBrokenBox] GameManager: EscapeService dependencias injetadas.")
	end

	-- ShopService.injectDataStoreManager(DataStoreManager)
	if ShopService and DataStoreManager and ShopService.injectDataStoreManager then
		ShopService.injectDataStoreManager(DataStoreManager)
		print("[TheBrokenBox] GameManager: DataStoreManager injetado no ShopService.")
	end
end

-- Sub-funcao 2: Wiring do MatchService + HitboxService + StaminaService
local function wireCoreServices()
	local MatchService = services.MatchService
	local StaminaService = services.StaminaService
	local HitboxService = services.HitboxService

	-- MatchService sinaliza mudanca de estado da partida
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState)
			print("[TheBrokenBox] Estado da partida: " .. newState)
		end)
	end

	-- MatchService sinaliza jogador morto -> notificar servicos
	if MatchService and MatchService.playerDied then
		MatchService.playerDied:Connect(function(player)
			if StaminaService and StaminaService.onPlayerDied then
				StaminaService.onPlayerDied(player)
			end
			if HitboxService and HitboxService.onPlayerDied then
				HitboxService.onPlayerDied(player)
			end
		end)
	end

	-- HitboxService sinaliza dano aplicado -> notificar MatchService
	if HitboxService and HitboxService.damageApplied then
		HitboxService.damageApplied:Connect(function(target, damage, source)
			if MatchService and MatchService.onDamageApplied then
				MatchService.onDamageApplied(target, damage, source)
			end
		end)
	end
end

-- Sub-funcao 3: Wiring do SurvivorService
local function wireSurvivorService()
	local SurvivorService = services.SurvivorService

	-- SurvivorService.survivorDamaged -> UISyncEvent (HUD)
	if SurvivorService and SurvivorService.survivorDamaged then
		SurvivorService.survivorDamaged:Connect(function(player, damage, source)
			if uiSyncEvent then
				local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
				RemoteEventUtils.firePlayer(
					uiSyncEvent,
					player,
					"SURVIVOR_DAMAGED",
					{ damage = damage, source = source and source.Name or nil }
				)
			end
		end)
	end

	-- SurvivorService.survivorHealed -> UISyncEvent (HUD)
	if SurvivorService and SurvivorService.survivorHealed then
		SurvivorService.survivorHealed:Connect(function(player, amount, healer)
			if uiSyncEvent then
				local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
				RemoteEventUtils.firePlayer(
					uiSyncEvent,
					player,
					"SURVIVOR_HEALED",
					{ amount = amount, healer = healer and healer.Name or nil }
				)
			end
		end)
	end

	-- SurvivorService.survivorDied -> GameStateEvent (PLAYER_DIED para todos)
	if SurvivorService and SurvivorService.survivorDied then
		SurvivorService.survivorDied:Connect(function(player)
			if gameStateEvent then
				local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
				RemoteEventUtils.fireAll(
					gameStateEvent,
					"PLAYER_DIED",
					{ userId = player.UserId, name = player.Name }
				)
			end
		end)
	end
end

-- Sub-funcao 4: Wiring do HunterService
local function wireHunterService()
	local MatchService = services.MatchService
	local HunterService = services.HunterService

	-- damageTaken -> onHunterAttacked (ganha Furia)
	if HunterService and MatchService and MatchService.damageTaken then
		MatchService.damageTaken:Connect(function(target, damage, source)
			if HunterService.isHunter(target) then
				HunterService.onHunterAttacked(source)
			end
		end)
	end

	-- roleAssigned -> setHunter
	if HunterService and MatchService and MatchService.roleAssigned then
		MatchService.roleAssigned:Connect(function(player, role)
			if role == "Hunter" then
				HunterService.setHunter(player)
			end
		end)
	end

	-- playerDied -> onHunterDied (limpar estado)
	if HunterService and MatchService and MatchService.playerDied then
		MatchService.playerDied:Connect(function(player)
			if HunterService.isHunter(player) then
				HunterService.onHunterDied()
			end
		end)
	end
end

-- Sub-funcao 5: Wiring do LobbyService + MapService
local function wireLobbyService()
	local MatchService = services.MatchService
	local LobbyService = services.LobbyService
	local MapService = services.MapService

	-- LobbyService.characterSelected -> MatchService.assignHunter/assignSurvivor
	if LobbyService and LobbyService.characterSelected then
		LobbyService.characterSelected:Connect(function(player, characterClass, role)
			if role == "Hunter" and MatchService then
				MatchService.assignHunter(player)
			end
			if role == "Survivor" and MatchService then
				MatchService.assignSurvivor(player, characterClass)
			end
		end)
		print("[TheBrokenBox] GameManager: LobbyService.characterSelected -> MatchService conectado.")
	end

	-- LobbyService.lobbyReady -> MatchService.setMatchState("Selecting")
	if LobbyService and LobbyService.lobbyReady then
		LobbyService.lobbyReady:Connect(function()
			if MatchService then
				MatchService.setMatchState("Selecting")
			end
		end)
		print("[TheBrokenBox] GameManager: LobbyService.lobbyReady -> MatchService.setMatchState conectado.")
	end

	-- MatchService.matchStateChanged(Ended) -> LobbyService.resetToGathering()
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState)
			if newState == "Ended" and LobbyService then
				LobbyService.resetToGathering()
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.matchStateChanged -> LobbyService conectado.")
	end

	-- MatchService.matchStateChanged(Playing) -> MapService.generateMissions + resetSpawnIndex
	if MatchService and MatchService.matchStateChanged and MapService then
		MatchService.matchStateChanged:Connect(function(newState)
			if newState == "Playing" then
				MapService.generateMissions()
				MapService.resetSpawnIndex()
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.matchStateChanged -> MapService (missoes) conectado.")
	end

	-- MatchService.roleAssigned -> MapService.getHunterSpawn/getRandomSurvivorSpawn
	if MatchService and MatchService.roleAssigned and MapService then
		MatchService.roleAssigned:Connect(function(player, role)
			if role == "Hunter" then
				local spawnPos = MapService.getHunterSpawn()
				print("[TheBrokenBox] GameManager: Spawn do Hunter em " .. tostring(spawnPos))
			end
			if role == "Survivor" then
				local spawnPos = MapService.getRandomSurvivorSpawn()
				print("[TheBrokenBox] GameManager: Spawn do Survivor " .. player.Name .. " em " .. tostring(spawnPos))
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.roleAssigned -> MapService (spawns) conectado.")
	end
end

-- Sub-funcao 6: Wiring do EscapeService
local function wireEscapeService()
	local MatchService = services.MatchService
	local EscapeService = services.EscapeService
	local ShopService = services.ShopService
	local CycleService = services.CycleService

	-- CycleService.cycleZero -> EscapeService.startEscape()
	if CycleService and CycleService.cycleZero and EscapeService then
		CycleService.cycleZero:Connect(function()
			print("[TheBrokenBox] GameManager: cycleZero recebido -> iniciando EscapeService")
			EscapeService.startEscape()
		end)
		print("[TheBrokenBox] GameManager: CycleService.cycleZero -> EscapeService.startEscape() conectado.")
	end

	-- EscapeService.playerEscaped -> ShopService.addCoins (+40)
	if EscapeService and EscapeService.playerEscaped then
		EscapeService.playerEscaped:Connect(function(player, gateId)
			if ShopService and ShopService.addCoins then
				ShopService.addCoins(player, GameConstants.Economy.COIN_FUGA)
				print("[TheBrokenBox] GameManager: " .. player.Name .. " escapou - +" .. GameConstants.Economy.COIN_FUGA .. " moedas")
			end
		end)
		print("[TheBrokenBox] GameManager: EscapeService.playerEscaped -> ShopService conectado.")
	end

	-- EscapeService.escapeEnded -> MatchService (MATCH_ENDED + setMatchState("Ended"))
	if EscapeService and EscapeService.escapeEnded then
		EscapeService.escapeEnded:Connect(function(escapedCount, totalAtStart)
			print("[TheBrokenBox] GameManager: escapeEnded - " .. escapedCount .. " escaparam de " .. totalAtStart)

			if MatchService then
				local winner
				local result

				if escapedCount > 0 then
					winner = "Survivors"
					if escapedCount >= totalAtStart then
						result = "FugaTotal"
					else
						result = "FugaParcial"
					end
				else
					winner = "Hunter"
					result = "Contencao"
				end

				-- Disparar MATCH_ENDED via GameStateEvent
				if gameStateEvent then
					local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
					RemoteEventUtils.fireAll(
						gameStateEvent,
						"MATCH_ENDED",
						{
							winner = winner,
							result = result,
							stats = {
								escapes = escapedCount,
								totalSurvivors = totalAtStart,
							}
						}
					)
				end

				-- Transicionar estado da partida
				MatchService.setMatchState("Ended")
			end
		end)
		print("[TheBrokenBox] GameManager: EscapeService.escapeEnded -> MatchService (MATCH_ENDED) conectado.")
	end
end

-- Sub-funcao 7: Wiring do ShopService + DataStoreManager
local function wireShopService()
	local LobbyService = services.LobbyService
	local MissionService = services.MissionService
	local ShopService = services.ShopService
	local DataStoreManager = services.DataStoreManager

	-- MissionService.missionCompleted -> ShopService.addCoins (+15)
	if MissionService and MissionService.missionCompleted then
		MissionService.missionCompleted:Connect(function(player, missionId)
			if ShopService and ShopService.addCoins then
				local GameConstants = require(ReplicatedStorage.GameConstants)
				ShopService.addCoins(player, GameConstants.Economy.COIN_MISSAO)
				print("[TheBrokenBox] GameManager: " .. player.Name .. " completou missao " .. missionId .. " - +" .. GameConstants.Economy.COIN_MISSAO .. " moedas")
			end
		end)
		print("[TheBrokenBox] GameManager: MissionService.missionCompleted -> ShopService (+15 coins) conectado.")
	end

	-- ShopService.characterUnlocked -> LobbyService + UISyncEvent
	if ShopService and ShopService.characterUnlocked then
		ShopService.characterUnlocked:Connect(function(player, characterClass)
			if LobbyService and LobbyService.onCharacterUnlocked then
				LobbyService.onCharacterUnlocked(player, characterClass)
			end

			if uiSyncEvent then
				local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
				RemoteEventUtils.firePlayer(
					uiSyncEvent,
					player,
					"CHARACTER_UNLOCKED",
					{
						characterClass = characterClass,
						coins = ShopService.getCoins and ShopService.getCoins(player) or 0,
					}
				)
			end

			print("[TheBrokenBox] GameManager: " .. player.Name .. " desbloqueou " .. characterClass)
		end)
		print("[TheBrokenBox] GameManager: ShopService.characterUnlocked -> LobbyService/UISync conectado.")
	end

	-- ShopService.coinsUpdated -> UISyncEvent (COINS_UPDATED)
	if ShopService and ShopService.coinsUpdated then
		ShopService.coinsUpdated:Connect(function(player, newTotal)
			if uiSyncEvent then
				local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
				local unlockedChars = {}
				if DataStoreManager then
					local data = DataStoreManager.getPlayerData(player)
					if data and data.unlockedCharacters then
						unlockedChars = data.unlockedCharacters
					end
				end
				RemoteEventUtils.firePlayer(
					uiSyncEvent,
					player,
					"COINS_UPDATED",
					{
						coins = newTotal,
						unlockedCharacters = unlockedChars,
					}
				)
			end
		end)
		print("[TheBrokenBox] GameManager: ShopService.coinsUpdated -> UISyncEvent conectado.")
	end

	-- Handler: BUY_UNLOCK via PlayerActionEvent -> ShopService.buyCharacter
	if playerActionEvent and ShopService then
		playerActionEvent.OnServerEvent:Connect(function(player, message)
			if message and message.type == "BUY_UNLOCK" then
				local data = message.data or {}
				local characterClass = data.characterClass
				if characterClass then
					print("[TheBrokenBox] GameManager: BUY_UNLOCK recebido de " .. player.Name .. " - " .. characterClass)
					ShopService.buyCharacter(player, characterClass)
				end
			end
		end)
		print("[TheBrokenBox] GameManager: BUY_UNLOCK handler conectado (PlayerActionEvent -> ShopService).")
	end

	-- Handler: RETURN_TO_LOBBY + SPECTATE_NEXT via PlayerActionEvent
	if playerActionEvent and LobbyService then
		playerActionEvent.OnServerEvent:Connect(function(player, message)
			if message and message.type == "RETURN_TO_LOBBY" then
				print("[TheBrokenBox] GameManager: RETURN_TO_LOBBY recebido de " .. player.Name)
				if LobbyService.returnPlayerToLobby then
					LobbyService.returnPlayerToLobby(player)
				end
			end
			if message and message.type == "SPECTATE_NEXT" then
				print("[TheBrokenBox] GameManager: SPECTATE_NEXT recebido de " .. player.Name .. " (handler pendente)")
			end
		end)
		print("[TheBrokenBox] GameManager: RETURN_TO_LOBBY + SPECTATE_NEXT handlers conectados (PlayerActionEvent).")
	end
end

-- Sub-funcao 8: Wiring do MissionService + CycleService
local function wireMissionCycle()
	local MatchService = services.MatchService
	local MissionService = services.MissionService
	local CycleService = services.CycleService
	local HunterService = services.HunterService

	-- MissionService.missionCompleted -> CycleService.onMissionCompleted (-10s)
	if MissionService and MissionService.missionCompleted and CycleService then
		MissionService.missionCompleted:Connect(function(player, missionId, missionType)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onMissionCompleted()
				print("[TheBrokenBox] GameManager: missionCompleted -> CycleService (-10s) - " .. missionId)
			end
		end)
		print("[TheBrokenBox] GameManager: MissionService.missionCompleted -> CycleService (-10s) conectado.")
	end

	-- MatchService.playerDied -> CycleService.onPlayerDied (+20s)
	if MatchService and MatchService.playerDied and CycleService then
		MatchService.playerDied:Connect(function(player)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onPlayerDied(player)
				print("[TheBrokenBox] GameManager: playerDied -> CycleService (+20s se Survivor) - " .. player.Name)
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.playerDied -> CycleService (+20s) conectado.")
	end

	-- HunterService.rageActivated -> CycleService.onRageActivated (pause)
	if HunterService and HunterService.rageActivated and CycleService then
		HunterService.rageActivated:Connect(function(hunter)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onRageActivated()
				print("[TheBrokenBox] GameManager: rageActivated -> CycleService (pause)")
			end
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageActivated -> CycleService (pause) conectado.")
	end

	-- HunterService.rageDeactivated -> CycleService.onRageDeactivated (resume)
	if HunterService and HunterService.rageDeactivated and CycleService then
		HunterService.rageDeactivated:Connect(function(hunter, remainingFury)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onRageDeactivated()
				print("[TheBrokenBox] GameManager: rageDeactivated -> CycleService (resume)")
			end
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageDeactivated -> CycleService (resume) conectado.")
	end
end

-- Sub-funcao 9: Wiring do estado Playing + SpawnService + CycleService
local function wirePlayingState()
	local MatchService = services.MatchService
	local MissionService = services.MissionService
	local CycleService = services.CycleService
	local SpawnService = services.SpawnService

	-- MatchService.matchStateChanged(Playing) -> MissionService + CycleService + SpawnService
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState)
			if newState == "Playing" then
				if MissionService and MissionService.initializeMissions then
					MissionService.initializeMissions()
					print("[TheBrokenBox] GameManager: Playing -> MissionService.initializeMissions()")
				end
				if CycleService and CycleService.startCycle then
					CycleService.startCycle()
					print("[TheBrokenBox] GameManager: Playing -> CycleService.startCycle()")
				end
				if SpawnService and SpawnService.teleportAllPlayers then
					SpawnService.teleportAllPlayers()
					print("[TheBrokenBox] GameManager: Playing -> SpawnService.teleportAllPlayers()")
				end
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.matchStateChanged -> MissionService+CycleService+SpawnService (Playing) conectado.")
	end

	-- CycleService.cycleTick -> UISyncEvent (HUD_UPDATE com cycleTime)
	if CycleService and CycleService.cycleTick and uiSyncEvent then
		CycleService.cycleTick:Connect(function(remainingTime)
			local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
			RemoteEventUtils.fireAll(
				uiSyncEvent,
				"HUD_UPDATE",
				{ cycleTime = remainingTime }
			)
		end)
		print("[TheBrokenBox] GameManager: CycleService.cycleTick -> UISyncEvent (cycleTime) conectado.")
	end
end

-- Sub-funcao 10: Wiring do AudioService
local function wireAudioService()
	local MatchService = services.MatchService
	local SurvivorService = services.SurvivorService
	local HunterService = services.HunterService
	local MissionService = services.MissionService
	local CycleService = services.CycleService
	local EscapeService = services.EscapeService
	local AudioService = services.AudioService

	-- SurvivorService.survivorDamaged -> AudioService.onSurvivorDamaged (heartbeat)
	if SurvivorService and SurvivorService.survivorDamaged and AudioService then
		SurvivorService.survivorDamaged:Connect(function(player, damage, source)
			AudioService.onSurvivorDamaged(player, damage, source)
		end)
		print("[TheBrokenBox] GameManager: SurvivorService.survivorDamaged -> AudioService (heartbeat) conectado.")
	end

	-- HunterService.rageActivated -> AudioService.onRageActivated
	if HunterService and HunterService.rageActivated and AudioService then
		HunterService.rageActivated:Connect(function(hunter)
			AudioService.onRageActivated(hunter)
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageActivated -> AudioService conectado.")
	end

	-- HunterService.rageDeactivated -> AudioService.onRageDeactivated
	if HunterService and HunterService.rageDeactivated and AudioService then
		HunterService.rageDeactivated:Connect(function(hunter, remainingFury)
			AudioService.onRageDeactivated(hunter, remainingFury)
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageDeactivated -> AudioService conectado.")
	end

	-- EscapeService.escapeStarted -> AudioService.onEscapeStarted
	if EscapeService and EscapeService.escapeStarted and AudioService then
		EscapeService.escapeStarted:Connect(function()
			AudioService.onEscapeStarted()
		end)
		print("[TheBrokenBox] GameManager: EscapeService.escapeStarted -> AudioService conectado.")
	end

	-- MissionService.missionCompleted -> AudioService.onMissionCompleted
	if MissionService and MissionService.missionCompleted and AudioService then
		MissionService.missionCompleted:Connect(function(player, missionId, missionType)
			if AudioService.onMissionCompleted then
				AudioService.onMissionCompleted(player, missionId, missionType)
			end
		end)
		print("[TheBrokenBox] GameManager: MissionService.missionCompleted -> AudioService (SFX) conectado.")
	end

	-- MatchService.playerDied -> AudioService.onPlayerDied
	if MatchService and MatchService.playerDied and AudioService then
		MatchService.playerDied:Connect(function(player)
			AudioService.onPlayerDied(player)
		end)
		print("[TheBrokenBox] GameManager: MatchService.playerDied -> AudioService (SFX) conectado.")
	end

	-- CycleService.cycleTick -> AudioService.onCycleTick
	if CycleService and CycleService.cycleTick and AudioService then
		CycleService.cycleTick:Connect(function(remainingTime)
			AudioService.onCycleTick(remainingTime)
		end)
		print("[TheBrokenBox] GameManager: CycleService.cycleTick -> AudioService conectado.")
	end
end

-- wireServiceSignals principal
local function wireServiceSignals()
	print("[TheBrokenBox] GameManager: wireServiceSignals() - conectando sinais...")

	wireDependencies()
	wireCoreServices()
	wireSurvivorService()
	wireHunterService()
	wireLobbyService()
	wireEscapeService()
	wireShopService()
	wireMissionCycle()
	wirePlayingState()
	wireAudioService()

	print("[TheBrokenBox] GameManager: wireServiceSignals() - concluido.")
end

-- ============================================================
-- Fase 3: Start assincrono de todos os servicos
-- ============================================================
local function startServices()
	print("[TheBrokenBox] GameManager: startServices() - iniciando listeners...")

	for _, entry in ipairs(serviceModules) do
		local mod = entry.module
		if mod and mod.Start then
			local startOk, startErr = pcall(mod.Start)
			if not startOk then
				warn("[TheBrokenBox] GameManager: ERRO em " .. entry.name .. ".Start(): " .. tostring(startErr))
			end
		end
	end

	print("[TheBrokenBox] GameManager: startServices() - concluido.")
end

-- ============================================================
-- Execucao
-- ============================================================
print("[TheBrokenBox] ========================================")
print("[TheBrokenBox] GameManager iniciando...")
print("[TheBrokenBox] ========================================")

setupEvents()
initServices()
wireServiceSignals()
startServices()

print("[TheBrokenBox] GameManager pronto. Aguardando jogadores...")
