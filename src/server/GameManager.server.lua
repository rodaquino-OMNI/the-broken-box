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
	{ name = "HunterEvents",     module = nil, isEvent = true },
	{ name = "SurvivorEvents",   module = nil, isEvent = true },
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

	-- Injecao de dependencias do HunterService
	if HunterService and HunterService.injectDependencies then
		HunterService.injectDependencies(
			MatchService,
			HitboxService,
			StaminaService
		)
		print("[TheBrokenBox] GameManager: HunterService dependencias injetadas.")
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
