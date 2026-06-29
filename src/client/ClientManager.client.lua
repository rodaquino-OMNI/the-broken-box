--!strict
--[[
  ClientManager.client.lua
  Ponto de entrada do cliente (LocalScript).
  Inicializa todos os modulos do cliente na ordem correta:
    InputManager, CameraManager, (futuro: UIManager, AudioManager)

  Padrao: cada modulo tem Init() e Start()
  Require paths: usar script.Parent para modulos irmaos
    (convencao Rojo para LocalScripts)

  Referencias: architecture.md, workflow-roblox.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Modulos do cliente (WaitForChild para seguranca com Rojo)
-- ============================================================
local function safeRequire(parent: Instance, ...: string): any
	local current = parent
	for _, name in ipairs({...}) do
		current = current:WaitForChild(name)
	end
	return require(current)
end

local InputManager = safeRequire(script.Parent, "Input", "InputManager")
local CameraManager = safeRequire(script.Parent, "Camera", "CameraManager")
local SurvivorHUD = safeRequire(script.Parent, "UI", "SurvivorHUD")
local KillerHUD = safeRequire(script.Parent, "UI", "KillerHUD")
local MissionUI = safeRequire(script.Parent, "UI", "MissionUI")
local CharacterSelectUI = safeRequire(script.Parent, "UI", "CharacterSelectUI")
local GameOverUI = safeRequire(script.Parent, "UI", "GameOverUI")
local ShopUI = safeRequire(script.Parent, "UI", "ShopUI")
local AudioManager = safeRequire(script.Parent, "Audio", "AudioManager")

local clientModules = {
	{ name = "InputManager",      module = InputManager },
	{ name = "CameraManager",     module = CameraManager },
	{ name = "SurvivorHUD",       module = SurvivorHUD },
	{ name = "KillerHUD",         module = KillerHUD },
	{ name = "MissionUI",         module = MissionUI },
	{ name = "CharacterSelectUI", module = CharacterSelectUI },
	{ name = "GameOverUI",        module = GameOverUI },
	{ name = "ShopUI",            module = ShopUI },
	{ name = "AudioManager",      module = AudioManager },
}

-- ============================================================
-- Fase 1: Init sincrono
-- ============================================================
local function initClientModules()
	print("[TheBrokenBox] ClientManager: initClientModules() — iniciando...")

	for _, entry in ipairs(clientModules) do
		local mod = entry.module
		if mod and mod.Init then
			local ok, err = pcall(mod.Init)
			if not ok then
				warn("[TheBrokenBox] ClientManager: ERRO em " .. entry.name .. ".Init(): " .. tostring(err))
			else
				print("[TheBrokenBox] ClientManager: " .. entry.name .. " inicializado.")
			end
		end
	end

	print("[TheBrokenBox] ClientManager: initClientModules() — concluido.")
end

-- ============================================================
-- Fase 2: Start
-- ============================================================
local function startClientModules()
	print("[TheBrokenBox] ClientManager: startClientModules() — iniciando...")

	for _, entry in ipairs(clientModules) do
		local mod = entry.module
		if mod and mod.Start then
			local ok, err = pcall(mod.Start)
			if not ok then
				warn("[TheBrokenBox] ClientManager: ERRO em " .. entry.name .. ".Start(): " .. tostring(err))
			else
				print("[TheBrokenBox] ClientManager: " .. entry.name .. " iniciado.")
			end
		end
	end

	print("[TheBrokenBox] ClientManager: startClientModules() — concluido.")
end

-- ============================================================
-- Execucao
-- ============================================================
print("[TheBrokenBox] ========================================")
print("[TheBrokenBox] ClientManager iniciando para " .. LocalPlayer.Name .. "...")
print("[TheBrokenBox] ========================================")

initClientModules()
startClientModules()

print("[TheBrokenBox] ClientManager pronto. Aguardando partida...")
