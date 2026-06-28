--!strict
--[[
  LobbyService.lua
  Servico de dominio que gerencia o lobby A Caixa:
    - Estado do lobby (gathering, selecting, preparing)
    - Fluxo de selecao de personagem
    - Atribuicao de papeis (Hunter/Survivor)
    - Controle de inicio de partida (minimo 2 jogadores)

  Sinais expostos:
    lobbyReady      — quando o lobby esta pronto para comecar
    characterSelected — quando um jogador seleciona personagem

  Init/Start pattern.
  Referencias: GDD Lobby — A Caixa, architecture.md 11.9
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

local LobbyService = {}
LobbyService.Name = "LobbyService"

-- ============================================================
-- Sinais do servico
-- ============================================================
LobbyService.lobbyReady = Signal.new()         -- ()
LobbyService.characterSelected = Signal.new()  -- (player: Player, characterClass: string, role: string?)

-- ============================================================
-- Tipos
-- ============================================================
type LobbyState = "Gathering" | "Selecting" | "Preparing"

-- ============================================================
-- Estado interno
-- ============================================================

local _state = {
	currentState = "Gathering" :: LobbyState,
	-- Selecoes dos jogadores: { [Player] = characterClass }
	selections = {} :: { [Player]: string },
	-- Se o jogador ja confirmou (ready)
	readyPlayers = {} :: { [Player]: boolean },
	-- Personagens disponiveis (carregado do GameConstants)
	availableHunter = "Distorcido",  -- Unico Cacador disponivel no MVP
	-- Timer de selecao
	selectTimer = 15,  -- segundos
	selectTimerActive = false,
	-- Conexoes
	connections = {} :: { RBXScriptConnection },
}

-- ============================================================
-- API: Estado do lobby
-- ============================================================

--[[
  Retorna o estado atual do lobby.
]]
function LobbyService.getState(): string
	return _state.currentState
end

--[[
  Retorna se o lobby esta no estado de selecao.
]]
function LobbyService.isSelecting(): boolean
	return _state.currentState == "Selecting"
end

-- ============================================================
-- API: Contagem de jogadores
-- ============================================================

--[[
  Retorna o numero de jogadores no lobby.
]]
function LobbyService.getPlayerCount(): number
	return #Players:GetPlayers()
end

--[[
  Verifica se ha jogadores suficientes para iniciar (min. 2).
]]
function LobbyService.hasMinimumPlayers(): boolean
	return LobbyService.getPlayerCount() >= 2
end

-- ============================================================
-- API: Personagens disponiveis
-- ============================================================

--[[
  Retorna a lista de personagens disponiveis para selecao.
  Formato: { { class = "Medico", name = "Medico", free = true, role = "Survivor" }, ... }
]]
function LobbyService.getAvailableCharacters(): { any }
	local characters = {}

	-- Cacador (gratis, unico)
	table.insert(characters, {
		class = "Distorcido",
		name = GameConstants.Hunter.NAME,
		free = true,
		role = "Hunter",
		description = "O Cacador — criatura sobrenatural",
	})

	-- Sobreviventes gratuitos
	local freeSurvivors = { "SACKBOY", "MEDICO" }
	for _, key in ipairs(freeSurvivors) do
		local config = GameConstants.Survivors[key]
		if config then
			table.insert(characters, {
				class = config.NAME,
				name = config.NAME,
				free = true,
				role = "Survivor",
				description = config.ROLE or "",
			})
		end
	end

	-- Sobreviventes pagos
	local paidSurvivors = { "SOLDADO", "ROBO" }
	for _, key in ipairs(paidSurvivors) do
		local config = GameConstants.Survivors[key]
		if config then
			table.insert(characters, {
				class = config.NAME,
				name = config.NAME,
				free = false,
				role = "Survivor",
				description = config.ROLE or "",
				-- Custo sera carregado do DataStore futuramente
				cost = key == "SOLDADO" and GameConstants.Economy.UNLOCK_COST_SOLDADO
					or GameConstants.Economy.UNLOCK_COST_ROBO,
			})
		end
	end

	return characters
end

-- ============================================================
-- API: Selecao de personagem
-- ============================================================

--[[
  Registra a selecao de personagem de um jogador.
  Chamado quando o servidor recebe SELECT_CHARACTER via PlayerActionEvent.
  Retorna true se a selecao foi aceita.
]]
function LobbyService.selectCharacter(player: Player, characterClass: string): boolean
	if _state.currentState ~= "Selecting" then
		warn("[TheBrokenBox] LobbyService: Selecao fora do estado Selecting (" .. player.Name .. ")")
		return false
	end

	-- Validar se o personagem existe
	local available = LobbyService.getAvailableCharacters()
	local valid = false
	for _, char in ipairs(available) do
		if char.class == characterClass then
			valid = true
			break
		end
	end

	if not valid then
		warn("[TheBrokenBox] LobbyService: Personagem invalido: " .. characterClass .. " (" .. player.Name .. ")")
		return false
	end

	-- Verificar se o personagem ja foi escolhido por outro jogador
	-- (Cacador e unico; Sobreviventes podem repetir classe)
	if characterClass == "Distorcido" then
		for otherPlayer, sel in pairs(_state.selections) do
			if sel == "Distorcido" and otherPlayer ~= player then
				warn("[TheBrokenBox] LobbyService: Cacador ja selecionado por " .. otherPlayer.Name)
				return false
			end
		end
	end

	_state.selections[player] = characterClass

	-- Determinar o papel
	local role: string?
	if characterClass == "Distorcido" then
		role = "Hunter"
	else
		role = "Survivor"
	end

	print("[TheBrokenBox] LobbyService: " .. player.Name .. " selecionou " .. characterClass .. " (" .. (role or "?") .. ")")
	LobbyService.characterSelected:Fire(player, characterClass, role)

	-- Verificar se todos selecionaram
	LobbyService._checkAllReady()

	return true
end

--[[
  Retorna a selecao de um jogador.
]]
function LobbyService.getPlayerSelection(player: Player): string?
	return _state.selections[player]
end

--[[
  Retorna todas as selecoes atuais.
]]
function LobbyService.getAllSelections(): { [Player]: string }
	return _state.selections
end

-- ============================================================
-- API: Controle de fluxo
-- ============================================================

--[[
  Inicia a fase de selecao de personagem.
  Transicao: Gathering -> Selecting.
  Notifica todos os clientes via GameStateEvent (externo).
]]
function LobbyService.startSelection(): ()
	if _state.currentState ~= "Gathering" then
		warn("[TheBrokenBox] LobbyService: Nao pode iniciar selecao no estado " .. _state.currentState)
		return
	end

	if not LobbyService.hasMinimumPlayers() then
		warn("[TheBrokenBox] LobbyService: Minimo de 2 jogadores necessario para iniciar.")
		return
	end

	_state.currentState = "Selecting"
	_state.selections = {}
	_state.readyPlayers = {}

	print("[TheBrokenBox] LobbyService: Fase de selecao iniciada. Timer: " .. _state.selectTimer .. "s")

	-- Iniciar timer de selecao
	LobbyService._startSelectTimer()

	LobbyService.lobbyReady:Fire()
end

--[[
  Finaliza a selecao e avanca para Preparacao.
  Transicao: Selecting -> Preparing.
]]
function LobbyService.finishSelection(): ()
	if _state.currentState ~= "Selecting" then
		return
	end

	_state.currentState = "Preparing"
	print("[TheBrokenBox] LobbyService: Selecao finalizada. Avancando para Preparacao...")

	-- Atribuir papeis: se ninguem escolheu Cacador, sortear um
	LobbyService._assignRoles()
end

--[[
  Retorna ao estado de Gathering (ex.: fim de partida).
]]
function LobbyService.resetToGathering(): ()
	_state.currentState = "Gathering"
	_state.selections = {}
	_state.readyPlayers = {}
	print("[TheBrokenBox] LobbyService: Retornando ao estado Gathering.")
end

-- ============================================================
-- Metodos internos
-- ============================================================

--[[
  Verifica se todos os jogadores ja selecionaram personagem.
  Se sim, pode avancar imediatamente (sem esperar o timer).
]]
function LobbyService._checkAllReady(): ()
	if _state.currentState ~= "Selecting" then
		return
	end

	local allPlayers = Players:GetPlayers()
	if #allPlayers == 0 then
		return
	end

	for _, player in ipairs(allPlayers) do
		if not _state.selections[player] then
			return  -- Ainda ha jogadores sem selecao
		end
	end

	print("[TheBrokenBox] LobbyService: Todos os jogadores selecionaram. Finalizando selecao...")
	LobbyService.finishSelection()
end

--[[
  Inicia o timer de selecao (15s).
  Quando expira, atribui personagens aleatorios para quem nao escolheu.
]]
function LobbyService._startSelectTimer(): ()
	if _state.selectTimerActive then
		return
	end

	_state.selectTimerActive = true

	task.spawn(function()
		local remaining = _state.selectTimer

		while remaining > 0 and _state.currentState == "Selecting" do
			task.wait(1)
			remaining = remaining - 1
		end

		-- Se ainda estamos em Selecting apos o timer, forcar finalizacao
		if _state.currentState == "Selecting" then
			print("[TheBrokenBox] LobbyService: Timer de selecao expirou. Atribuindo personagens restantes...")
			-- Atribuir personagens aleatorios para quem nao escolheu
			LobbyService._assignRandomToUnselected()
			LobbyService.finishSelection()
		end

		_state.selectTimerActive = false
	end)
end

--[[
  Atribui personagens aleatorios para jogadores que nao selecionaram.
]]
function LobbyService._assignRandomToUnselected(): ()
	local available = LobbyService.getAvailableCharacters()
	local allPlayers = Players:GetPlayers()

	-- Verificar se o Cacador ja foi escolhido
	local hunterChosen = false
	for _, sel in pairs(_state.selections) do
		if sel == "Distorcido" then
			hunterChosen = true
			break
		end
	end

	for _, player in ipairs(allPlayers) do
		if not _state.selections[player] then
			if not hunterChosen then
				-- Primeiro jogador sem selecao vira Cacador
				_state.selections[player] = "Distorcido"
				hunterChosen = true
				print("[TheBrokenBox] LobbyService: " .. player.Name .. " atribuido como Cacador (aleatorio)")
			else
				-- Atribuir um Sobrevivente gratuito aleatorio
				local survivors = {}
				for _, char in ipairs(available) do
					if char.free and char.role == "Survivor" then
						table.insert(survivors, char.class)
					end
				end
				if #survivors > 0 then
					local randomClass = survivors[math.random(1, #survivors)]
					_state.selections[player] = randomClass
					print("[TheBrokenBox] LobbyService: " .. player.Name .. " atribuido como " .. randomClass .. " (aleatorio)")
				end
			end
		end
	end
end

--[[
  Atribui papeis finais (Hunter/Survivor) e notifica MatchService.
]]
function LobbyService._assignRoles(): ()
	-- Esta funcao sera conectada ao MatchService via GameManager.wireServiceSignals()
	-- Por enquanto, apenas registra as atribuicoes

	for player, characterClass in pairs(_state.selections) do
		local role = (characterClass == "Distorcido") and "Hunter" or "Survivor"
		print("[TheBrokenBox] LobbyService: Papel final — " .. player.Name .. " = " .. role .. " (" .. characterClass .. ")")
		-- A atribuicao real (MatchService.assignHunter/assignSurvivor) e feita
		-- pelo GameManager quando recebe o sinal characterSelected
	end
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono.
]]
function LobbyService.Init(): ()
	print("[TheBrokenBox] LobbyService.Init()")
	_state.currentState = "Gathering"
	_state.selections = {}
	_state.readyPlayers = {}
	_state.selectTimerActive = false
end

--[[
  Start(): registro de listeners.
]]
function LobbyService.Start(): ()
	print("[TheBrokenBox] LobbyService.Start() — Aguardando jogadores no lobby A Caixa...")

	-- Listener de novos jogadores entrando no lobby
	local conn = Players.PlayerAdded:Connect(function(player: Player)
		print("[TheBrokenBox] LobbyService: Jogador entrou no lobby: " .. player.Name .. " (total: " .. LobbyService.getPlayerCount() .. ")")

		-- Se ja temos 2 jogadores e estamos em Gathering, iniciar selecao
		-- (no MVP, inicia automaticamente ao atingir o minimo)
		-- Nota: no futuro, o host controlara o inicio
	end)
	table.insert(_state.connections, conn)
end

return LobbyService
