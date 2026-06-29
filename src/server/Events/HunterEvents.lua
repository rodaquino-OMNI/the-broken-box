--!strict
--[[
  HunterEvents.lua
  Handlers de eventos do Cacador no servidor.
  Escuta PlayerActionEvent para inputs do Cacador:
    - HUNTER_M1, HUNTER_PULL, HUNTER_ROAR, HUNTER_RAGE

  Validacao:
    - Cooldown, vivo, nao stunado
    - Nao pode ativar Rage durante fase de Fuga
    - So processa se o jogador for o Cacador

  Referencias: GDD M5-M7, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local HunterEvents = {}

-- ============================================================
-- Referencias a servicos (injetadas pelo GameManager)
-- ============================================================
local HunterService = nil
local MatchService = nil

-- ============================================================
-- Conexao do RemoteEvent
-- ============================================================
local _remoteEvent: RemoteEvent? = nil
local _remoteConnection: RBXScriptConnection? = nil

-- ============================================================
-- Handlers de input do Cacador
-- ============================================================

--[[
  Processa uma mensagem do PlayerActionEvent.
  Chamado quando o servidor recebe um evento do cliente.
]]
local function onPlayerAction(player: Player, message: {any})
	if not HunterService then return end
	if not MatchService then return end

	-- Verificar se o jogador e o Cacador
	if not HunterService.isHunter(player) then
		return -- Nao e o Cacador, ignora inputs de Hunter
	end

	-- Verificar se o Cacador esta vivo
	local data = MatchService.getPlayerData(player)
	if not data or not data.isAlive then
		return
	end

	local msgType = message.type
	local msgData = message.data

	-- ============================================================
	-- HUNTER_M1 - Tapa (ataque basico)
	-- ============================================================
	if msgType == PlayerActionEvent.MESSAGES.HUNTER_M1 then
		print("[TheBrokenBox] HunterEvents: HUNTER_M1 de " .. player.Name)

		-- Validacao de cooldown/stun e feita dentro de HunterService.performM1()
		HunterService.performM1()
		return
	end

	-- ============================================================
	-- HUNTER_PULL - Braco Esticado
	-- ============================================================
	if msgType == PlayerActionEvent.MESSAGES.HUNTER_PULL then
		print("[TheBrokenBox] HunterEvents: HUNTER_PULL de " .. player.Name)

		-- Extrair direcao do olhar
		local aimDirection: Vector3 = Vector3.new(0, 0, -1) -- Padrao: frente
		if msgData and msgData.aimDirection then
			aimDirection = msgData.aimDirection
		else
			-- Usar direcao do personagem
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					aimDirection = rootPart.CFrame.LookVector
				end
			end
		end

		HunterService.performPull(aimDirection)
		return
	end

	-- ============================================================
	-- HUNTER_ROAR - Grito
	-- ============================================================
	if msgType == PlayerActionEvent.MESSAGES.HUNTER_ROAR then
		print("[TheBrokenBox] HunterEvents: HUNTER_ROAR de " .. player.Name)

		HunterService.performRoar()
		return
	end

	-- ============================================================
	-- HUNTER_RAGE - Ativar Rage
	-- ============================================================
	if msgType == PlayerActionEvent.MESSAGES.HUNTER_RAGE then
		print("[TheBrokenBox] HunterEvents: HUNTER_RAGE de " .. player.Name)

		-- Validacao da fase de Fuga
		local matchState = MatchService.getMatchState()
		if matchState == "Escaping" then
			warn("[TheBrokenBox] HunterEvents: Rage nao pode ser ativado durante a Fuga!")
			return
		end

		HunterService.activateRageWindup()
		return
	end

	-- Inputs nao reconhecidos ou de Sobrevivente sao ignorados silenciosamente
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): encontra o RemoteEvent de PlayerAction.
]]
function HunterEvents.Init(): ()
	print("[TheBrokenBox] HunterEvents.Init()")

	-- Encontrar o RemoteEvent em ReplicatedStorage.Events
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_remoteEvent = RemoteEventUtils.findRemoteEvent(eventsFolder, PlayerActionEvent.NAME)
	end

	if not _remoteEvent then
		warn("[TheBrokenBox] HunterEvents: PlayerActionEvent nao encontrado! Criando...")
		-- Criar se nao existir (para testes)
		if eventsFolder then
			_remoteEvent = RemoteEventUtils.createRemoteEvent(eventsFolder, PlayerActionEvent.NAME)
			print("[TheBrokenBox] HunterEvents: PlayerActionEvent criado em ReplicatedStorage.Events.")
		end
	end
end

--[[
  Start(): conecta o listener OnServerEvent.
]]
function HunterEvents.Start(): ()
	print("[TheBrokenBox] HunterEvents.Start() - registrando listener do PlayerActionEvent...")

	if not _remoteEvent then
		warn("[TheBrokenBox] HunterEvents: PlayerActionEvent nao disponivel! Inputs do Cacador NAO serao processados.")
		return
	end

	-- Conectar ao evento de servidor
	_remoteConnection = _remoteEvent.OnServerEvent:Connect(onPlayerAction)

	-- Limpar quando o jogo fecha
	game:BindToClose(function()
		if _remoteConnection then
			_remoteConnection:Disconnect()
			_remoteConnection = nil
		end
	end)

	print("[TheBrokenBox] HunterEvents pronto. Escutando inputs do Cacador...")
end

-- ============================================================
-- Injecao de dependencias
-- ============================================================

--[[
  Injeta referencias aos servicos necessarios.
  Chamado pelo GameManager durante wireServiceSignals().
]]
function HunterEvents.injectDependencies(
	hunterSvc: {},
	matchSvc: {}
): ()
	HunterService = hunterSvc
	MatchService = matchSvc
	print("[TheBrokenBox] HunterEvents: Dependencias injetadas.")
end

return HunterEvents
