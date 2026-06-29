--!strict
--[[
  GameOverUI.lua
  Interface de fim de partida (client-side).
  Exibe tela de VITORIA ou DERROTA com estatisticas e moedas ganhas.

  Escuta GameStateEvent para MATCH_ENDED.
  Botao "Voltar ao Lobby" dispara RETURN_TO_LOBBY via PlayerActionEvent.

  Referencias: GDD Condicoes de Vitoria e Derrota, E6-S4
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local GameConstants = require(ReplicatedStorage.GameConstants)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local GameOverUI = {}

-- ============================================================
-- Referencias de UI
-- ============================================================
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local resultLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local coinsLabel: TextLabel? = nil
local statsFrame: Frame? = nil
local returnButton: TextButton? = nil
local statsContainer: Frame? = nil

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
  Cria a ScreenGui da tela de Game Over.
  Inicialmente escondida, exibida no MATCH_ENDED.
]]
local function createUI(): ()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameOverUI"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Overlay escuro de fundo
	local overlay = createElement("Frame", screenGui, {
		Name = "Overlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 7/10,
		BorderSizePixel = 0,
		ZIndex = 10,
	})

	-- Frame principal centralizado
	mainFrame = createElement("Frame", overlay, {
		Name = "MainFrame",
		Size = UDim2.new(0, 400, 0, 350),
		Position = UDim2.new(5/10, -200, 5/10, -175),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = 1/10,
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(100, 100, 120),
		ZIndex = 11,
	})

	-- Padding interno
	createElement("UIPadding", mainFrame, {
		PaddingTop = UDim.new(0, 20),
		PaddingBottom = UDim.new(0, 20),
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
	})

	-- Layout vertical
	local layout = createElement("UIListLayout", mainFrame, {
		Name = "Layout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	-- Titulo do resultado (VITORIA / DERROTA)
	resultLabel = createElement("TextLabel", mainFrame, {
		Name = "ResultLabel",
		Size = UDim2.new(1, 0, 0, 50),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 215, 0),
		TextSize = 36,
		Font = Enum.Font.SourceSansBold,
		TextStrokeTransparency = 5/10,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		ZIndex = 12,
	})

	-- Subtitulo (Fuga Total / Fuga Parcial / Contencao)
	subtitleLabel = createElement("TextLabel", mainFrame, {
		Name = "SubtitleLabel",
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextSize = 18,
		Font = Enum.Font.SourceSans,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 12,
	})

	-- Separador
	local separator1 = createElement("Frame", mainFrame, {
		Name = "Separator1",
		Size = UDim2.new(8/10, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(80, 80, 100),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		ZIndex = 12,
	})

	-- Moedas ganhas
	coinsLabel = createElement("TextLabel", mainFrame, {
		Name = "CoinsLabel",
		Size = UDim2.new(1, 0, 0, 36),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 220, 50),
		TextSize = 22,
		Font = Enum.Font.SourceSansBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		ZIndex = 12,
	})

	-- Separador
	local separator2 = createElement("Frame", mainFrame, {
		Name = "Separator2",
		Size = UDim2.new(8/10, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(80, 80, 100),
		BorderSizePixel = 0,
		LayoutOrder = 5,
		ZIndex = 12,
	})

	-- Estatisticas
	statsContainer = createElement("Frame", mainFrame, {
		Name = "StatsContainer",
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		ZIndex = 12,
	})

	local statsLayout = createElement("UIListLayout", statsContainer, {
		Name = "StatsLayout",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	-- Botao Voltar ao Lobby
	returnButton = createElement("TextButton", mainFrame, {
		Name = "ReturnButton",
		Size = UDim2.new(6/10, 0, 0, 44),
		Text = "VOLTAR AO LOBBY",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
		Font = Enum.Font.SourceSansBold,
		BackgroundColor3 = Color3.fromRGB(60, 60, 180),
		BorderSizePixel = 0,
		LayoutOrder = 7,
		ZIndex = 12,
	})

	-- Efeito hover no botao
	returnButton.MouseEnter:Connect(function()
		returnButton.BackgroundColor3 = Color3.fromRGB(80, 80, 220)
	end)
	returnButton.MouseLeave:Connect(function()
		returnButton.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
	end)

	-- Clique no botao
	returnButton.MouseButton1Click:Connect(function()
		onReturnToLobby()
	end)

	print("[TheBrokenBox] GameOverUI: UI criada (oculta).")
end

-- ============================================================
-- Atualizacao da UI
-- ============================================================

--[[
  Exibe a tela de Game Over com os dados da partida.
]]
local function showGameOver(data: { winner: string, result: string, rewards: {any}? }): ()
	if not screenGui then
		return
	end

	local isVictory = (data.winner == "Survivors")
	local resultType = data.result or "Contencao"

	-- Titulo
	if resultLabel then
		if isVictory then
			resultLabel.Text = "VITORIA!"
			resultLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			resultLabel.Text = "DERROTA"
			resultLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
		end
	end

	-- Subtitulo
	if subtitleLabel then
		if resultType == "FugaTotal" then
			subtitleLabel.Text = "Fuga Total - Todos escaparam!"
		elseif resultType == "FugaParcial" then
			subtitleLabel.Text = "Fuga Parcial - Pelo menos 1 escapou"
		else
			subtitleLabel.Text = "Contencao Total - Ninguem escapou"
		end
	end

	-- Moedas
	local coinReward = 0
	if data.rewards then
		for _, reward in ipairs(data.rewards) do
			if reward.userId == LocalPlayer.UserId then
				coinReward = reward.coins or 0
				break
			end
		end
	end

	if coinsLabel then
		if isVictory and coinReward > 0 then
			coinsLabel.Text = "+" .. tostring(coinReward) .. " Moedas"
			coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
		elseif isVictory then
			coinsLabel.Text = "Sobreviveu!"
			coinsLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
		else
			coinsLabel.Text = "Voce nao sobreviveu"
			coinsLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
		end
	end

	-- Estatisticas
	-- Limpar estatisticas anteriores
	if statsContainer then
		for _, child in ipairs(statsContainer:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	-- Criar labels de estatisticas
	local stats: { string } = {}

	if data.stats then
		if data.stats.missionsDone then
			table.insert(stats, "Missoes concluidas: " .. tostring(data.stats.missionsDone))
		end
		if data.stats.escapes then
			table.insert(stats, "Sobreviventes escaparam: " .. tostring(data.stats.escapes))
		end
		if data.stats.kills then
			table.insert(stats, "Mortes do Cacador: " .. tostring(data.stats.kills))
		end
		if data.stats.survivorClass then
			table.insert(stats, "Classe: " .. tostring(data.stats.survivorClass))
		end
	end

	if #stats == 0 then
		table.insert(stats, "A partida terminou")
	end

	for _, statText in ipairs(stats) do
		createElement("TextLabel", statsContainer, {
			Name = "StatLabel",
			Size = UDim2.new(1, 0, 0, 20),
			Text = statText,
			TextColor3 = Color3.fromRGB(180, 180, 190),
			TextSize = 14,
			Font = Enum.Font.SourceSans,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
			ZIndex = 12,
		})
	end

	-- Exibir a UI
	screenGui.Enabled = true

	print("[TheBrokenBox] GameOverUI: Tela exibida - " .. (isVictory and "VITORIA" or "DERROTA"))
end

--[[
  Esconde a tela de Game Over.
]]
local function hideGameOver(): ()
	if screenGui then
		screenGui.Enabled = false
	end
end

-- ============================================================
-- Handlers
-- ============================================================

--[[
  Chamado quando o jogador clica em "Voltar ao Lobby".
  Dispara RETURN_TO_LOBBY via PlayerActionEvent.
]]
local function onReturnToLobby(): ()
	print("[TheBrokenBox] GameOverUI: Solicitando retorno ao Lobby...")

	-- Encontrar PlayerActionEvent
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if not eventsFolder then
		warn("[TheBrokenBox] GameOverUI: Pasta Events nao encontrada")
		return
	end

	-- Buscar RemoteEvent PlayerActionEvent
	local playerActionEvent: RemoteEvent? = nil
	for _, child in ipairs(eventsFolder:GetChildren()) do
		if child:IsA("RemoteEvent") and child.Name == "PlayerActionEvent" then
			playerActionEvent = child :: RemoteEvent
			break
		end
	end

	if not playerActionEvent then
		warn("[TheBrokenBox] GameOverUI: PlayerActionEvent RemoteEvent nao encontrado")
		return
	end

	-- Disparar RETURN_TO_LOBBY
	RemoteEventUtils.fireServer(playerActionEvent, "RETURN_TO_LOBBY", {})

	-- Esconder a UI
	hideGameOver()

	print("[TheBrokenBox] GameOverUI: RETURN_TO_LOBBY enviado.")
end

--[[
  Processa mensagens do GameStateEvent.
]]
local function onGameStateMessage(message: {any}): ()
	local msgType = message.type
	local data = message.data

	if msgType == "MATCH_ENDED" then
		print("[TheBrokenBox] GameOverUI: MATCH_ENDED recebido - " .. tostring(data.winner))
		showGameOver(data)
	end
end

-- ============================================================
-- Init/Start
-- ============================================================

--[[
  Init(): setup sincrono da UI.
]]
function GameOverUI.Init(): ()
	print("[TheBrokenBox] GameOverUI.Init()")
	createUI()
end

--[[
  Start(): registro de listeners.
]]
function GameOverUI.Start(): ()
	print("[TheBrokenBox] GameOverUI.Start() - registrando listeners...")

	-- Encontrar eventos em ReplicatedStorage
	local eventsFolder = ReplicatedStorage:WaitForChild("Events")
	if not eventsFolder then
		warn("[TheBrokenBox] GameOverUI: Pasta Events nao encontrada")
		return
	end

	-- Escutar GameStateEvent (RemoteEvent server -> client)
	local gameStateEvent: RemoteEvent? = nil
	for _, child in ipairs(eventsFolder:GetChildren()) do
		if child:IsA("RemoteEvent") and child.Name == "GameStateEvent" then
			gameStateEvent = child :: RemoteEvent
			break
		end
	end

	if not gameStateEvent then
		warn("[TheBrokenBox] GameOverUI: RemoteEvent GameStateEvent nao encontrado")
		return
	end

	gameStateEvent.OnClientEvent:Connect(onGameStateMessage)

	print("[TheBrokenBox] GameOverUI.Start() concluido.")
end

return GameOverUI
