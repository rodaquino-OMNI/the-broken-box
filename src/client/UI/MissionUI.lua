--!strict
--[[
  MissionUI.lua
  Interface de missoes (client-side).
  Exibe o minigame conforme o tipo de missao:
    V1 Breaker  - 4 alavancas, clicar para virar a direita
    V2 Generator - 5 cabos, conectar na sequencia
    V3 Oil Machine - zona de ponteiro (Flee-style), clicar para travar

  Progresso enviado ao servidor via MISSION_PROGRESS.
  Cancelamento automatico ao detectar movimento.

  Usa script.Parent, IsA("RemoteEvent") para RemoteEvent lookup.
  Referencias: GDD M1, GameConstants.Missions
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local GameConstants = require(ReplicatedStorage.GameConstants)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local MissionUI = {}
MissionUI.Name = "MissionUI"

-- ============================================================
-- Referencias de RemoteEvent
-- ============================================================
local _playerActionEvent: RemoteEvent? = nil

-- ============================================================
-- Estado interno da UI de missao
-- ============================================================
local _screenGui: ScreenGui? = nil
local _activeMissionId: string? = nil
local _activeMissionType: string? = nil
local _currentProgress: number = 0
local _maxProgress: number = 1
local _missionActive: boolean = false

-- ============================================================
-- Criacao da UI
-- ============================================================

local function createElement(className: string, parent: Instance, props: { [string]: any }): Instance
	local element = Instance.new(className)
	for key, value in pairs(props) do
		element[key] = value
	end
	element.Parent = parent
	return element
end

-- ============================================================
-- V1: Disjuntor de Energia - 4 alavancas
-- ============================================================
local _v1Levers = {}  -- Estado de cada alavanca (false=esquerda, true=direita)
local _v1LeverStates = { false, false, false, false }
local _v1Repetition: number = 0
local _v1RequiredReps: number = 4

--[[
  Verifica se todas as alavancas V1 estao para a direita.
]]
local function areAllLeversRight(): boolean
	for i = 1, 4 do
		if not _v1LeverStates[i] then
			return false
		end
	end
	return true
end

--[[
  Envia progresso V1 ao servidor.
]]
local function sendV1Progress(): ()
	if not _activeMissionId or not _playerActionEvent then
		return
	end

	if areAllLeversRight() then
		_v1Repetition = _v1Repetition + 1

		-- Enviar progresso
		RemoteEventUtils.firePlayer(
			_playerActionEvent,
			LocalPlayer,
			"MISSION_PROGRESS",
			{ missionId = _activeMissionId, progress = _v1Repetition }
		)

		if _v1Repetition >= _v1RequiredReps then
			-- Missao completa
			updateProgressBar(1)
			return
		end

		-- Resetar alavancas para a proxima repeticao
		for i = 1, 4 do
			_v1LeverStates[i] = false
			if _v1Levers[i] then
				_v1Levers[i].BackgroundColor3 = Color3.fromRGB(150, 50, 50)
				_v1Levers[i][2].Text = "←"
			end
		end

		updateProgressBar(_v1Repetition / _v1RequiredReps)
	end
end

--[[
  Cria a UI do V1 Breaker: 4 botoes de alavanca.
]]
local function createV1UI(parent: Frame): ()
	_v1Levers = {}
	_v1LeverStates = { false, false, false, false }
	_v1Repetition = 0
	_v1RequiredReps = GameConstants.Missions.V1_BREAKER.REPETITIONS or 4
	_maxProgress = _v1RequiredReps
	_currentProgress = 0

	-- Titulo
	createElement("TextLabel", parent, {
		Name = "V1Title",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Disjuntor de Energia",
		TextColor3 = Color3.fromRGB(255, 200, 100),
		TextSize = 16,
		Font = Enum.Font.SourceSansBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Grid 2x2 de alavancas
	local grid = createElement("Frame", parent, {
		Name = "LeverGrid",
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 0, 30),
		BackgroundTransparency = 1,
	})

	local positions = {
		UDim2.new(0, 10, 0, 10),
		UDim2.new(5/10, 5, 0, 10),
		UDim2.new(0, 10, 5/10, 5),
		UDim2.new(5/10, 5, 5/10, 5),
	}

	for i = 1, 4 do
		local leverBtn = createElement("TextButton", grid, {
			Name = "Lever" .. i,
			Size = UDim2.new(5/10, -15, 5/10, -15),
			Position = positions[i],
			BackgroundColor3 = Color3.fromRGB(150, 50, 50),
			Text = "←",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 28,
			Font = Enum.Font.SourceSansBold,
			AutoButtonColor = true,
		})

		-- Label de numero da alavanca
		createElement("TextLabel", leverBtn, {
			Name = "LeverLabel",
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.new(0, 0, 1, -16),
			Text = "Alavanca " .. i,
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextSize = 10,
			Font = Enum.Font.SourceSans,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
		})

		local leverIndex = i

		leverBtn.MouseButton1Click:Connect(function()
			if not _missionActive then return end

			-- Alternar estado
			_v1LeverStates[leverIndex] = not _v1LeverStates[leverIndex]

			if _v1LeverStates[leverIndex] then
				leverBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
				leverBtn.Text = "→"
			else
				leverBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
				leverBtn.Text = "←"
			end

			sendV1Progress()
		end)

		_v1Levers[leverIndex] = leverBtn
	end
end

-- ============================================================
-- V2: Gerador - 5 cabos para conectar em sequencia
-- ============================================================
local _v2Cables = {}
local _v2CableStates = { false, false, false, false, false }
local _v2NextCable: number = 1
local _v2Repetition: number = 0
local _v2RequiredReps: number = 4

--[[
  Envia progresso V2 ao servidor.
]]
local function sendV2Progress(): ()
	if not _activeMissionId or not _playerActionEvent then
		return
	end

	-- Contar cabos conectados
	local connected = 0
	for i = 1, 5 do
		if _v2CableStates[i] then
			connected = connected + 1
		end
	end

	if connected >= 5 then
		_v2Repetition = _v2Repetition + 1

		RemoteEventUtils.firePlayer(
			_playerActionEvent,
			LocalPlayer,
			"MISSION_PROGRESS",
			{ missionId = _activeMissionId, progress = _v2Repetition }
		)

		if _v2Repetition >= _v2RequiredReps then
			updateProgressBar(1)
			return
		end

		-- Resetar cabos para proxima repeticao
		for i = 1, 5 do
			_v2CableStates[i] = false
			if _v2Cables[i] then
				_v2Cables[i].BackgroundColor3 = Color3.fromRGB(80, 80, 80)
				_v2Cables[i].Text = "Cabo " .. i .. " (?)"
			end
		end
		_v2NextCable = 1

		updateProgressBar(_v2Repetition / _v2RequiredReps)
	end
end

--[[
  Cria a UI do V2 Generator: 5 cabos em sequencia.
]]
local function createV2UI(parent: Frame): ()
	_v2Cables = {}
	_v2CableStates = { false, false, false, false, false }
	_v2NextCable = 1
	_v2Repetition = 0
	_v2RequiredReps = GameConstants.Missions.V2_GENERATOR.REPETITIONS or 4
	_maxProgress = _v2RequiredReps
	_currentProgress = 0

	-- Titulo
	createElement("TextLabel", parent, {
		Name = "V2Title",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Gerador - Conecte os cabos na ordem",
		TextColor3 = Color3.fromRGB(255, 200, 100),
		TextSize = 14,
		Font = Enum.Font.SourceSansBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Label de instrucao
	local instructionLabel = createElement("TextLabel", parent, {
		Name = "V2Instruction",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 28),
		Text = "Conecte: Cabo 1",
		TextColor3 = Color3.fromRGB(100, 200, 255),
		TextSize = 12,
		Font = Enum.Font.SourceSans,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- 5 cabos em coluna
	for i = 1, 5 do
		local yPos = 48 + (i - 1) * 32

		local cableBtn = createElement("TextButton", parent, {
			Name = "Cable" .. i,
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 0, yPos),
			BackgroundColor3 = Color3.fromRGB(80, 80, 80),
			Text = "Cabo " .. i .. " (?)",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 13,
			Font = Enum.Font.SourceSans,
			AutoButtonColor = true,
		})

		local cableIndex = i

		cableBtn.MouseButton1Click:Connect(function()
			if not _missionActive then return end

			-- So pode conectar na ordem
			if cableIndex ~= _v2NextCable then
				-- Feedback: piscar vermelho
				cableBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
				task.wait(2/10)
				if _v2CableStates[cableIndex] then
					cableBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
				else
					cableBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
				end
				return
			end

			-- Conectar cabo
			_v2CableStates[cableIndex] = true
			cableBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			cableBtn.Text = "Cabo " .. cableIndex .. " (OK)"
			_v2NextCable = _v2NextCable + 1

			-- Atualizar instrucao
			if _v2NextCable <= 5 then
				instructionLabel.Text = "Conecte: Cabo " .. _v2NextCable
			else
				instructionLabel.Text = "Todos conectados!"
			end

			sendV2Progress()
		end)

		_v2Cables[cableIndex] = cableBtn
	end
end

-- ============================================================
-- V3: Maquina de Petroleo - ponteiro/zona (Flee-style)
-- ============================================================
local _v3PointerAngle: number = 0
local _v3TargetZoneStart: number = 0
local _v3TargetZoneEnd: number = 0
local _v3PointerSpeed: number = 120      -- graus/s
local _v3PointerDirection: number = 1    -- 1 ou -1
local _v3PointerFrame: Frame? = nil
local _v3ClickButton: TextButton? = nil
local _v3IsLocked: boolean = false
local _v3LastRender: number = 0

--[[
  Gera uma nova zona de acerto aleatoria.
]]
local function generateTargetZone(): ()
	-- Zona ocupa ~20% do arco (72 graus)
	local zoneSize = 72
	local maxStart = 360 - zoneSize
	_v3TargetZoneStart = math.random(0, maxStart)
	_v3TargetZoneEnd = _v3TargetZoneStart + zoneSize
end

--[[
  Verifica se o ponteiro esta na zona de acerto.
]]
local function isPointerInZone(): boolean
	local angle = _v3PointerAngle % 360
	if angle < 0 then
		angle = angle + 360
	end

	return angle >= _v3TargetZoneStart and angle <= _v3TargetZoneEnd
end

--[[
  Cria a UI do V3 Oil Machine: ponteiro circular.
]]
local function createV3UI(parent: Frame): ()
	_v3PointerAngle = 0
	_v3PointerSpeed = 120
	_v3PointerDirection = 1
	_v3IsLocked = false
	_v3LastRender = 0
	_maxProgress = 1
	_currentProgress = 0

	generateTargetZone()

	-- Titulo
	createElement("TextLabel", parent, {
		Name = "V3Title",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Maquina de Petroleo",
		TextColor3 = Color3.fromRGB(255, 200, 100),
		TextSize = 16,
		Font = Enum.Font.SourceSansBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Container circular
	local circleSize = 160
	local circleContainer = createElement("Frame", parent, {
		Name = "CircleContainer",
		Size = UDim2.new(0, circleSize, 0, circleSize),
		Position = UDim2.new(5/10, -circleSize/2, 0, 35),
		BackgroundTransparency = 1,
	})

	-- Circulo de fundo
	local bgCircle = createElement("Frame", circleContainer, {
		Name = "BGCircle",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0,
	})
	-- Aproximacao de circulo via UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(5/10, 0)
	corner.Parent = bgCircle

	-- Zona de acerto (arco verde)
	local zoneIndicator = createElement("Frame", circleContainer, {
		Name = "ZoneIndicator",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(50, 200, 50),
		BackgroundTransparency = 6/10,
		BorderSizePixel = 0,
		ZIndex = 1,
	})
	local zoneCorner = Instance.new("UICorner")
	zoneCorner.CornerRadius = UDim.new(5/10, 0)
	zoneCorner.Parent = zoneIndicator

	-- Ponteiro (linha radial)
	_v3PointerFrame = createElement("Frame", circleContainer, {
		Name = "Pointer",
		Size = UDim2.new(0, 3, 5/10, 0),
		Position = UDim2.new(5/10, -1, 0, 0),
		AnchorPoint = Vector2.new(5/10, 0),
		BackgroundColor3 = Color3.fromRGB(255, 50, 50),
		BorderSizePixel = 0,
		ZIndex = 5,
	})

	-- Botao de clique (sobre toda a area)
	_v3ClickButton = createElement("TextButton", circleContainer, {
		Name = "ClickZone",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	})

	_v3ClickButton.MouseButton1Click:Connect(function()
		if not _missionActive then return end

		if isPointerInZone() then
			-- Acertou!
			_v3IsLocked = true

			RemoteEventUtils.firePlayer(
				_playerActionEvent,
				LocalPlayer,
				"MISSION_PROGRESS",
				{ missionId = _activeMissionId, progress = 1 }
			)

			updateProgressBar(1)

			-- Feedback visual
			if _v3PointerFrame then
				_v3PointerFrame.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
			end
			if bgCircle then
				bgCircle.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
			end
		else
			-- Errou! Resetar ponteiro
			_v3PointerSpeed = _v3PointerSpeed + 30 -- Aumenta velocidade
			_v3PointerDirection = _v3PointerDirection * -1 -- Inverte direcao
			generateTargetZone()

			-- Feedback: piscar vermelho
			if bgCircle then
				bgCircle.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
				task.delay(3/10, function()
					if bgCircle and not _v3IsLocked then
						bgCircle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					end
				end)
			end
		end
	end)

	-- Instrucao
	createElement("TextLabel", parent, {
		Name = "V3Instruction",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, circleSize + 40),
		Text = "Clique quando o ponteiro estiver na zona verde!",
		TextColor3 = Color3.fromRGB(200, 200, 200),
		TextSize = 12,
		Font = Enum.Font.SourceSans,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

-- ============================================================
-- Barra de Progresso (comum a todos os tipos)
-- ============================================================
local _progressBar: Frame? = nil
local _progressFill: Frame? = nil
local _progressLabel: TextLabel? = nil

function updateProgressBar(ratio: number): ()
	if _progressFill then
		_progressFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
	end
	if _progressLabel then
		_progressLabel.Text = string.format("Progresso: %.0f%%", ratio * 100)
	end
end

--[[
  Cria a barra de progresso no parent.
]]
local function createProgressBar(parent: Frame): ()
	local barContainer = createElement("Frame", parent, {
		Name = "ProgressContainer",
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.new(0, 5, 1, -24),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderSizePixel = 0,
	})

	_progressFill = createElement("Frame", barContainer, {
		Name = "ProgressFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(50, 150, 200),
		BorderSizePixel = 0,
		ZIndex = 1,
	})

	_progressLabel = createElement("TextLabel", barContainer, {
		Name = "ProgressLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "Progresso: 0%",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 11,
		Font = Enum.Font.SourceSans,
		TextStrokeTransparency = 8/10,
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
end

-- ============================================================
-- Render loop do V3 (ponteiro giratorio)
-- ============================================================
local function onRenderStep(deltaTime: number): ()
	if not _missionActive then return end
	if _activeMissionType ~= "V3" then return end
	if _v3IsLocked then return end

	-- Atualizar angulo do ponteiro
	_v3PointerAngle = _v3PointerAngle + (_v3PointerSpeed * deltaTime * _v3PointerDirection)

	if _v3PointerFrame then
		_v3PointerFrame.Rotation = _v3PointerAngle
	end

	-- Refletir na UI quando o ponteiro cruzar limites
	-- (a rotacao do frame ja faz o trabalho visual)
end

-- ============================================================
-- Controle da UI de Missao
-- ============================================================

--[[
  Abre a UI de missao para um tipo especifico.
  Chamado quando o servidor confirma o inicio da missao.
]]
function MissionUI.openMission(missionId: string, missionType: string): ()
	-- Fechar UI anterior se houver
	MissionUI.closeMission()

	_activeMissionId = missionId
	_activeMissionType = missionType
	_missionActive = true
	_currentProgress = 0

	-- Criar ScreenGui
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "MissionUI"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Frame principal (centro da tela)
	local mainFrame = createElement("Frame", _screenGui, {
		Name = "MissionFrame",
		Size = UDim2.new(0, 300, 0, 280),
		Position = UDim2.new(5/10, -150, 5/10, -140),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 3/10,
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(100, 100, 100),
	})

	-- Barra de progresso
	createProgressBar(mainFrame)

	-- Criar UI especifica do tipo
	if missionType == "V1" then
		createV1UI(mainFrame)
	elseif missionType == "V2" then
		createV2UI(mainFrame)
	elseif missionType == "V3" then
		createV3UI(mainFrame)

		-- Iniciar render loop para o ponteiro
		RunService.RenderStepped:Connect(onRenderStep)
	end

	-- Botao de cancelar (X no canto)
	local closeBtn = createElement("TextButton", mainFrame, {
		Name = "CloseButton",
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(1, -28, 0, 4),
		BackgroundColor3 = Color3.fromRGB(150, 50, 50),
		Text = "X",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		Font = Enum.Font.SourceSansBold,
		AutoButtonColor = true,
	})

	closeBtn.MouseButton1Click:Connect(function()
		MissionUI.cancelMission("user_cancel")
	end)

	print("[TheBrokenBox] MissionUI: Missao aberta - " .. missionId .. " (" .. missionType .. ")")
end

--[[
  Fecha a UI de missao (limpa elementos).
]]
function MissionUI.closeMission(): ()
	_missionActive = false
	_activeMissionId = nil
	_activeMissionType = nil

	-- Limpar estado V3
	_v3IsLocked = false
	_v3PointerFrame = nil
	_v3ClickButton = nil

	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end

	_progressFill = nil
	_progressLabel = nil
end

--[[
  Cancela a missao atual (enviando ao servidor).
]]
function MissionUI.cancelMission(reason: string?): ()
	if not _activeMissionId then
		return
	end

	-- Enviar cancelamento ao servidor
	if _playerActionEvent then
		RemoteEventUtils.firePlayer(
			_playerActionEvent,
			LocalPlayer,
			"MISSION_CANCEL",
			{ missionId = _activeMissionId, reason = reason or "movement" }
		)
	end

	print("[TheBrokenBox] MissionUI: Missao cancelada - " .. (_activeMissionId or "?") .. " (" .. (reason or "?") .. ")")
	MissionUI.closeMission()
end

-- ============================================================
-- Deteccao de movimento (cancelamento automatico)
-- ============================================================
local _lastMoveCheckTime: number = 0

local function checkMovementCancel(): ()
	if not _missionActive then return end

	local now = os.clock()
	if now - _lastMoveCheckTime < 3/10 then
		return -- Verificar a cada 300ms
	end
	_lastMoveCheckTime = now

	-- Verificar se o jogador esta se movendo
	local character = LocalPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Se a velocidade do Humanoid for significativa, cancelar
	if humanoid.MoveDirection.Magnitude > 1/10 then
		MissionUI.cancelMission("movement")
	end
end

-- ============================================================
-- Listeners de eventos do servidor
-- ============================================================

--[[
  Processa mensagens do UISyncEvent / GameStateEvent para missoes.
  Escuta por MISSION_STARTED / MISSION_COMPLETED / MISSION_CANCELLED.
]]
local function onGameStateMessage(message: {any}): ()
	local msgType = message.type
	local data = message.data

	if msgType == "MISSION_STARTED" then
		if data and data.missionId and data.missionType then
			MissionUI.openMission(data.missionId, data.missionType)
		end

	elseif msgType == "MISSION_COMPLETED" then
		if _activeMissionId == data.missionId then
			MissionUI.closeMission()
		end

	elseif msgType == "MISSION_CANCELLED" then
		if _activeMissionId == data.missionId then
			MissionUI.closeMission()
		end
	end
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): encontra o RemoteEvent e prepara estruturas.
]]
function MissionUI.Init(): ()
	print("[TheBrokenBox] MissionUI.Init()")

	-- Encontrar o RemoteEvent PlayerActionEvent
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_playerActionEvent = RemoteEventUtils.findRemoteEvent(eventsFolder, "PlayerActionEvent")
	end

	if not _playerActionEvent then
		warn("[TheBrokenBox] MissionUI: PlayerActionEvent nao encontrado!")
	end

	-- Encontrar GameStateEvent para eventos de missao
	local gameStateEvent: RemoteEvent? = nil
	if eventsFolder then
		gameStateEvent = RemoteEventUtils.findRemoteEvent(eventsFolder, "GameStateEvent")
	end

	if gameStateEvent then
		gameStateEvent.OnClientEvent:Connect(onGameStateMessage)
		print("[TheBrokenBox] MissionUI: Listener do GameStateEvent conectado.")
	end
end

--[[
  Start(): inicia o loop de deteccao de movimento para cancelamento.
]]
function MissionUI.Start(): ()
	print("[TheBrokenBox] MissionUI.Start() - iniciando deteccao de movimento...")

	-- Loop de deteccao de movimento (a cada 300ms)
	task.spawn(function()
		while true do
			checkMovementCancel()
			task.wait(3/10)
		end
	end)

	print("[TheBrokenBox] MissionUI pronto.")
end

return MissionUI
