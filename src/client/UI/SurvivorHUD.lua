--!strict
--[[
  SurvivorHUD.lua
  Interface do Sobrevivente (client-side).
  Exibe HP, stamina, HP dos aliados, cooldowns e timer do Ciclo.
  Escuta UISyncEvent para atualizacoes.

  Referencias: GameConstants.Survivors, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local GameConstants = require(ReplicatedStorage.GameConstants)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local SurvivorHUD = {}

-- ============================================================
-- Referencias de UI
-- ============================================================
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil

-- Elementos
local hpBar: Frame? = nil
local hpLabel: TextLabel? = nil
local staminaBar: Frame? = nil
local staminaLabel: TextLabel? = nil
local cycleLabel: TextLabel? = nil
local allyHPFrame: Frame? = nil
local cooldownFrame: Frame? = nil
local heartbeatIndicator: Frame? = nil  -- Indicador visual de batimento (E8)

-- Estado local
local _currentHP = 100
local _maxHP = 100
local _currentStamina = 100
local _maxStamina = 100
local _cycleTime = 240
local _cooldowns: { [string]: { endTime: number, duration: number } } = {}
local _allyHPLabels: { [number]: TextLabel } = {}  -- userId -> label

-- ============================================================
-- Criacao da UI
-- ============================================================

local function createElement(className: string, parent: Instance, props: { [string]: any }): Instance
	local element = Instance.new(className)
	for key, value in props do
		element[key] = value
	end
	element.Parent = parent
	return element
end

--[[
  Cria a ScreenGui completa do HUD do Sobrevivente.
]]
local function createHUD(): ()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SurvivorHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Frame principal (canto superior esquerdo)
	mainFrame = createElement("Frame", screenGui, {
		Name = "MainFrame",
		Size = UDim2.new(0, 280, 0, 200),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 5/10,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
	})

	-- Layout: UIListLayout
	local layout = createElement("UIListLayout", mainFrame, {
		Name = "Layout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})

	-- Padding interno
	local padding = createElement("UIPadding", mainFrame, {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})

	-- === HP Bar ===
	local hpContainer = createElement("Frame", mainFrame, {
		Name = "HPContainer",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})

	hpLabel = createElement("TextLabel", hpContainer, {
		Name = "HPLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "HP: 100/100",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		Font = Enum.Font.SourceSansBold,
		TextStrokeTransparency = 8/10,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})

	hpBar = createElement("Frame", hpContainer, {
		Name = "HPBar",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(200, 50, 50),
		BorderSizePixel = 0,
	})

	local hpBg = createElement("Frame", hpContainer, {
		Name = "HPBg",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(60, 20, 20),
		BorderSizePixel = 0,
	})
	hpBg.ZIndex = 0
	hpBar.ZIndex = 1

	-- === Stamina Bar ===
	local stamContainer = createElement("Frame", mainFrame, {
		Name = "StaminaContainer",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	})

	staminaLabel = createElement("TextLabel", stamContainer, {
		Name = "StaminaLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "Stamina: 100/100",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 12,
		Font = Enum.Font.SourceSans,
		TextStrokeTransparency = 8/10,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	})

	staminaBar = createElement("Frame", stamContainer, {
		Name = "StaminaBar",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(50, 150, 200),
		BorderSizePixel = 0,
		ZIndex = 1,
	})

	local stamBg = createElement("Frame", stamContainer, {
		Name = "StaminaBg",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(20, 40, 60),
		BorderSizePixel = 0,
		ZIndex = 0,
	})

	-- === Ciclo Timer ===
	cycleLabel = createElement("TextLabel", mainFrame, {
		Name = "CycleLabel",
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Ciclo: 4:00",
		TextColor3 = Color3.fromRGB(255, 200, 100),
		TextSize = 14,
		Font = Enum.Font.SourceSansBold,
		TextStrokeTransparency = 8/10,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
	})

	-- === Indicador de Batimento Cardiaco (E8) ===
	-- Pulso visual que aparece quando o Cacador esta perto (< 40 studs)
	heartbeatIndicator = createElement("Frame", mainFrame, {
		Name = "HeartbeatIndicator",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	})

	local heartIcon = createElement("TextLabel", heartbeatIndicator, {
		Name = "HeartIcon",
		Size = UDim2.new(0, 80, 1, 0),
		Text = "♥",
		TextColor3 = Color3.fromRGB(255, 60, 60),
		TextSize = 18,
		Font = Enum.Font.SourceSansBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local heartLabel = createElement("TextLabel", heartbeatIndicator, {
		Name = "HeartLabel",
		Size = UDim2.new(1, -84, 1, 0),
		Position = UDim2.new(0, 84, 0, 0),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 100, 100),
		TextSize = 12,
		Font = Enum.Font.SourceSans,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Inicia invisivel
	heartbeatIndicator.Visible = false

	-- === Cooldowns ===
	cooldownFrame = createElement("Frame", mainFrame, {
		Name = "Cooldowns",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
	})

	local cdLayout = createElement("UIListLayout", cooldownFrame, {
		Name = "CDLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})

	-- === Aliados HP (lado direito da tela) ===
	allyHPFrame = createElement("Frame", screenGui, {
		Name = "AllyHP",
		Size = UDim2.new(0, 200, 0, 160),
		Position = UDim2.new(1, -210, 0, 10),
		BackgroundTransparency = 4/10,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
	})

	local allyTitle = createElement("TextLabel", allyHPFrame, {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Aliados",
		TextColor3 = Color3.fromRGB(200, 200, 200),
		TextSize = 12,
		Font = Enum.Font.SourceSansBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local allyLayout = createElement("UIListLayout", allyHPFrame, {
		Name = "AllyLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	})

	print("[TheBrokenBox] SurvivorHUD: UI criada.")
end

-- ============================================================
-- Atualizacao da UI
-- ============================================================

--[[
  Atualiza a barra de HP.
]]
local function updateHP(hp: number, maxHp: number): ()
	_currentHP = hp
	_maxHP = maxHp

	if hpBar then
		local ratio = math.clamp(hp / maxHp, 0, 1)
		hpBar.Size = UDim2.new(ratio, 0, 1, 0)

		-- Cor muda baseado no HP
		if ratio > 0.6 then
			hpBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		elseif ratio > 0.3 then
			hpBar.BackgroundColor3 = Color3.fromRGB(220, 150, 30)
		else
			hpBar.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
		end
	end

	if hpLabel then
		hpLabel.Text = string.format("HP: %d/%d", hp, maxHp)
	end
end

--[[
  Atualiza a barra de Stamina.
]]
local function updateStamina(stamina: number, maxStamina: number): ()
	_currentStamina = stamina
	_maxStamina = maxStamina

	if staminaBar then
		local ratio = math.clamp(stamina / maxStamina, 0, 1)
		staminaBar.Size = UDim2.new(ratio, 0, 1, 0)
	end

	if staminaLabel then
		staminaLabel.Text = string.format("Stamina: %d/%d", stamina, maxStamina)
	end
end

--[[
  Atualiza o timer do Ciclo.
]]
local function updateCycle(seconds: number): ()
	_cycleTime = seconds

	if cycleLabel then
		local mins = math.floor(seconds / 60)
		local secs = math.floor(seconds % 60)
		cycleLabel.Text = string.format("Ciclo: %d:%02d", mins, secs)

		-- Pisca quando faltam menos de 30s
		if seconds < 30 then
			cycleLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		end
	end
end

--[[
  Atualiza os indicadores de cooldown.
]]
local function updateCooldowns(): ()
	if not cooldownFrame then
		return
	end

	-- Limpar labels antigos
	for _, child in ipairs(cooldownFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local now = os.clock()
	local hasActive = false

	for name, cd in pairs(_cooldowns) do
		local remaining = cd.endTime - now
		if remaining > 0 then
			hasActive = true
			local label = createElement("TextLabel", cooldownFrame, {
				Name = name,
				Size = UDim2.new(1, 0, 0, 16),
				Text = string.format("%s: %.1fs", name, remaining),
				TextColor3 = Color3.fromRGB(255, 150, 100),
				TextSize = 11,
				Font = Enum.Font.SourceSans,
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
	end

	if not hasActive then
		createElement("TextLabel", cooldownFrame, {
			Name = "NoCD",
			Size = UDim2.new(1, 0, 0, 16),
			Text = "Pronto",
			TextColor3 = Color3.fromRGB(100, 200, 100),
			TextSize = 11,
			Font = Enum.Font.SourceSans,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

--[[
  Atualiza a lista de HP dos aliados.
  Recebe uma tabela { [userId] = { name, hp, maxHp, class } }
]]
local function updateAllyHP(allyData: { [number]: { name: string, hp: number, maxHp: number, class: string } }): ()
	if not allyHPFrame then
		return
	end

	-- Limpar labels antigos (mantendo o titulo e layout)
	local toRemove = {}
	for _, child in ipairs(allyHPFrame:GetChildren()) do
		if child:IsA("TextLabel") and child.Name ~= "Title" then
			table.insert(toRemove, child)
		end
	end
	for _, child in toRemove do
		child:Destroy()
	end

	-- Criar labels para cada aliado
	local order = 1
	for userId, data in pairs(allyData) do
		local ratio = math.clamp(data.hp / data.maxHp, 0, 1)
		local color = ratio > 0.5 and Color3.fromRGB(100, 200, 100)
			or ratio > 0.25 and Color3.fromRGB(220, 180, 50)
			or Color3.fromRGB(220, 50, 50)

		local label = createElement("TextLabel", allyHPFrame, {
			Name = "Ally_" .. tostring(userId),
			Size = UDim2.new(1, 0, 0, 16),
			Text = string.format("[%s] %s: %d/%d", data.class, data.name, data.hp, data.maxHp),
			TextColor3 = color,
			TextSize = 11,
			Font = Enum.Font.SourceSans,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		})
		order = order + 1
	end
end

-- ============================================================
-- Listeners de UISyncEvent
-- ============================================================

--[[
  Atualiza o indicador visual de batimento cardiaco.
  Mostra um ♥ pulsante quando o Cacador esta a < 40 studs.
  Intensidade (tamanho e cor) aumenta com a proximidade.
]]
local function updateHeartbeatPulse(proximity: number): ()
	if not heartbeatIndicator then
		return
	end

	local heartbeatRadius = GameConstants.Audio.HEARTBEAT_RADIUS  -- 40 studs

	if proximity >= heartbeatRadius or proximity <= 0 then
		heartbeatIndicator.Visible = false
		return
	end

	heartbeatIndicator.Visible = true

	-- Encontrar o icone de coracao e o label
	local heartIcon: TextLabel? = nil
	local heartLabel: TextLabel? = nil
	for _, child in ipairs(heartbeatIndicator:GetChildren()) do
		if child:IsA("TextLabel") then
			if child.Name == "HeartIcon" then
				heartIcon = child :: TextLabel
			elseif child.Name == "HeartLabel" then
				heartLabel = child :: TextLabel
			end
		end
	end

	-- Calcular intensidade baseada na proximidade
	local factor = 1 - math.clamp(proximity / heartbeatRadius, 0, 1)

	-- Ajustar tamanho do icone (pulso)
	if heartIcon then
		local baseSize = 18
		local pulseSize = baseSize + (baseSize * factor * 0.8)  -- 18 a 32.4
		heartIcon.TextSize = math.floor(pulseSize)

		-- Cor: vermelho fraco -> vermelho intenso
		local red = 100 + (155 * factor)  -- 100 a 255
		heartIcon.TextColor3 = Color3.fromRGB(math.floor(red), 40, 40)
	end

	-- Texto de distancia
	if heartLabel then
		local distText = string.format("%.0f studs", proximity)
		if proximity < 10 then
			distText = "MUITO PERTO!"
		elseif proximity < 20 then
			distText = "PERTO: " .. distText
		end
		heartLabel.Text = distText
	end
end

--[[
  Processa mensagens do UISyncEvent.
]]
local function onUISyncMessage(message: {any}): ()
	local msgType = message.type
	local data = message.data

	if msgType == "HUD_UPDATE" then
		-- Atualizacao por frame (~60Hz)
		if data.hp then
			local maxHp = data.maxHp or _maxHP
			updateHP(data.hp, maxHp)
		end
		if data.stamina then
			local maxStamina = data.maxStamina or _maxStamina
			updateStamina(data.stamina, maxStamina)
		end
		if data.cycleTime then
			updateCycle(data.cycleTime)
		end
		if data.allyHP then
			updateAllyHP(data.allyHP)
		end

	elseif msgType == "COOLDOWN_START" then
		local abilityName = data.ability
		local duration = data.duration
		if abilityName and duration then
			_cooldowns[abilityName] = {
				endTime = os.clock() + duration,
				duration = duration,
			}
			print("[TheBrokenBox] SurvivorHUD: Cooldown " .. abilityName .. " " .. duration .. "s")
		end

	elseif msgType == "COOLDOWN_END" then
		local abilityName = data.ability
		if abilityName then
			_cooldowns[abilityName] = nil
		end

	elseif msgType == "LMS_ACTIVATED" then
		-- Exibir indicacao de LMS
		print("[TheBrokenBox] SurvivorHUD: LMS ativado! " .. tostring(data.class) .. " - " .. tostring(data.bonus))

	elseif msgType == "AUDIO_HEARTBEAT" then
		-- Atualizar indicador visual de batimento cardiaco (E8)
		local proximity = data and data.proximity or math.huge
		updateHeartbeatPulse(proximity)
	end
end

-- ============================================================
-- Init/Start
-- ============================================================

--[[
  Init(): setup sincrono da UI.
]]
function SurvivorHUD.Init(): ()
	print("[TheBrokenBox] SurvivorHUD.Init()")
	createHUD()
end

--[[
  Start(): registro de listeners e loop de atualizacao.
]]
function SurvivorHUD.Start(): ()
	print("[TheBrokenBox] SurvivorHUD.Start() - registrando listeners...")

	-- Encontrar o UISyncEvent em ReplicatedStorage
	local replicatedStorage = ReplicatedStorage
	local eventsFolder = replicatedStorage:WaitForChild("Events")
	if not eventsFolder then
		warn("[TheBrokenBox] SurvivorHUD: Pasta Events nao encontrada em ReplicatedStorage")
		return
	end

	-- Buscar o RemoteEvent (nao o ModuleScript)
	local uiSyncEvent: RemoteEvent? = nil
	for _, child in ipairs(eventsFolder:GetChildren()) do
		if child:IsA("RemoteEvent") and child.Name == "UISyncEvent" then
			uiSyncEvent = child :: RemoteEvent
			break
		end
	end

	if not uiSyncEvent then
		warn("[TheBrokenBox] SurvivorHUD: RemoteEvent UISyncEvent nao encontrado")
		return
	end

	-- Escutar mensagens do servidor
	uiSyncEvent.OnClientEvent:Connect(onUISyncMessage)

	-- Tambem escutar GameStateEvent para batimentos cardiacos (E8)
	local gameStateEvent: RemoteEvent? = nil
	for _, child in ipairs(eventsFolder:GetChildren()) do
		if child:IsA("RemoteEvent") and child.Name == "GameStateEvent" then
			gameStateEvent = child :: RemoteEvent
			break
		end
	end
	if gameStateEvent then
		gameStateEvent.OnClientEvent:Connect(onUISyncMessage)
		print("[TheBrokenBox] SurvivorHUD: Listener do GameStateEvent (heartbeat) conectado.")
	end

	-- Loop de atualizacao dos cooldowns (1x/s)
	task.spawn(function()
		while screenGui and screenGui.Parent do
			updateCooldowns()
			task.wait(0.5)
		end
	end)

	print("[TheBrokenBox] SurvivorHUD.Start() concluido.")
end

return SurvivorHUD
