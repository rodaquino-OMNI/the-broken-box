--!strict
--[[
  MatchService.lua
  Servico de dominio que gerencia o estado da partida,
  rastreamento de jogadores, atribuicao de papeis (Hunter/Survivor)
  e fluxo de estados (Lobby -> Selecting -> Playing -> Escaping -> Ended).

  Sinais expostos:
    matchStateChanged  - quando o estado da partida muda
    playerDied         - quando um jogador morre (HP -> 0)
    roleAssigned       - quando papeis sao atribuidos

  Referencias: GDD Condicoes de Vitoria e Derrota, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

local MatchService = {}
MatchService.Name = "MatchService"

-- ============================================================
-- Sinais do servico
-- ============================================================
MatchService.matchStateChanged = Signal.new()  -- (newState: string)
MatchService.playerDied = Signal.new()         -- (player: Player)
MatchService.roleAssigned = Signal.new()       -- (player: Player, role: string)
MatchService.damageTaken = Signal.new()        -- (player: Player, damage: number, source: Player?)

-- ============================================================
-- Estado interno da partida
-- ============================================================
type MatchState = "Lobby" | "Selecting" | "Preparing" | "Playing" | "Escaping" | "Ended"

local _state = {
	currentState = "Lobby" :: MatchState,
	-- Rastreamento de jogadores
	players = {},           -- { [Player] = playerData }
	aliveSurvivors = 0,
	hunter = nil :: Player?,
	-- Mapa de papeis: survivorClass por Player
	survivorClasses = {},   -- { [Player] = "Medico" | "Soldado" | "Sackboy" | "Robo" }
}

-- ============================================================
-- Dados por jogador
-- ============================================================
type PlayerData = {
	userId: number,
	name: string,
	role: string?,           -- "Hunter" | "Survivor" | nil
	survivorClass: string?,   -- Classe do Sobrevivente, se aplicavel
	hp: number,
	maxHp: number,
	stamina: number,
	maxStamina: number,
	speed: number,
	isAlive: boolean,
	character: Model?,
}

-- ============================================================
-- API: Gerenciamento de jogadores
-- ============================================================

--[[
  Registra um jogador na partida.
  Chamado quando PlayerAdded dispara.
]]
function MatchService.registerPlayer(player: Player): ()
	if _state.players[player] then
		warn("[TheBrokenBox] MatchService: Jogador ja registrado: " .. player.Name)
		return
	end

	local data: PlayerData = {
		userId = player.UserId,
		name = player.Name,
		role = nil,
		survivorClass = nil,
		hp = 0,
		maxHp = 0,
		stamina = 0,
		maxStamina = 0,
		speed = 22,  -- Velocidade base padrao
		isAlive = true,
		character = nil,
	}

	_state.players[player] = data
	print("[TheBrokenBox] MatchService: Jogador registrado: " .. player.Name .. " (total: " .. MatchService.getPlayerCount() .. ")")
end

--[[
  Remove um jogador da partida.
  Chamado quando PlayerRemoving dispara.
]]
function MatchService.removePlayer(player: Player): ()
	if not _state.players[player] then
		return
	end

	local data = _state.players[player]
	if data.role == "Hunter" then
		_state.hunter = nil
	elseif data.role == "Survivor" and data.isAlive then
		_state.aliveSurvivors = math.max(0, _state.aliveSurvivors - 1)
	end

	_state.players[player] = nil
	_state.survivorClasses[player] = nil
	print("[TheBrokenBox] MatchService: Jogador removido: " .. player.Name)
end

-- ============================================================
-- API: Atribuicao de papeis
-- ============================================================

--[[
  Atribui o papel de Hunter a um jogador.
  So pode haver 1 Hunter por partida.
]]
function MatchService.assignHunter(player: Player): ()
	if _state.hunter then
		warn("[TheBrokenBox] MatchService: Ja existe um Hunter! (" .. _state.hunter.Name .. ")")
		return
	end

	local data = _state.players[player]
	if not data then
		warn("[TheBrokenBox] MatchService: Jogador nao registrado: " .. player.Name)
		return
	end

	data.role = "Hunter"
	data.maxHp = GameConstants.Hunter.MAX_HP
	data.hp = GameConstants.Hunter.MAX_HP
	data.maxStamina = GameConstants.Hunter.STAMINA
	data.stamina = GameConstants.Hunter.STAMINA
	data.speed = GameConstants.Hunter.BASE_SPEED

	_state.hunter = player

	print("[TheBrokenBox] MatchService: Hunter atribuido: " .. player.Name)
	MatchService.roleAssigned:Fire(player, "Hunter")
end

--[[
  Atribui o papel de Survivor a um jogador, com classe especifica.
]]
function MatchService.assignSurvivor(player: Player, survivorClass: string): ()
	local data = _state.players[player]
	if not data then
		warn("[TheBrokenBox] MatchService: Jogador nao registrado: " .. player.Name)
		return
	end

	-- Obter stats da classe
	local classConfig = GameConstants.Survivors[survivorClass:upper()]
	if not classConfig then
		warn("[TheBrokenBox] MatchService: Classe invalida: " .. survivorClass)
		return
	end

	data.role = "Survivor"
	data.survivorClass = survivorClass
	data.maxHp = classConfig.MAX_HP
	data.hp = classConfig.MAX_HP
	data.maxStamina = classConfig.STAMINA
	data.stamina = classConfig.STAMINA
	data.speed = classConfig.SPEED
	data.isAlive = true

	_state.survivorClasses[player] = survivorClass
	_state.aliveSurvivors = _state.aliveSurvivors + 1

	print("[TheBrokenBox] MatchService: Survivor atribuido: " .. player.Name .. " como " .. survivorClass)
	MatchService.roleAssigned:Fire(player, "Survivor")
end

--[[
  Retorna o papel de um jogador ("Hunter" | "Survivor" | nil).
]]
function MatchService.getPlayerRole(player: Player): string?
	local data = _state.players[player]
	if data then
		return data.role
	end
	return nil
end

--[[
  Retorna a classe de um Survivor.
]]
function MatchService.getSurvivorClass(player: Player): string?
	return _state.survivorClasses[player]
end

--[[
  Retorna o Hunter atual (ou nil).
]]
function MatchService.getHunter(): Player?
	return _state.hunter
end

-- ============================================================
-- API: Estado da partida
-- ============================================================

--[[
  Muda o estado da partida e notifica os ouvintes.
]]
function MatchService.setMatchState(newState: MatchState): ()
	local oldState = _state.currentState
	_state.currentState = newState
	print("[TheBrokenBox] MatchService: Estado mudou: " .. oldState .. " -> " .. newState)
	MatchService.matchStateChanged:Fire(newState)
end

--[[
  Retorna o estado atual da partida.
]]
function MatchService.getMatchState(): string
	return _state.currentState
end

-- ============================================================
-- API: Dano e HP
-- ============================================================

--[[
  Aplica dano a um jogador. Se HP chegar a 0, dispara playerDied.
  Retorna true se o jogador morreu.
]]
function MatchService.applyDamage(player: Player, damage: number, source: Player?): boolean
	local data = _state.players[player]
	if not data or not data.isAlive then
		return false
	end

	data.hp = math.max(0, data.hp - damage)
	MatchService.damageTaken:Fire(player, damage, source)

	if data.hp <= 0 then
		data.isAlive = false
		if data.role == "Survivor" then
			_state.aliveSurvivors = math.max(0, _state.aliveSurvivors - 1)
		end
		print("[TheBrokenBox] MatchService: " .. player.Name .. " morreu! (dano: " .. damage .. ")")
		MatchService.playerDied:Fire(player)
		return true
	end

	return false
end

--[[
  Cura um jogador. Nao excede o HP maximo.
]]
function MatchService.healPlayer(player: Player, amount: number): ()
	local data = _state.players[player]
	if not data or not data.isAlive then
		return
	end
	data.hp = math.min(data.maxHp, data.hp + amount)
end

--[[
  Retorna o HP atual de um jogador.
]]
function MatchService.getPlayerHP(player: Player): number
	local data = _state.players[player]
	if data then
		return data.hp
	end
	return 0
end

--[[
  Retorna os dados completos de um jogador.
]]
function MatchService.getPlayerData(player: Player): PlayerData?
	return _state.players[player]
end

-- ============================================================
-- API: Stamina
-- ============================================================

--[[
  Atualiza a stamina de um jogador (validado pelo StaminaService).
]]
function MatchService.setPlayerStamina(player: Player, value: number): ()
	local data = _state.players[player]
	if data then
		data.stamina = math.clamp(value, 0, data.maxStamina)
	end
end

--[[
  Retorna a stamina atual de um jogador.
]]
function MatchService.getPlayerStamina(player: Player): number
	local data = _state.players[player]
	if data then
		return data.stamina
	end
	return 0
end

-- ============================================================
-- API: Contagem de jogadores
-- ============================================================

function MatchService.getPlayerCount(): number
	local count = 0
	for _ in pairs(_state.players) do
		count = count + 1
	end
	return count
end

function MatchService.getAliveSurvivorCount(): number
	return _state.aliveSurvivors
end

--[[
  Retorna uma lista de Players com o papel especificado.
  Ex.: getPlayersByRole("Survivor") -> { Player, Player, ... }
]]
function MatchService.getPlayersByRole(role: string): {Player}
	local result = {}
	for player, data in pairs(_state.players) do
		if data.role == role then
			table.insert(result, player)
		end
	end
	return result
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono de estruturas.
]]
function MatchService.Init(): ()
	print("[TheBrokenBox] MatchService.Init()")
	_state.players = {}
	_state.aliveSurvivors = 0
	_state.hunter = nil
	_state.survivorClasses = {}
	_state.currentState = "Lobby"
end

--[[
  Start(): registro de listeners de jogadores.
]]
function MatchService.Start(): ()
	print("[TheBrokenBox] MatchService.Start()")

	-- Registrar jogadores existentes (para late-join em testes)
	for _, player in ipairs(Players:GetPlayers()) do
		MatchService.registerPlayer(player)
	end

	-- Listener de novos jogadores
	Players.PlayerAdded:Connect(function(player: Player)
		MatchService.registerPlayer(player)
	end)

	-- Listener de jogadores saindo
	Players.PlayerRemoving:Connect(function(player: Player)
		MatchService.removePlayer(player)
	end)
end

--[[
  Callback opcional: chamado quando dano e aplicado via HitboxService.
]]
function MatchService.onDamageApplied(target: Player, damage: number, source: Player?): ()
	MatchService.applyDamage(target, damage, source)
end

return MatchService
