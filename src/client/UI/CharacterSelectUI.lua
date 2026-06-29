--!strict
--[[
  CharacterSelectUI.lua
  UI de selecao de personagem no lobby (client-side).
  Exibe personagens disponiveis (gratis e pagos).
  Envia SELECT_CHARACTER via PlayerActionEvent ao selecionar.
  Escuta GameStateEvent para lock-in do personagem.

  Usa script.Parent para requires (convencao Rojo).
  Usa IsA("RemoteEvent") para encontrar RemoteEvents em ReplicatedStorage.

  Referencias: GDD Lobby - A Caixa, architecture.md 12.1
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Dependencias compartilhadas (ReplicatedStorage)
-- ============================================================
local GameConstants = require(ReplicatedStorage.GameConstants)

local CharacterSelectUI = {}

-- ============================================================
-- Cores e estilo (retraux)
-- ============================================================
local COLORS = {
	BG = Color3.fromRGB(15, 15, 20),              -- Fundo escuro
	PANEL = Color3.fromRGB(25, 25, 35),           -- Painel de selecao
	TITLE = Color3.fromRGB(220, 200, 140),        -- Titulo dourado/amber
	TEXT = Color3.fromRGB(200, 200, 210),         -- Texto claro
	FREE = Color3.fromRGB(100, 200, 120),         -- Verde = gratuito
	PAID = Color3.fromRGB(200, 180, 60),          -- Dourado = pago
	LOCKED = Color3.fromRGB(120, 120, 120),       -- Cinza = bloqueado
	BUTTON_BG = Color3.fromRGB(40, 40, 55),       -- Fundo do botao
	BUTTON_HOVER = Color3.fromRGB(60, 60, 80),    -- Hover do botao
	BUTTON_LOCKED = Color3.fromRGB(35, 35, 35),   -- Botao bloqueado
	SELECTED_BORDER = Color3.fromRGB(220, 200, 140), -- Borda de selecionado
}

-- ============================================================
-- Estado interno
-- ============================================================
local _screenGui: ScreenGui? = nil
local _mainFrame: Frame? = nil
local _titleLabel: TextLabel? = nil
local _characterFrames: { Frame } = {}
local _selectButton: TextButton? = nil
local _statusLabel: TextLabel? = nil

-- Estado da selecao
local _selectedCharacter: string? = nil
local _characterLocked: boolean = false
local _isSelecting: boolean = false

-- RemoteEvents (descobertos via IsA)
local _playerActionEvent: RemoteEvent? = nil
local _gameStateEvent: RemoteEvent? = nil
local _gameStateConnection: RBXScriptConnection? = nil

-- ============================================================
-- Dados dos personagens
-- ============================================================
-- Disponiveis no MVP:
--   Gratis: Distorcido (Hunter), Sackboy, Medico
--   Pagos: Soldado, Robo

type CharacterInfo = {
	class: string,
	name: string,
	role: string,
	free: boolean,
	cost: number?,
	description: string,
}

local function getAvailableCharacters(): { CharacterInfo }
	local chars = {}

	-- Cacador (gratis)
	table.insert(chars, {
		class = "Distorcido",
		name = GameConstants.Hunter.NAME,
		role = "Hunter",
		free = true,
		description = "O Cacador - criatura sobrenatural (HP 2000)",
	})

	-- Sobreviventes gratuitos
	table.insert(chars, {
		class = "Sackboy",
		name = GameConstants.Survivors.SACKBOY.NAME,
		role = "Survivor",
		free = true,
		description = "Hit & Run / Controle (HP " .. GameConstants.Survivors.SACKBOY.MAX_HP .. ")",
	})
	table.insert(chars, {
		class = "Medico",
		name = GameConstants.Survivors.MEDICO.NAME,
		role = "Survivor",
		free = true,
		description = "Suporte/Cura (HP " .. GameConstants.Survivors.MEDICO.MAX_HP .. ")",
	})

	-- Sobreviventes pagos
	table.insert(chars, {
		class = "Soldado",
		name = GameConstants.Survivors.SOLDADO.NAME,
		role = "Survivor",
		free = false,
		description = "Controle a Distancia (HP " .. GameConstants.Survivors.SOLDADO.MAX_HP .. ")",
		cost = GameConstants.Economy.UNLOCK_COST_SOLDADO,
	})
	table.insert(chars, {
		class = "Robo",
		name = GameConstants.Survivors.ROBO.NAME,
		role = "Survivor",
		free = false,
		description = "Tanque / Sacrificio (HP " .. GameConstants.Survivors.ROBO.MAX_HP .. ")",
		cost = GameConstants.Economy.UNLOCK_COST_ROBO,
	})

	return chars
end

-- ============================================================
-- Construcao da UI
-- ============================================================

--[[
  Cria um botao de personagem individual.
]]
local function createCharacterButton(parent: Frame, char: CharacterInfo, index: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "CharFrame_" .. char.class
	frame.Size = UDim2.new(1, -20, 0, 60)
	frame.Position = UDim2.new(0, 10, 0, 10 + (index - 1) * 70)
	frame.BackgroundColor3 = COLORS.BUTTON_BG
	frame.BorderSizePixel = 1
	frame.BorderColor3 = Color3.fromRGB(60, 60, 80)
	frame.Parent = parent

	-- Nome do personagem
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 160, 0, 24)
	nameLabel.Position = UDim2.new(0, 10, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = char.name
	nameLabel.TextColor3 = char.free and COLORS.FREE or COLORS.PAID
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	-- Descricao (role)
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(0, 160, 0, 18)
	descLabel.Position = UDim2.new(0, 10, 0, 34)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = char.description
	descLabel.TextColor3 = COLORS.TEXT
	descLabel.Font = Enum.Font.SourceSans
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = frame

	-- Tag: GRATIS ou PAGO
	local tagLabel = Instance.new("TextLabel")
	tagLabel.Name = "TagLabel"
	tagLabel.Size = UDim2.new(0, 80, 0, 20)
	tagLabel.Position = UDim2.new(1, -90, 0, 6)
	tagLabel.BackgroundTransparency = char.free and 0.6 or 0.4
	tagLabel.BackgroundColor3 = char.free and COLORS.FREE or COLORS.PAID
	tagLabel.Text = char.free and "GRATIS" or ("PAGO (" .. (char.cost or 0) .. ")")
	tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tagLabel.Font = Enum.Font.SourceSansBold
	tagLabel.TextSize = 11
	tagLabel.Parent = frame

	-- Botao de clique (invisivel, cobre todo o frame)
	local button = Instance.new("TextButton")
	button.Name = "SelectButton"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = frame

	-- Eventos de hover e clique
	button.MouseEnter:Connect(function()
		if _characterLocked then return end
		if not char.free then
			-- Personagem pago: mostrar como bloqueado se nao desbloqueado
			-- (no MVP, todos os pagos estao bloqueados por padrao)
			frame.BackgroundColor3 = COLORS.BUTTON_LOCKED
		else
			frame.BackgroundColor3 = COLORS.BUTTON_HOVER
		end
	end)

	button.MouseLeave:Connect(function()
		if _selectedCharacter == char.class then
			frame.BorderColor3 = COLORS.SELECTED_BORDER
			return
		end
		if not char.free then
			frame.BackgroundColor3 = COLORS.BUTTON_LOCKED
		else
			frame.BackgroundColor3 = COLORS.BUTTON_BG
		end
	end)

	button.MouseButton1Click:Connect(function()
		if _characterLocked then return end

		if not char.free then
			-- Personagem pago: verificar se pode comprar
			-- No MVP, pagos estao bloqueados
			_statusLabel.Text = char.name .. " esta bloqueado! (" .. (char.cost or 0) .. " moedas)"
			_statusLabel.TextColor3 = COLORS.LOCKED
			return
		end

		-- Selecionar personagem
		_selectedCharacter = char.class
		_statusLabel.Text = "Selecionado: " .. char.name
		_statusLabel.TextColor3 = COLORS.FREE

		-- Destacar visualmente
		for _, otherFrame in ipairs(_characterFrames) do
			otherFrame.BorderColor3 = Color3.fromRGB(60, 60, 80) -- Reset
		end
		frame.BorderColor3 = COLORS.SELECTED_BORDER

		-- Habilitar botao de confirmar
		if _selectButton then
			_selectButton.Visible = true
			_selectButton.Text = "CONFIRMAR - " .. char.name
		end
	end)

	-- Personagens pagos: cinza/opaco se bloqueados
	if not char.free then
		frame.BackgroundColor3 = COLORS.BUTTON_LOCKED
		nameLabel.TextColor3 = COLORS.LOCKED
		descLabel.TextColor3 = COLORS.LOCKED
		frame.BackgroundTransparency = 0.3
	end

	return frame
end

--[[
  Cria a ScreenGui completa da selecao de personagem.
]]
local function createUI(): ()
	-- Remover UI anterior se existir
	if _screenGui then
		_screenGui:Destroy()
	end

	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "CharacterSelectUI"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Frame principal (centralizado)
	_mainFrame = Instance.new("Frame")
	_mainFrame.Name = "MainFrame"
	_mainFrame.Size = UDim2.new(0, 380, 0, 520)
	_mainFrame.Position = UDim2.new(0.5, -190, 0.5, -260)
	_mainFrame.BackgroundColor3 = COLORS.PANEL
	_mainFrame.BorderSizePixel = 2
	_mainFrame.BorderColor3 = COLORS.TITLE
	_mainFrame.Parent = _screenGui

	-- Titulo
	_titleLabel = Instance.new("TextLabel")
	_titleLabel.Name = "TitleLabel"
	_titleLabel.Size = UDim2.new(1, -20, 0, 40)
	_titleLabel.Position = UDim2.new(0, 10, 0, 10)
	_titleLabel.BackgroundTransparency = 1
	_titleLabel.Text = "A CAIXA - SELECIONE SEU PERSONAGEM"
	_titleLabel.TextColor3 = COLORS.TITLE
	_titleLabel.Font = Enum.Font.SourceSansBold
	_titleLabel.TextSize = 18
	_titleLabel.Parent = _mainFrame

	-- Container dos personagens (scroll)
	local charContainer = Instance.new("ScrollingFrame")
	charContainer.Name = "CharContainer"
	charContainer.Size = UDim2.new(1, -20, 0, 370)
	charContainer.Position = UDim2.new(0, 10, 0, 55)
	charContainer.BackgroundTransparency = 0.8
	charContainer.BackgroundColor3 = COLORS.BG
	charContainer.BorderSizePixel = 1
	charContainer.ScrollBarThickness = 6
	charContainer.CanvasSize = UDim2.new(0, 0, 0, 380)
	charContainer.Parent = _mainFrame

	-- Criar botoes de personagens
	local characters = getAvailableCharacters()
	_characterFrames = {}
	for i, char in ipairs(characters) do
		local frame = createCharacterButton(charContainer, char, i)
		table.insert(_characterFrames, frame)
	end

	-- Botao de confirmar
	_selectButton = Instance.new("TextButton")
	_selectButton.Name = "ConfirmButton"
	_selectButton.Size = UDim2.new(1, -20, 0, 36)
	_selectButton.Position = UDim2.new(0, 10, 1, -50)
	_selectButton.BackgroundColor3 = COLORS.FREE
	_selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	_selectButton.Font = Enum.Font.SourceSansBold
	_selectButton.TextSize = 15
	_selectButton.Text = "SELECIONE UM PERSONAGEM"
	_selectButton.Visible = false
	_selectButton.Parent = _mainFrame

	_selectButton.MouseButton1Click:Connect(function()
		if _characterLocked then return end
		if not _selectedCharacter then return end
		if not _playerActionEvent then
			warn("[TheBrokenBox] CharacterSelectUI: PlayerActionEvent nao encontrado!")
			return
		end

		-- Enviar selecao para o servidor
		_playerActionEvent:FireServer({
			type = "SELECT_CHARACTER",
			data = {
				characterClass = _selectedCharacter,
			},
		})

		print("[TheBrokenBox] CharacterSelectUI: Enviando selecao - " .. _selectedCharacter)

		-- Feedback visual
		_statusLabel.Text = "Enviando selecao: " .. _selectedCharacter .. "..."
		_statusLabel.TextColor3 = COLORS.PAID
	end)

	-- Status / feedback
	_statusLabel = Instance.new("TextLabel")
	_statusLabel.Name = "StatusLabel"
	_statusLabel.Size = UDim2.new(1, -20, 0, 22)
	_statusLabel.Position = UDim2.new(0, 10, 1, 10)
	_statusLabel.BackgroundTransparency = 1
	_statusLabel.Text = ""
	_statusLabel.TextColor3 = COLORS.TEXT
	_statusLabel.Font = Enum.Font.SourceSans
	_statusLabel.TextSize = 13
	_statusLabel.Parent = _mainFrame
end

-- ============================================================
-- Eventos de rede
-- ============================================================

--[[
  Callback do GameStateEvent (Servidor -> Cliente).
  Processa mensagens:
    - CHARACTER_SELECT: abrir UI de selecao
    - YOUR_CHARACTER: personagem atribuido (lock-in)
    - CHARACTER_SELECTED: outro jogador selecionou
]]
local function onGameStateMessage(message: { type: string, data: { [string]: any } })
	local msgType = message.type
	local data = message.data or {}

	if msgType == "CHARACTER_SELECT" then
		-- Iniciar selecao
		print("[TheBrokenBox] CharacterSelectUI: Iniciando selecao de personagem...")
		_isSelecting = true
		_characterLocked = false
		_selectedCharacter = nil

		createUI()

		if _selectButton then
			_selectButton.Visible = false
		end
		if _statusLabel then
			_statusLabel.Text = "Escolha seu personagem!"
			_statusLabel.TextColor3 = COLORS.TEXT
		end

	elseif msgType == "YOUR_CHARACTER" then
		-- Personagem confirmado pelo servidor
		local characterClass = data.characterClass
		local isHunter = data.isHunter

		print("[TheBrokenBox] CharacterSelectUI: Personagem confirmado - " .. tostring(characterClass) .. " (Hunter: " .. tostring(isHunter) .. ")")
		_characterLocked = true
		_selectedCharacter = characterClass
		_isSelecting = false

		if _statusLabel then
			_statusLabel.Text = "PERSONAGEM CONFIRMADO: " .. tostring(characterClass)
			_statusLabel.TextColor3 = COLORS.FREE
		end

		if _selectButton then
			_selectButton.Visible = false
		end

	elseif msgType == "CHARACTER_SELECTED" then
		-- Outro jogador selecionou (feedback visual opcional)
		local otherClass = data.characterClass
		print("[TheBrokenBox] CharacterSelectUI: Outro jogador selecionou " .. tostring(otherClass))
	end
end

-- ============================================================
-- Busca dos RemoteEvents (via IsA)
-- ============================================================

--[[
  Encontra RemoteEvents em ReplicatedStorage.Events usando IsA("RemoteEvent").
  Convencao para client-side: buscar a instancia RemoteEvent, nao o ModuleScript.
]]
local function findRemoteEvents(): ()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[TheBrokenBox] CharacterSelectUI: Pasta Events nao encontrada em ReplicatedStorage")
		return
	end

	for _, child in ipairs(eventsFolder:GetChildren()) do
		if child:IsA("RemoteEvent") then
			if child.Name == "PlayerActionEvent" then
				_playerActionEvent = child :: RemoteEvent
				print("[TheBrokenBox] CharacterSelectUI: PlayerActionEvent encontrado.")
			elseif child.Name == "GameStateEvent" then
				_gameStateEvent = child :: RemoteEvent
				print("[TheBrokenBox] CharacterSelectUI: GameStateEvent encontrado.")
			end
		end
	end

	if not _playerActionEvent then
		warn("[TheBrokenBox] CharacterSelectUI: PlayerActionEvent (RemoteEvent) nao encontrado!")
	end
	if not _gameStateEvent then
		warn("[TheBrokenBox] CharacterSelectUI: GameStateEvent (RemoteEvent) nao encontrado!")
	end
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): busca RemoteEvents e prepara estruturas.
]]
function CharacterSelectUI.Init(): ()
	print("[TheBrokenBox] CharacterSelectUI.Init()")

	findRemoteEvents()

	-- Conectar ao GameStateEvent se disponivel
	if _gameStateEvent then
		_gameStateConnection = _gameStateEvent.OnClientEvent:Connect(onGameStateMessage)
		print("[TheBrokenBox] CharacterSelectUI: Listener do GameStateEvent conectado.")
	else
		warn("[TheBrokenBox] CharacterSelectUI: GameStateEvent nao disponivel. UI nao respondera ao servidor.")
	end
end

--[[
  Start(): cria a UI ou aguarda o sinal do servidor.
]]
function CharacterSelectUI.Start(): ()
	print("[TheBrokenBox] CharacterSelectUI.Start() - aguardando fase de selecao...")

	-- A UI sera criada quando o servidor enviar CHARACTER_SELECT
	-- via GameStateEvent. Se o evento ja foi recebido antes do Start,
	-- a UI ja tera sido criada em Init().

	-- Para testes: criar UI imediatamente se estamos em modo local
	-- (descomentar para testar sem servidor):
	-- if not _screenGui then
	-- 	createUI()
	-- end
end

--[[
  Destroi a UI (chamado ao trocar de tela).
]]
function CharacterSelectUI.destroy(): ()
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end
	_mainFrame = nil
	_characterFrames = {}
	_selectButton = nil
	_statusLabel = nil
	_selectedCharacter = nil
	_characterLocked = false
	_isSelecting = false
end

return CharacterSelectUI
