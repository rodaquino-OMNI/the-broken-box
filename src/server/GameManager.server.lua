--!strict
--[[
  GameManager.server.lua
  Ponto de entrada do servidor. Orquestra a inicializacao
  de todos os servicos na ordem correta (Init/Start pattern).

  Fases:
    1. setupEvents()     — criar RemoteEvents em ReplicatedStorage
    2. initServices()     — require + Init() sincrono (injetando dependencias)
    3. wireServiceSignals() — conectar sinais entre servicos
    4. startServices()    — Start() assincrono (listeners, Heartbeat)

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
local gameStateEvent: RemoteEvent?
local playerActionEvent: RemoteEvent?
local uiSyncEvent: RemoteEvent?

-- ============================================================
-- Fase 0: Criacao dos RemoteEvents
-- ============================================================
local function setupEvents()
	print("[TheBrokenBox] GameManager: setupEvents() — criando RemoteEvents...")

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

local function initServices()
print("[TheBrokenBox] GameManager: initServices() — iniciando...")

for _, entry in ipairs(serviceModules) do
	local modLoaded = false
	local requirePath: ModuleScript?

	if entry.isEvent then
		requirePath = script.Events[entry.name]
	else
		requirePath = script.Services[entry.name]
	end

	if requirePath then
		local success, mod = pcall(function()
			return require(requirePath)
		end)

		if success then
			entry.module = mod
			services[entry.name] = mod
			modLoaded = true
		else
			warn("[TheBrokenBox] GameManager: ERRO ao carregar " .. entry.name .. ": " .. tostring(mod))
		end
	else
		warn("[TheBrokenBox] GameManager: Modulo nao encontrado: " .. entry.name)
	end

	if modLoaded then
		local mod = entry.module

		-- Chamar Init() com dependencias apropriadas
		if mod.Init then
			local initOk, initErr
			if entry.name == "SurvivorService" then
				initOk, initErr = pcall(function()
					mod.Init(
						gameStateEvent :: RemoteEvent,
						playerActionEvent :: RemoteEvent,
						uiSyncEvent :: RemoteEvent,
						services.MatchService
					)
				end)
			elseif entry.name == "SurvivorEvents" then
				initOk, initErr = pcall(function()
					mod.Init(
						services.SurvivorService,
						playerActionEvent :: RemoteEvent,
						uiSyncEvent :: RemoteEvent
					)
				end)
			elseif entry.name == "ShopService" then
				initOk, initErr = pcall(function()
					mod.Init()
					-- Injetar DataStoreManager apos Init (dependencia hard)
					if services.DataStoreManager and mod.injectDataStoreManager then
						mod.injectDataStoreManager(services.DataStoreManager)
					end
				end)
			elseif entry.name == "MissionService" then
				initOk, initErr = pcall(function()
					mod.Init(
						services.MatchService,
						services.MapService
					)
				end)
			elseif entry.name == "CycleService" then
				initOk, initErr = pcall(function()
					mod.Init(
						services.MatchService
					)
				end)
			elseif entry.name == "MissionEvents" then
				initOk, initErr = pcall(function()
					mod.Init(
						services.MissionService,
						playerActionEvent :: RemoteEvent
					)
				end)
			elseif entry.name == "AudioService" then
				initOk, initErr = pcall(function()
					mod.Init(
						gameStateEvent :: RemoteEvent,
						services.MatchService
					)
				end)
			else
				initOk, initErr = pcall(function()
					mod.Init()
				end)
			end

			if not initOk then
				warn("[TheBrokenBox] GameManager: ERRO em " .. entry.name .. ".Init(): " .. tostring(initErr))
			end
		end

		print("[TheBrokenBox] GameManager: " .. entry.name .. " carregado.")
	end

	print("[TheBrokenBox] GameManager: initServices() — concluido.")
end

-- ============================================================
-- Fase 2: Conexao de sinais entre servicos (wiring)
-- ============================================================
local function wireServiceSignals()
	print("[TheBrokenBox] GameManager: wireServiceSignals() — conectando sinais...")

	local MatchService = services.MatchService
	local StaminaService = services.StaminaService
	local HitboxService = services.HitboxService
	local SurvivorService = services.SurvivorService
	local HunterService = services.HunterService
	local HunterEvents = services.HunterEvents
	local MapService = services.MapService

	-- Injecao de dependencias do HunterService
	if HunterService and HunterService.injectDependencies then
		HunterService.injectDependencies(
			MatchService,
			HitboxService,
			StaminaService
		)
		print("[TheBrokenBox] GameManager: HunterService dependencias injetadas.")
	end

	-- Injecao de dependencias do SpawnService
	local SpawnService = services.SpawnService
	if SpawnService and SpawnService.injectDependencies then
		SpawnService.injectDependencies(
			MatchService,
			MapService
		)
		print("[TheBrokenBox] GameManager: SpawnService dependencias injetadas.")
	end

	-- Injecao de dependencias do HunterEvents
	if HunterEvents and HunterEvents.injectDependencies then
		HunterEvents.injectDependencies(
			HunterService,
			MatchService
		)
	end

	-- MatchService sinaliza mudanca de estado da partida
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState: string)
			print("[TheBrokenBox] Estado da partida: " .. newState)
		end)
	end

	-- MatchService sinaliza jogador morto -> notificar servicos
	if MatchService and MatchService.playerDied then
		MatchService.playerDied:Connect(function(player: Player)
			if StaminaService and StaminaService.onPlayerDied then
				StaminaService.onPlayerDied(player)
			end
			if HitboxService and HitboxService.onPlayerDied then
				HitboxService.onPlayerDied(player)
			end
			-- SurvivorService conecta internamente via Init()
		end)
	end

	-- HitboxService sinaliza dano aplicado -> notificar MatchService
	if HitboxService and HitboxService.damageApplied then
		HitboxService.damageApplied:Connect(function(target: Player, damage: number, source: Player?)
			if MatchService and MatchService.onDamageApplied then
				MatchService.onDamageApplied(target, damage, source)
			end
		end)
	end

	-- SurvivorService sinaliza dano em Sobrevivente -> notificar HUD
	if SurvivorService and SurvivorService.survivorDamaged then
		SurvivorService.survivorDamaged:Connect(function(player: Player, damage: number, source: Player?)
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

	-- SurvivorService sinaliza cura em Sobrevivente -> notificar HUD
	if SurvivorService and SurvivorService.survivorHealed then
		SurvivorService.survivorHealed:Connect(function(player: Player, amount: number, healer: Player?)
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

	-- SurvivorService sinaliza morte de Sobrevivente -> notificar todos
	if SurvivorService and SurvivorService.survivorDied then
		SurvivorService.survivorDied:Connect(function(player: Player)
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

	-- ============================================================
	-- Wiring do HunterService
	-- ============================================================

	-- HunterService: quando o Cacador e atacado, ganha Furia
	if HunterService and MatchService and MatchService.damageTaken then
		MatchService.damageTaken:Connect(function(target: Player, damage: number, source: Player?)
			if HunterService.isHunter(target) then
				HunterService.onHunterAttacked(source)
			end
		end)
	end

	-- MatchService: quando papeis sao atribuidos, notificar HunterService
	if HunterService and MatchService and MatchService.roleAssigned then
		MatchService.roleAssigned:Connect(function(player: Player, role: string)
			if role == "Hunter" then
				HunterService.setHunter(player)
			end
		end)
	end

	-- MatchService: quando jogador morre, limpar estado do Hunter
	if HunterService and MatchService and MatchService.playerDied then
		MatchService.playerDied:Connect(function(player: Player)
			if HunterService.isHunter(player) then
				HunterService.onHunterDied()
			end
		end)
	end

	-- ============================================================
	-- Wiring do LobbyService (E4)
	-- ============================================================
	local LobbyService = services.LobbyService

	-- LobbyService: quando um personagem e selecionado -> atribuir no MatchService
	if LobbyService and LobbyService.characterSelected then
		LobbyService.characterSelected:Connect(function(player: Player, characterClass: string, role: string?)
			if role == "Hunter" and MatchService then
				MatchService.assignHunter(player)
			elseif role == "Survivor" and MatchService then
				MatchService.assignSurvivor(player, characterClass)
			end
		end)
		print("[TheBrokenBox] GameManager: LobbyService.characterSelected -> MatchService conectado.")
	end

	-- LobbyService: quando o lobby fica pronto -> transicao para Selecting
	if LobbyService and LobbyService.lobbyReady then
		LobbyService.lobbyReady:Connect(function()
			if MatchService then
				MatchService.setMatchState("Selecting")
			end
		end)
		print("[TheBrokenBox] GameManager: LobbyService.lobbyReady -> MatchService.setMatchState conectado.")
	end

	-- MatchService: quando estado muda -> notificar LobbyService
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState: string)
			if newState == "Ended" and LobbyService then
				LobbyService.resetToGathering()
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.matchStateChanged -> LobbyService conectado.")
	end

	-- MapService: gerar missoes quando a partida iniciar (Playing)
	if MatchService and MatchService.matchStateChanged and MapService then
		MatchService.matchStateChanged:Connect(function(newState: string)
			if newState == "Playing" then
				MapService.generateMissions()
				MapService.resetSpawnIndex()
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.matchStateChanged -> MapService (missoes) conectado.")
	end

	-- MapService: fornecer spawn points quando papeis sao atribuidos
	if MatchService and MatchService.roleAssigned and MapService then
		MatchService.roleAssigned:Connect(function(player: Player, role: string)
			if role == "Hunter" then
				-- Spawn do Cacador (posicao fixa)
				local spawnPos = MapService.getHunterSpawn()
				-- O spawn real e feito pelo MatchService/HunterService
				print("[TheBrokenBox] GameManager: Spawn do Hunter em " .. tostring(spawnPos))
			elseif role == "Survivor" then
				-- Spawn do Sobrevivente (aleatorio)
				local spawnPos = MapService.getRandomSurvivorSpawn()
				print("[TheBrokenBox] GameManager: Spawn do Survivor " .. player.Name .. " em " .. tostring(spawnPos))
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.roleAssigned -> MapService (spawns) conectado.")
	end

	-- ============================================================
	-- Wiring do EscapeService (E6)
	-- ============================================================
	local EscapeService = services.EscapeService
	local MissionService = services.MissionService
	local ShopService = services.ShopService
	local CycleService = services.CycleService

	-- Injecao de dependencias do EscapeService
	if EscapeService and EscapeService.injectDependencies then
		EscapeService.injectDependencies(
			MatchService,
			MapService,
			MissionService,  -- Pode ser nil (wire guard interno)
			ShopService      -- Pode ser nil (wire guard interno)
		)
		print("[TheBrokenBox] GameManager: EscapeService dependencias injetadas.")
	end

	-- CycleService.cycleZero -> EscapeService.startEscape()
	if CycleService and CycleService.cycleZero and EscapeService then
		CycleService.cycleZero:Connect(function()
			print("[TheBrokenBox] GameManager: cycleZero recebido -> iniciando EscapeService")
			EscapeService.startEscape()
		end)
		print("[TheBrokenBox] GameManager: CycleService.cycleZero -> EscapeService.startEscape() conectado.")
	end

	-- EscapeService.playerEscaped -> ShopService (+40 coins)
	if EscapeService and EscapeService.playerEscaped then
		EscapeService.playerEscaped:Connect(function(player: Player, gateId: string)
			if ShopService and ShopService.addCoins then
				ShopService.addCoins(player, GameConstants.Economy.COIN_FUGA)
				print("[TheBrokenBox] GameManager: " .. player.Name .. " escapou — +" .. GameConstants.Economy.COIN_FUGA .. " moedas")
			end
		end)
		print("[TheBrokenBox] GameManager: EscapeService.playerEscaped -> ShopService conectado.")
	end

	-- EscapeService.escapeEnded -> MatchService (resolver vitoria)
	if EscapeService and EscapeService.escapeEnded then
		EscapeService.escapeEnded:Connect(function(escapedCount: number, totalAtStart: number)
			print("[TheBrokenBox] GameManager: escapeEnded — " .. escapedCount .. " escaparam de " .. totalAtStart)

			if MatchService then
				-- Resolver vitoria
				local winner: string
				local result: string

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

	-- ============================================================
	-- Wiring do DataStoreManager + ShopService (E7)
	-- ============================================================
	local DataStoreManager = services.DataStoreManager

	-- Inject DataStoreManager into ShopService (if not done in Init)
	if ShopService and DataStoreManager and ShopService.injectDataStoreManager then
		ShopService.injectDataStoreManager(DataStoreManager)
		print("[TheBrokenBox] GameManager: DataStoreManager injetado no ShopService.")
	end

	-- MissionService.missionCompleted -> ShopService (+15 coins)
	if MissionService and MissionService.missionCompleted then
		MissionService.missionCompleted:Connect(function(player: Player, missionId: string)
			if ShopService and ShopService.addCoins then
				local GameConstants = require(ReplicatedStorage.GameConstants)
				ShopService.addCoins(player, GameConstants.Economy.COIN_MISSAO)
				print("[TheBrokenBox] GameManager: " .. player.Name .. " completou missao " .. missionId .. " — +" .. GameConstants.Economy.COIN_MISSAO .. " moedas")
			end
		end)
		print("[TheBrokenBox] GameManager: MissionService.missionCompleted -> ShopService (+15 coins) conectado.")
	end

	-- ShopService.characterUnlocked -> notificar LobbyService + UISync
	if ShopService and ShopService.characterUnlocked then
		ShopService.characterUnlocked:Connect(function(player: Player, characterClass: string)
			-- Notificar LobbyService para atualizar lista de personagens disponiveis
			if LobbyService and LobbyService.onCharacterUnlocked then
				LobbyService.onCharacterUnlocked(player, characterClass)
			end

			-- Notificar cliente via UISyncEvent
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

	-- ShopService.coinsUpdated -> notificar cliente via UISyncEvent
	if ShopService and ShopService.coinsUpdated then
		ShopService.coinsUpdated:Connect(function(player: Player, newTotal: number)
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
			playerActionEvent.OnServerEvent:Connect(function(player: Player, message: { type: string, data: {any} })
				if message and message.type == "BUY_UNLOCK" then
					local data = message.data or {}
					local characterClass = data.characterClass
					if characterClass then
						print("[TheBrokenBox] GameManager: BUY_UNLOCK recebido de " .. player.Name .. " — " .. characterClass)
						ShopService.buyCharacter(player, characterClass)
					end
				end
			end)
			print("[TheBrokenBox] GameManager: BUY_UNLOCK handler conectado (PlayerActionEvent -> ShopService).")
		end

		-- Handler: RETURN_TO_LOBBY + SPECTATE_NEXT via PlayerActionEvent
		if playerActionEvent and LobbyService then
			playerActionEvent.OnServerEvent:Connect(function(player: Player, message: { type: string, data: {any} })
				if message and message.type == "RETURN_TO_LOBBY" then
					print("[TheBrokenBox] GameManager: RETURN_TO_LOBBY recebido de " .. player.Name)
					if LobbyService.returnPlayerToLobby then
						LobbyService.returnPlayerToLobby(player)
					end
				elseif message and message.type == "SPECTATE_NEXT" then
					print("[TheBrokenBox] GameManager: SPECTATE_NEXT recebido de " .. player.Name .. " (handler pendente)")
				end
			end)
			print("[TheBrokenBox] GameManager: RETURN_TO_LOBBY + SPECTATE_NEXT handlers conectados (PlayerActionEvent).")
		end

	-- ============================================================
	-- Wiring do MissionService + CycleService (E5)
	-- ============================================================

	-- MissionService: missionCompleted -> CycleService (-10s)
	if MissionService and MissionService.missionCompleted and CycleService then
		MissionService.missionCompleted:Connect(function(player: Player, missionId: string, missionType: string)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onMissionCompleted()
				print("[TheBrokenBox] GameManager: missionCompleted -> CycleService (-10s) — " .. missionId)
			end
		end)
		print("[TheBrokenBox] GameManager: MissionService.missionCompleted -> CycleService (-10s) conectado.")
	end

	-- MatchService: playerDied -> CycleService (+20s)
	if MatchService and MatchService.playerDied and CycleService then
		MatchService.playerDied:Connect(function(player: Player)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onPlayerDied(player)
				print("[TheBrokenBox] GameManager: playerDied -> CycleService (+20s se Survivor) — " .. player.Name)
			end
		end)
		print("[TheBrokenBox] GameManager: MatchService.playerDied -> CycleService (+20s) conectado.")
	end

	-- HunterService: rageActivated -> CycleService (pause)
	if HunterService and HunterService.rageActivated and CycleService then
		HunterService.rageActivated:Connect(function(hunter: Player)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onRageActivated()
				print("[TheBrokenBox] GameManager: rageActivated -> CycleService (pause)")
			end
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageActivated -> CycleService (pause) conectado.")
	end

	-- HunterService: rageDeactivated -> CycleService (resume)
	if HunterService and HunterService.rageDeactivated and CycleService then
		HunterService.rageDeactivated:Connect(function(hunter: Player, remainingFury: number)
			if CycleService.isActive and CycleService.isActive() then
				CycleService.onRageDeactivated()
				print("[TheBrokenBox] GameManager: rageDeactivated -> CycleService (resume)")
			end
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageDeactivated -> CycleService (resume) conectado.")
	end

	-- MatchService: estado Playing -> MissionService.initializeMissions() + CycleService.startCycle() + SpawnService.teleportAllPlayers()
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState: string)
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

	-- CycleService.cycleTick -> UISyncEvent (cycleTime para HUDs)
	if CycleService and CycleService.cycleTick and uiSyncEvent then
		CycleService.cycleTick:Connect(function(remainingTime: number)
			local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
			RemoteEventUtils.fireAll(
				uiSyncEvent,
				"HUD_UPDATE",
				{ cycleTime = remainingTime }
			)
		end)
		print("[TheBrokenBox] GameManager: CycleService.cycleTick -> UISyncEvent (cycleTime) conectado.")
	end

	-- ============================================================
	-- Wiring do AudioService (E8)
	-- ============================================================
	local AudioService = services.AudioService

	-- SurvivorService.survivorDamaged -> AudioService (heartbeat SFX)
	if SurvivorService and SurvivorService.survivorDamaged and AudioService then
		SurvivorService.survivorDamaged:Connect(function(player: Player, damage: number, source: Player?)
			AudioService.onSurvivorDamaged(player, damage, source)
		end)
		print("[TheBrokenBox] GameManager: SurvivorService.survivorDamaged -> AudioService (heartbeat) conectado.")
	end

	-- HunterService.rageActivated -> AudioService (Perseguição)
	if HunterService and HunterService.rageActivated and AudioService then
		HunterService.rageActivated:Connect(function(hunter: Player)
			AudioService.onRageActivated(hunter)
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageActivated -> AudioService conectado.")
	end

	-- HunterService.rageDeactivated -> AudioService (retorna camada)
	if HunterService and HunterService.rageDeactivated and AudioService then
		HunterService.rageDeactivated:Connect(function(hunter: Player, remainingFury: number)
			AudioService.onRageDeactivated(hunter, remainingFury)
		end)
		print("[TheBrokenBox] GameManager: HunterService.rageDeactivated -> AudioService conectado.")
	end

	-- EscapeService.escapeStarted -> AudioService (climax)
	if EscapeService and EscapeService.escapeStarted and AudioService then
		EscapeService.escapeStarted:Connect(function()
			AudioService.onEscapeStarted()
		end)
		print("[TheBrokenBox] GameManager: EscapeService.escapeStarted -> AudioService conectado.")
	end

	-- MissionService.missionCompleted -> AudioService (SFX)
	if MissionService and MissionService.missionCompleted and AudioService then
		MissionService.missionCompleted:Connect(function(player: Player, missionId: string, missionType: string)
			if AudioService.onMissionCompleted then
				AudioService.onMissionCompleted(player, missionId, missionType)
			end
		end)
		print("[TheBrokenBox] GameManager: MissionService.missionCompleted -> AudioService (SFX) conectado.")
	end

	-- MatchService.playerDied -> AudioService (SFX)
	if MatchService and MatchService.playerDied and AudioService then
		MatchService.playerDied:Connect(function(player: Player)
			AudioService.onPlayerDied(player)
		end)
		print("[TheBrokenBox] GameManager: MatchService.playerDied -> AudioService (SFX) conectado.")
	end

	-- CycleService.cycleTick -> AudioService (ajustar camada por proximidade)
	if CycleService and CycleService.cycleTick and AudioService then
		CycleService.cycleTick:Connect(function(remainingTime: number)
			AudioService.onCycleTick(remainingTime)
		end)
		print("[TheBrokenBox] GameManager: CycleService.cycleTick -> AudioService conectado.")
	end

	print("[TheBrokenBox] GameManager: wireServiceSignals() — concluido.")
end

-- ============================================================
-- Fase 3: Start assincrono de todos os servicos
-- ============================================================
local function startServices()
	print("[TheBrokenBox] GameManager: startServices() — iniciando listeners...")

	for _, entry in ipairs(serviceModules) do
		local mod = entry.module
		if mod and mod.Start then
			local startOk, startErr = pcall(function()
				mod.Start()
			end)
			if not startOk then
				warn("[TheBrokenBox] GameManager: ERRO em " .. entry.name .. ".Start(): " .. tostring(startErr))
			end
		end
	end

	print("[TheBrokenBox] GameManager: startServices() — concluido.")
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
