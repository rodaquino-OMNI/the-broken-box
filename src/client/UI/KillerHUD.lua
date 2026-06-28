--!strict
--[[
  KillerHUD.lua
  HUD do Cacador (cliente).
  Exibe:
    - Barra de Furia (0-100+)
    - Cooldowns de habilidades (M1, Pull, Roar)
    - Contagem de Sobreviventes vivos (sem classes/HP)
    - Indicadores de proximidade (batimentos, distorcao de borda)

  Escuta UISyncEvent para atualizacoes do servidor (~60Hz).
  Assimetria de informacao: Cacador NAO ve classes nem HP dos Sobreviventes.

  Referencias: GDD M7 (Camera e Visao do Cacador), architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local UISyncEvent = require(ReplicatedStorage.Events.UISyncEvent)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local KillerHUD = {}

-- ============================================================
-- Estado interno do HUD
-- ============================================================
local _screenGui: ScreenGui? = nil
local _furyBar: Frame? = nil
local _furyFill: Frame? = nil
local _furyLabel: TextLabel? = nil
local _cooldownLabels: { [string]: TextLabel } = {}
local _aliveCountLabel: TextLabel? = nil
local _proximityIndicator: Frame? = nil -- Distorcao de borda

-- Cache de estado recebido do servidor
local _cachedFury: number = 0
local _cachedAliveCount: number = 4
local _cachedCooldowns: { [string]: number } = {}
local _cachedProximityLevel: number = 0 -- 0=Calma, 1=Alerta, 2=Perseguicao

-- Conexao do UISyncEvent
local _uiSyncEvent: RemoteEvent? = nil
local _uiSyncConnection: RBXScriptConnection? = nil

-- ============================================================
-- Constantes visuais (estilo retraux)
-- ============================================================
local HUD_COLORS = {
	FURY_FILL = Color3.fromRGB(200, 60, 40),       -- Vermelho furia
	FURY_BG = Color3.fromRGB(40, 20, 20),            -- Fundo escuro
	COOLDOWN_READY = Color3.fromRGB(100, 200, 100),  -- Verde = pronto
	COOLDOWN_ACTIVE = Color3.fromRGB(200, 200, 100), -- Amarelo = recarregando
	TEXT = Color3.fromRGB(220, 220, 220),            -- Texto claro
	PROXIMITY_EDGE = Color3.fromRGB(0, 0, 0),        -- Preto para distorcao
}

-- ============================================================
-- Construcao da UI
-- ============================================================

--[[
  Cria a ScreenGui principal e todos os elementos do HUD.
]]
local function createUI()
	-- Criar ScreenGui
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "KillerHUD"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- ============================================================
	-- Barra de Furia (topo-central)
	-- ============================================================
	_furyBar = Instance.new("Frame")
	_furyBar.Name = "FuryBar"
	_furyBar.Size = UDim2.new(0, 300, 0, 24)
	_furyBar.Position = UDim2.new(0.5, -150, 0, 10)
	_furyBar.BackgroundColor3 = HUD_COLORS.FURY_BG
	_furyBar.BorderSizePixel = 1
	_furyBar.Parent = _screenGui

	-- Preenchimento da furia
	_furyFill = Instance.new("Frame")
	_furyFill.Name = "FuryFill"
	_furyFill.Size = UDim2.new(0, 0, 1, 0)
	_furyFill.BackgroundColor3 = HUD_COLORS.FURY_FILL
	_furyFill.BorderSizePixel = 1
	_furyFill.Parent = _furyBar

	-- Label de texto da furia
	_furyLabel = Instance.new("TextLabel")
	_furyLabel.Name = "FuryLabel"
	_furyLabel.Size = UDim2.new(1, 0, 1, 0)
	_furyLabel.BackgroundTransparency = 1
	_furyLabel.Text = "FURIA: 0/100"
	_furyLabel.TextColor3 = HUD_COLORS.TEXT
	_furyLabel.Font = Enum.Font.SourceSansBold
	_furyLabel.TextSize = 14
	_furyLabel.TextStrokeTransparency = 0.5
	_furyLabel.Parent = _furyBar

	-- ============================================================
	-- Cooldowns (canto inferior direito)
	-- ============================================================
	local function createCooldownLabel(name: string, positionY: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name .. "Cooldown"
		label.Size = UDim2.new(0, 180, 0, 22)
		label.Position = UDim2.new(1, -190, 1, positionY)
		label.AnchorPoint = Vector2.new(0, 0)
		label.BackgroundTransparency = 0.7
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		label.TextColor3 = HUD_COLORS.COOLDOWN_READY
		label.Font = Enum.Font.SourceSans
		label.TextSize = 13
		label.TextStrokeTransparency = 0.5
		label.Text = name .. ": PRONTO"
		label.Parent = _screenGui
		return label
	end

	_cooldownLabels["M1"] = createCooldownLabel("M1 (Tapa)", -100)
	_cooldownLabels["Pull"] = createCooldownLabel("Braco Esticado", -76)
	_cooldownLabels["Roar"] = createCooldownLabel("Grito", -52)

	-- ============================================================
	-- Contagem de Sobreviventes vivos (canto superior direito)
	-- ============================================================
	_aliveCountLabel = Instance.new("TextLabel")
	_aliveCountLabel.Name = "AliveCountLabel"
	_aliveCountLabel.Size = UDim2.new(0, 200, 0, 30)
	_aliveCountLabel.Position = UDim2.new(1, -210, 0, 10)
	_aliveCountLabel.AnchorPoint = Vector2.new(0, 0)
	_aliveCountLabel.BackgroundTransparency = 0.8
	_aliveCountLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	_aliveCountLabel.TextColor3 = HUD_COLORS.TEXT
	_aliveCountLabel.Font = Enum.Font.SourceSansBold
	_aliveCountLabel.TextSize = 16
	_aliveCountLabel.TextStrokeTransparency = 0.5
	_aliveCountLabel.Text = "VIVOS: 4"
	_aliveCountLabel.Parent = _screenGui

	-- ============================================================
	-- Indicador de proximidade (distorcao de borda)
	-- Frame semi-transparente nas bordas que escurece com proximidade
	-- ============================================================
	_proximityIndicator = Instance.new("Frame")
	_proximityIndicator.Name = "ProximityEdge"
	_proximityIndicator.Size = UDim2.new(1, 0, 1, 0)
	_proximityIndicator.BackgroundTransparency = 1
	_proximityIndicator.BorderSizePixel = 0
	_proximityIndicator.ZIndex = 10
	_proximityIndicator.Parent = _screenGui

	-- Criar 4 bordas (top, bottom, left, right) para efeito de vignette
	local function createEdgeBar(name: string, size: UDim2, position: UDim2)
		local edge = Instance.new("Frame")
		edge.Name = name
		edge.Size = size
		edge.Position = position
		edge.BackgroundColor3 = HUD_COLORS.PROXIMITY_EDGE
		edge.BackgroundTransparency = 1 -- Invisivel ate proximidade
		edge.BorderSizePixel = 0
		edge.Parent = _proximityIndicator
		return edge
	end

	createEdgeBar("TopEdge", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 0))
	createEdgeBar("BottomEdge", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 1, -60))
	createEdgeBar("LeftEdge", UDim2.new(0, 40, 1, 0), UDim2.new(0, 0, 0, 0))
	createEdgeBar("RightEdge", UDim2.new(0, 40, 1, 0), UDim2.new(1, -40, 0, 0))

	print("[TheBrokenBox] KillerHUD: UI criada.")
end

-- ============================================================
-- Atualizacao da UI
-- ============================================================

--[[
  Atualiza a barra de Furia.
]]
local function updateFuryBar()
	if not _furyFill or not _furyLabel then return end

	local furyConfig = GameConstants.Hunter.FURY
	local fillPercent = math.clamp(_cachedFury / furyConfig.MAX, 0, 1)
	_furyFill.Size = UDim2.new(fillPercent, 0, 1, 0)
	_furyLabel.Text = "FURIA: " .. math.floor(_cachedFury) .. "/" .. furyConfig.MAX

	-- Cor muda quando atinge o limiar de Rage
	if _cachedFury >= furyConfig.RAGE_THRESHOLD then
		_furyFill.BackgroundColor3 = Color3.fromRGB(255, 80, 40) -- Tom mais intenso
	else
		_furyFill.BackgroundColor3 = HUD_COLORS.FURY_FILL
	end
end

--[[
  Atualiza os labels de cooldown.
]]
local function updateCooldowns()
	for ability, label in pairs(_cooldownLabels) do
		local remaining = _cachedCooldowns[ability] or 0

		if remaining <= 0 then
			label.Text = ability .. ": PRONTO"
			label.TextColor3 = HUD_COLORS.COOLDOWN_READY
		else
			label.Text = ability .. ": " .. string.format("%.1f", remaining) .. "s"
			label.TextColor3 = HUD_COLORS.COOLDOWN_ACTIVE
		end
	end
end

--[[
  Atualiza a contagem de Sobreviventes vivos.
]]
local function updateAliveCount()
	if not _aliveCountLabel then return end
	_aliveCountLabel.Text = "VIVOS: " .. _cachedAliveCount
end

--[[
  Atualiza o indicador de proximidade (distorcao de borda).
  proximityLevel: 0=Calma, 1=Alerta, 2=Perseguicao
]]
local function updateProximityIndicator()
	if not _proximityIndicator then return end

	local alpha: number

	if _cachedProximityLevel <= 0 then
		alpha = 0 -- Sem distorcao
	elseif _cachedProximityLevel == 1 then
		alpha = 0.15 -- Alerta leve
	else
		alpha = 0.35 -- Perseguicao intensa
	end

	-- Aplicar transparencia uniforme nas bordas
	for _, edge in ipairs(_proximityIndicator:GetChildren()) do
		if edge:IsA("Frame") then
			edge.BackgroundTransparency = 1 - alpha
		end
	end
end

-- ============================================================
-- Processamento de mensagens do UISyncEvent
-- ============================================================

--[[
  Callback quando recebe atualizacao do UISyncEvent.
  message.data contem: fury, aliveCount, cooldowns, proximityLevel
]]
local function onUISync(_player: Player, message: {any})
	if message.type ~= UISyncEvent.MESSAGES.HUD_UPDATE then
		return
	end

	local data = message.data
	if not data then return end

	-- Cache dos dados
	_cachedFury = data.fury or 0
	_cachedAliveCount = data.aliveCount or 0
	_cachedCooldowns = data.cooldowns or {}
	_cachedProximityLevel = data.proximityLevel or 0

	-- Atualizar UI
	updateFuryBar()
	updateCooldowns()
	updateAliveCount()
	updateProximityIndicator()
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): cria a UI e encontra o RemoteEvent.
]]
function KillerHUD.Init(): ()
	print("[TheBrokenBox] KillerHUD.Init()")

	-- Encontrar o UISyncEvent
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_uiSyncEvent = RemoteEventUtils.findRemoteEvent(eventsFolder, UISyncEvent.NAME)
	end

	if not _uiSyncEvent then
		warn("[TheBrokenBox] KillerHUD: UISyncEvent nao encontrado!")
		-- Criar se nao existir (para testes)
		if eventsFolder then
			_uiSyncEvent = RemoteEventUtils.createRemoteEvent(eventsFolder, UISyncEvent.NAME)
			print("[TheBrokenBox] KillerHUD: UISyncEvent criado.")
		end
	end
end

--[[
  Start(): conecta o listener e constroi a UI.
]]
function KillerHUD.Start(): ()
	print("[TheBrokenBox] KillerHUD.Start() — construindo UI e registrando listener...")

	-- Criar interface
	createUI()

	-- Conectar ao UISyncEvent
	if _uiSyncEvent then
		_uiSyncConnection = _uiSyncEvent.OnClientEvent:Connect(onUISync)
		print("[TheBrokenBox] KillerHUD: Listener do UISyncEvent conectado.")
	else
		warn("[TheBrokenBox] KillerHUD: UISyncEvent nao disponivel! HUD nao recebera atualizacoes.")
	end

	print("[TheBrokenBox] KillerHUD pronto. Furia: 0, Vivos: ?")
end

return KillerHUD
