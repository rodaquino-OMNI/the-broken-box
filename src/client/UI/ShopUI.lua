--!strict
--[[
  ShopUI.lua
  UI da loja "A Caixa" (client-side).
  Exibe O Vendedor e a interface de compra de personagens.
  Mostra saldo de moedas, personagens bloqueados/desbloqueados.
  Envia BUY_UNLOCK via PlayerActionEvent ao comprar.

  Usa script.Parent para requires (convencao Rojo).
  Usa IsA("RemoteEvent") para encontrar RemoteEvents em ReplicatedStorage.

  Referencias: GDD Progressao de Jogador, Lobby — A Caixa
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)

local ShopUI = {}

-- ============================================================
-- Cores e estilo (retraux — consistente com CharacterSelectUI)
-- ============================================================
local COLORS = {
	BG = Color3.fromRGB(15, 15, 20),
	PANEL = Color3.fromRGB(25, 25, 35),
	TITLE = Color3.fromRGB(220, 200, 140),        -- Dourado/amber
	TEXT = Color3.fromRGB(200, 200, 210),
	FREE = Color3.fromRGB(100, 200, 120),         -- Verde = gratuito
	PAID = Color3.fromRGB(200, 180, 60),          -- Dourado = pago
	LOCKED = Color3.fromRGB(120, 120, 120),       -- Cinza = bloqueado
	UNLOCKED = Color3.fromRGB(100, 200, 120),    -- Verde = desbloqueado
	BUTTON_BG = Color3.fromRGB(40, 40, 55),
	BUTTON_HOVER = Color3.fromRGB(60, 60, 80),
	BUTTON_LOCKED = Color3.fromRGB(35, 35, 35),
	BUTTON_BUY = Color3.fromRGB(200, 160, 40),    -- Botao de comprar (dourado escuro)
	COIN = Color3.fromRGB(240, 200, 60),          -- Dourado vivo para moedas
	SELECTED_BORDER = Color3.fromRGB(220, 200, 140),
}

-- ============================================================
-- Estado interno
-- ============================================================
local _screenGui: ScreenGui? = nil
local _mainFrame: Frame? = nil
local _titleLabel: TextLabel? = nil
local _coinLabel: TextLabel? = nil
local _characterFrames: { Frame } = {}
local _statusLabel: TextLabel? = nil

-- Estado do jogador (sincronizado via UISyncEvent)
local _coins: number = 0
local _unlockedCharacters: { string } = {}

-- RemoteEvents (descobertos via IsA)
local _playerActionEvent: RemoteEvent? = nil
local _uiSyncEvent: RemoteEvent? = nil
local _uiSyncConnection: RBXScriptConnection? = nil

-- ============================================================
-- Dados dos personagens (locais, para exibicao)
-- ============================================================

type CharacterInfo = {
	class: string,
	name: string,
	role: string,
	free: boolean,
	unlocked: boolean,
	price: number,
	description: string,
}

--[[
  Retorna a lista de personagens disponiveis na loja.
  Personagens gratuitos sempre aparecem como unlocked.
]]
local function getShopCharacters(): { CharacterInfo }
	local chars = {}

	-- Cacador (sempre gratuito)
	table.insert(chars, {
		class = "Distorcido",
		name = GameConstants.Hunter.NAME,
		role = "Hunter",
		free = true,
		unlocked = true,
		price = 0,
		description = "O Cacador — criatura sobrenatural (HP 2000)",
	})

	-- Sobreviventes gratuitos
	table.insert(chars, {
		class = "Sackboy",
		name = GameConstants.Survivors.SACKBOY.NAME,
		role = "Survivor",
		free = true,
		unlocked = true,
		price = 0,
		description = "Hit & Run / Controle (HP " .. GameConstants.Survivors.SACKBOY.MAX_HP .. ")",
	})
	table.insert(chars, {
		class = "Medico",
		name = GameConstants.Survivors.MEDICO.NAME,
		role = "Survivor",
		free = true,
		unlocked = true,
		price = 0,
		description = "Suporte/Cura (HP " .. GameConstants.Survivors.MEDICO.MAX_HP .. ")",
	})

	-- Sobreviventes pagos
	local paidChars = {
		{ key = "SOLDADO", class = GameConstants.Survivors.SOLDADO.NAME or "Soldado", hp = GameConstants.Survivors.SOLDADO.MAX_HP },
		{ key = "ROBO", class = GameConstants.Survivors.ROBO.NAME or "Robo", hp = GameConstants.Survivors.ROBO.MAX_HP },
	}
	local prices = {
		[paidChars[1].class] = GameConstants.Economy.UNLOCK_COST_SOLDADO,
		[paidChars[2].class] = GameConstants.Economy.UNLOCK_COST_ROBO,
	}

	for _, pc in ipairs(paidChars) do
		local characterClass = pc.class
		local isUnlocked = false
		for _, unlockedName in ipairs(_unlockedCharacters) do
			if unlockedName == characterClass then
				isUnlocked = true
				break
			end
		end

		local config = GameConstants.Survivors[pc.key]
		table.insert(chars, {
			class = characterClass,
			name = characterClass,
			role = "Survivor",
			free = false,
			unlocked = isUnlocked,
			price = prices[characterClass] or (pc.key == "SOLDADO" and GameConstants.Economy.UNLOCK_COST_SOLDADO or GameConstants.Economy.UNLOCK_COST_ROBO),
			description = (config and config.ROLE or "") .. " (HP " .. pc.hp .. ")",
		})
	end

	return chars
end

-- ============================================================
-- Atualizacao de estado
-- ============================================================

--[[
  Atualiza o saldo de moedas no display.
]]
local function updateCoinDisplay(): ()
	if _coinLabel then
		_coinLabel.Text = "" .. _coins .. " MOEDAS"
	end
end

--[[
  Atualiza a UI com novos dados (chamado via UISyncEvent).
]]
local function refreshUI(): ()
	if not _mainFrame then
		return
	end

	updateCoinDisplay()

	-- Reconstruir botoes de personagens
	for _, frame in ipairs(_characterFrames) do
		frame:Destroy()
	end
	_characterFrames = {}

	-- Encontrar o container de personagens
	local charContainer = _mainFrame:FindFirstChild("CharContainer")
	if not charContainer then
		return
	end

	-- Verificar se ha um botao de fechar para remover
	local existingClose = _mainFrame:FindFirstChild("CloseButton")
	if existingClose then
		existingClose:Destroy()
	end

	local characters = getShopCharacters()
	for i, char in ipairs(characters) do
		local frame = createShopButton(charContainer :: Frame, char, i)
		table.insert(_characterFrames, frame)
	end

	-- Atualizar canvas size do ScrollingFrame
	if charContainer:IsA("ScrollingFrame") then
		charContainer.CanvasSize = UDim2.new(0, 0, 0, #characters * 75 + 10)
	end
end

-- ============================================================
-- Construcao da UI
-- ============================================================

--[[
  Cria um botao de personagem na loja.
]]
local function createShopButton(parent: Frame, char: CharacterInfo, index: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = "ShopCharFrame_" .. char.class
	frame.Size = UDim2.new(1, -20, 0, 65)
	frame.Position = UDim2.new(0, 10, 0, 8 + (index - 1) * 75)
	frame.BackgroundColor3 = char.unlocked and COLORS.BUTTON_BG or COLORS.BUTTON_LOCKED
	frame.BorderSizePixel = 1
	frame.BorderColor3 = Color3.fromRGB(60, 60, 80)
	frame.Parent = parent

	-- Nome do personagem
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 150, 0, 22)
	nameLabel.Position = UDim2.new(0, 10, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = char.name
	nameLabel.TextColor3 = char.unlocked and COLORS.UNLOCKED or COLORS.LOCKED
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	-- Descricao (role)
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(0, 150, 0, 16)
	descLabel.Position = UDim2.new(0, 10, 0, 26)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = char.description
	descLabel.TextColor3 = char.unlocked and COLORS.TEXT or COLORS.LOCKED
	descLabel.Font = Enum.Font.SourceSans
	descLabel.TextSize = 11
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = frame

	-- Tag de status
	local tagText: string
	local tagColor: Color3
	if char.free then
		tagText = "GRATIS"
		tagColor = COLORS.FREE
	elseif char.unlocked then
		tagText = "DESBLOQUEADO"
		tagColor = COLORS.UNLOCKED
	else
		tagText = "" .. char.price .. " Moedas"
		tagColor = COLORS.PAID
	end

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Name = "TagLabel"
	tagLabel.Size = UDim2.new(0, 100, 0, 20)
	tagLabel.Position = UDim2.new(1, -110, 0, 4)
	tagLabel.BackgroundTransparency = 0.5
	tagLabel.BackgroundColor3 = tagColor
	tagLabel.Text = tagText
	tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tagLabel.Font = Enum.Font.SourceSansBold
	tagLabel.TextSize = 11
	tagLabel.Parent = frame

	-- Botao de compra (apenas para personagens pagos nao desbloqueados)
	if not char.free and not char.unlocked then
		local buyButton = Instance.new("TextButton")
		buyButton.Name = "BuyButton"
		buyButton.Size = UDim2.new(0, 90, 0, 26)
		buyButton.Position = UDim2.new(1, -110, 0, 28)
		buyButton.BackgroundColor3 = COLORS.BUTTON_BUY
		buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyButton.Font = Enum.Font.SourceSansBold
		buyButton.TextSize = 13
		buyButton.Text = "COMPRAR"
		buyButton.Parent = frame

		-- Tooltip de preco no hover
		buyButton.MouseEnter:Connect(function()
			buyButton.Text = "" .. char.price .. " COMPRAR"
			buyButton.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
		end)
		buyButton.MouseLeave:Connect(function()
			buyButton.Text = "COMPRAR"
			buyButton.BackgroundColor3 = COLORS.BUTTON_BUY
		end)

		-- Clique para comprar
		buyButton.MouseButton1Click:Connect(function()
			if not _playerActionEvent then
				warn("[TheBrokenBox] ShopUI: PlayerActionEvent nao encontrado!")
				return
			end

			if _coins < char.price then
				if _statusLabel then
					_statusLabel.Text = "Moedas insuficientes! (Precisa: " .. char.price .. ", Tem: " .. _coins .. ")"
					_statusLabel.TextColor3 = COLORS.LOCKED
				end
				return
			end

			-- Enviar solicitacao de compra ao servidor
			_playerActionEvent:FireServer({
				type = "BUY_UNLOCK",
				data = {
					characterClass = char.class,
				},
			})

			print("[TheBrokenBox] ShopUI: Solicitando compra — " .. char.class .. " (" .. char.price .. " moedas)")

			if _statusLabel then
				_statusLabel.Text = "Comprando " .. char.name .. "..."
				_statusLabel.TextColor3 = COLORS.PAID
			end
		end)
	end

	return frame
end

--[[
  Cria a ScreenGui completa da loja.
]]
local function createUI(): ()
	-- Remover UI anterior se existir
	if _screenGui then
		_screenGui:Destroy()
	end

	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "ShopUI"
	_screenGui.ResetOnSpawn = false
	_screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Frame principal (centralizado)
	_mainFrame = Instance.new("Frame")
	_mainFrame.Name = "MainFrame"
	_mainFrame.Size = UDim2.new(0, 360, 0, 440)
	_mainFrame.Position = UDim2.new(0.5, -180, 0.5, -220)
	_mainFrame.BackgroundColor3 = COLORS.PANEL
	_mainFrame.BorderSizePixel = 2
	_mainFrame.BorderColor3 = COLORS.TITLE
	_mainFrame.Parent = _screenGui

	-- Titulo
	_titleLabel = Instance.new("TextLabel")
	_titleLabel.Name = "TitleLabel"
	_titleLabel.Size = UDim2.new(1, -20, 0, 36)
	_titleLabel.Position = UDim2.new(0, 10, 0, 8)
	_titleLabel.BackgroundTransparency = 1
	_titleLabel.Text = "A CAIXA — O VENDEDOR"
	_titleLabel.TextColor3 = COLORS.TITLE
	_titleLabel.Font = Enum.Font.SourceSansBold
	_titleLabel.TextSize = 18
	_titleLabel.Parent = _mainFrame

	-- Saldo de moedas
	_coinLabel = Instance.new("TextLabel")
	_coinLabel.Name = "CoinLabel"
	_coinLabel.Size = UDim2.new(1, -40, 0, 28)
	_coinLabel.Position = UDim2.new(0, 20, 0, 46)
	_coinLabel.BackgroundTransparency = 0.7
	_coinLabel.BackgroundColor3 = COLORS.BG
	_coinLabel.Text = "" .. _coins .. " MOEDAS"
	_coinLabel.TextColor3 = COLORS.COIN
	_coinLabel.Font = Enum.Font.SourceSansBold
	_coinLabel.TextSize = 16
	_coinLabel.Parent = _mainFrame

	-- Container dos personagens (scroll)
	local charContainer = Instance.new("ScrollingFrame")
	charContainer.Name = "CharContainer"
	charContainer.Size = UDim2.new(1, -20, 0, 300)
	charContainer.Position = UDim2.new(0, 10, 0, 80)
	charContainer.BackgroundTransparency = 0.8
	charContainer.BackgroundColor3 = COLORS.BG
	charContainer.BorderSizePixel = 1
	charContainer.ScrollBarThickness = 6
	charContainer.CanvasSize = UDim2.new(0, 0, 0, 400)
	charContainer.Parent = _mainFrame

	-- Criar botoes de personagens
	local characters = getShopCharacters()
	_characterFrames = {}
	for i, char in ipairs(characters) do
		local frame = createShopButton(charContainer, char, i)
		table.insert(_characterFrames, frame)
	end

	-- Status / feedback
	_statusLabel = Instance.new("TextLabel")
	_statusLabel.Name = "StatusLabel"
	_statusLabel.Size = UDim2.new(1, -20, 0, 22)
	_statusLabel.Position = UDim2.new(0, 10, 1, 10)
	_statusLabel.BackgroundTransparency = 1
	_statusLabel.Text = "Bem-vindo a loja! Complete missoes para ganhar moedas."
	_statusLabel.TextColor3 = COLORS.TEXT
	_statusLabel.Font = Enum.Font.SourceSans
	_statusLabel.TextSize = 12
	_statusLabel.Parent = _mainFrame

	-- Atualizar display de moedas
	updateCoinDisplay()
end

-- ============================================================
-- Eventos de rede
-- ============================================================

--[[
  Callback do UISyncEvent (Servidor -> Cliente).
  Processa mensagens:
    - COINS_UPDATED: atualiza saldo de moedas
    - CHARACTER_UNLOCKED: personagem desbloqueado
    - SHOP_OPEN: abre a loja
    - SHOP_CLOSE: fecha a loja
]]
local function onUISyncMessage(message: { type: string, data: { [string]: any } })
	local msgType = message.type
	local data = message.data or {}

	if msgType == "SHOP_OPEN" then
		-- Abrir loja
		print("[TheBrokenBox] ShopUI: Abrindo loja A Caixa...")

		-- Carregar dados do jogador se fornecidos
		if data.coins ~= nil then
			_coins = data.coins
		end
		if data.unlockedCharacters then
			_unlockedCharacters = data.unlockedCharacters
		end

		createUI()

	elseif msgType == "COINS_UPDATED" then
		-- Atualizar saldo
		if data.coins ~= nil then
			_coins = data.coins
			updateCoinDisplay()
			print("[TheBrokenBox] ShopUI: Moedas atualizadas: " .. _coins)
		end

		-- Atualizar tambem dados de desbloqueio se fornecidos
		if data.unlockedCharacters then
			_unlockedCharacters = data.unlockedCharacters
		end

		-- Recriar botoes para refletir o novo estado
		refreshUI()

	elseif msgType == "CHARACTER_UNLOCKED" then
		-- Personagem desbloqueado
		local unlockedClass = data.characterClass
		if unlockedClass then
			local alreadyThere = false
			for _, name in ipairs(_unlockedCharacters) do
				if name == unlockedClass then
					alreadyThere = true
					break
				end
			end
			if not alreadyThere then
				table.insert(_unlockedCharacters, unlockedClass)
			end

			print("[TheBrokenBox] ShopUI: Personagem desbloqueado: " .. unlockedClass)

			if _statusLabel then
				_statusLabel.Text = "" .. unlockedClass .. " DESBLOQUEADO! Parabens!"
				_statusLabel.TextColor3 = COLORS.UNLOCKED
			end

			-- Atualizar moedas se fornecidas
			if data.coins ~= nil then
				_coins = data.coins
				updateCoinDisplay()
			end

			refreshUI()
		end

	elseif msgType == "SHOP_CLOSE" then
		-- Fechar loja
		print("[TheBrokenBox] ShopUI: Fechando loja.")
		ShopUI.destroy()
	end
end

-- ============================================================
-- Busca dos RemoteEvents (via IsA)
-- ============================================================

--[[
  Encontra RemoteEvents em ReplicatedStorage.Events usando IsA("RemoteEvent").
]]
local function findRemoteEvents(): ()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[TheBrokenBox] ShopUI: Pasta Events nao encontrada em ReplicatedStorage")
		return
	end

	for _, child in ipairs(eventsFolder:GetChildren()) do
		if child:IsA("RemoteEvent") then
			if child.Name == "PlayerActionEvent" then
				_playerActionEvent = child :: RemoteEvent
				print("[TheBrokenBox] ShopUI: PlayerActionEvent encontrado.")
			elseif child.Name == "UISyncEvent" then
				_uiSyncEvent = child :: RemoteEvent
				print("[TheBrokenBox] ShopUI: UISyncEvent encontrado.")
			end
		end
	end

	if not _playerActionEvent then
		warn("[TheBrokenBox] ShopUI: PlayerActionEvent (RemoteEvent) nao encontrado!")
	end
	if not _uiSyncEvent then
		warn("[TheBrokenBox] ShopUI: UISyncEvent (RemoteEvent) nao encontrado!")
	end
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): busca RemoteEvents e prepara estruturas.
]]
function ShopUI.Init(): ()
	print("[TheBrokenBox] ShopUI.Init()")

	findRemoteEvents()

	-- Conectar ao UISyncEvent se disponivel
	if _uiSyncEvent then
		_uiSyncConnection = _uiSyncEvent.OnClientEvent:Connect(onUISyncMessage)
		print("[TheBrokenBox] ShopUI: Listener do UISyncEvent conectado.")
	else
		warn("[TheBrokenBox] ShopUI: UISyncEvent nao disponivel. UI nao respondera ao servidor.")
	end
end

--[[
  Start(): aguarda o servidor abrir a loja.
]]
function ShopUI.Start(): ()
	print("[TheBrokenBox] ShopUI.Start() — aguardando abertura da loja...")
	-- A UI sera criada quando o servidor enviar SHOP_OPEN via UISyncEvent.
end

--[[
  Destroi a UI.
]]
function ShopUI.destroy(): ()
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end
	_mainFrame = nil
	_titleLabel = nil
	_coinLabel = nil
	_characterFrames = {}
	_statusLabel = nil
end

return ShopUI
