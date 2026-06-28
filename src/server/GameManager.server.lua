--!strict
--[[
  GameManager.server.lua
  Ponto de entrada do servidor. Orquestra a inicializacao
  de todos os servicos na ordem correta (Init/Start pattern).

  Fases:
    1. initServices()  — require + Init() sincrono
    2. wireServiceSignals() — conectar sinais entre servicos
    3. startServices()  — Start() assincrono (listeners, Heartbeat)

  Referencias: architecture.md 4. Padrao Init/Start
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Cache de servicos
local services = {}

--[[
  Lista de servicos na ordem de inicializacao.
  Ordem importa: MatchService primeiro (tracking de jogadores),
  depois servicos dependentes.
]]
local serviceModules = {
	{ name = "MatchService",   module = nil },
	{ name = "StaminaService", module = nil },
	{ name = "HitboxService",  module = nil },
}

-- ============================================================
-- Fase 1: Init sincrono de todos os servicos
-- ============================================================
local function initServices()
	print("[TheBrokenBox] GameManager: initServices() — iniciando...")

	for _, entry in ipairs(serviceModules) do
		local success, mod = pcall(function()
			return require(script.Services[entry.name])
		end)

		if not success then
			warn("[TheBrokenBox] GameManager: ERRO ao carregar " .. entry.name .. ": " .. tostring(mod))
			continue
		end

		entry.module = mod
		services[entry.name] = mod

		if mod.Init then
			local initOk, initErr = pcall(function()
				mod.Init()
			end)
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

	-- MatchService sinaliza mudanca de estado da partida
	if MatchService and MatchService.matchStateChanged then
		MatchService.matchStateChanged:Connect(function(newState: string)
			print("[TheBrokenBox] Estado da partida: " .. newState)
		end)
	end

	-- MatchService sinaliza jogador morto -> notificar Stamina e Hitbox
	if MatchService and MatchService.playerDied then
		MatchService.playerDied:Connect(function(player: Player)
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
		HitboxService.damageApplied:Connect(function(target: Player, damage: number, source: Player?)
			if MatchService and MatchService.onDamageApplied then
				MatchService.onDamageApplied(target, damage, source)
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
-- Garantir que pastas existam (Roblox cria automaticamente com os scripts)
-- mas podemos logar para debug
print("[TheBrokenBox] ========================================")
print("[TheBrokenBox] GameManager iniciando...")
print("[TheBrokenBox] ========================================")

initServices()
wireServiceSignals()
startServices()

print("[TheBrokenBox] GameManager pronto. Aguardando jogadores...")
