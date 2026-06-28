--!strict
--[[
  StaminaService.lua
  Servico server-authoritative de stamina.
  Gerencia gasto, regeneracao, pulo e dash para todos os jogadores.

  Regras (ref: GDD M4):
    - Gasto ao correr: 7/s
    - Regeneracao: 9/s (ao andar/parado)
    - Atraso pos-esgotamento: 0.5s antes de regenerar
    - Pulo: custo 10, cooldown 2s
    - Jump height: suficiente para esquivar M1 hitbox
    - Dash: pausa regeneracao (sem consumo extra)

  Funciona via RunService.Heartbeat para atualizacao por frame.
  Validacao server-side (anti-stamina hack).

  Referencias: GDD M4 (Stamina e Pulo), architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

local StaminaService = {}
StaminaService.Name = "StaminaService"

-- ============================================================
-- Sinais
-- ============================================================
StaminaService.staminaChanged = Signal.new()   -- (player: Player, stamina: number, maxStamina: number)
StaminaService.staminaExhausted = Signal.new() -- (player: Player)
StaminaService.jumpUsed = Signal.new()         -- (player: Player)

-- ============================================================
-- Estado interno por jogador
-- ============================================================
type StaminaState = {
	player: Player,
	stamina: number,
	maxStamina: number,
	isRunning: boolean,
	isDashing: boolean,
	exhaustedTime: number,    -- timestamp de quando esgotou (para delay)
	isExhausted: boolean,
	jumpCooldown: number,     -- timestamp do ultimo pulo
	lastUpdate: number,       -- timestamp do ultimo tick
}

local _staminaStates = {}  -- { [Player] = StaminaState }
local _heartbeatConnection: RBXScriptConnection? = nil

-- ============================================================
-- Funcoes internas
-- ============================================================

--[[
  Cria o estado de stamina para um jogador.
]]
local function createStaminaState(player: Player, maxStamina: number): StaminaState
	return {
		player = player,
		stamina = maxStamina,
		maxStamina = maxStamina,
		isRunning = false,
		isDashing = false,
		exhaustedTime = 0,
		isExhausted = false,
		jumpCooldown = 0,
		lastUpdate = os.clock(),
	}
end

--[[
  Atualiza a stamina de um jogador no tick do Heartbeat.
  Chamado a cada frame (~60Hz).
]]
local function updateStaminaTick(state: StaminaState, deltaTime: number)
	local config = GameConstants.Stamina
	local stamina = state.stamina
	local now = os.clock()

	-- Se estiver em dash, nao regenera (mas tambem nao gasta stamina)
	if state.isDashing then
		state.lastUpdate = now
		return
	end

	-- Se esta correndo: gasta stamina
	if state.isRunning and not state.isExhausted then
		stamina = stamina - config.SPEND_PER_SECOND * deltaTime

		-- Chegou a 0?
		if stamina <= 0 then
			stamina = 0
			state.isExhausted = true
			state.exhaustedTime = now
			StaminaService.staminaExhausted:Fire(state.player)
			print("[TheBrokenBox] Stamina: " .. state.player.Name .. " esgotou a stamina!")
		end
	elseif not state.isRunning then
		-- Se esta esgotado, verificar delay
		if state.isExhausted then
			local elapsed = now - state.exhaustedTime
			if elapsed >= config.EXHAUST_DELAY then
				state.isExhausted = false
			end
		end

		-- Regenerar stamina se nao estiver esgotado
		-- Andar NAO impede regeneracao (so correr gasta)
		if not state.isExhausted then
			stamina = math.min(state.maxStamina, stamina + config.REGEN_PER_SECOND * deltaTime)
		end
	end

	-- Aplicar alteracao
	if stamina ~= state.stamina then
		state.stamina = stamina
		StaminaService.staminaChanged:Fire(state.player, stamina, state.maxStamina)
	end

	state.lastUpdate = now
end

-- ============================================================
-- API: Gerenciamento de jogadores
-- ============================================================

--[[
  Inicializa a stamina para um jogador.
  Chamado quando o papel e atribuido (MatchService).
]]
function StaminaService.initPlayer(player: Player, maxStamina: number): ()
	if _staminaStates[player] then
		return -- Ja inicializado
	end

	_staminaStates[player] = createStaminaState(player, maxStamina)
	print("[TheBrokenBox] StaminaService: Inicializado para " .. player.Name .. " (max: " .. maxStamina .. ")")
end

--[[
  Remove o estado de stamina de um jogador.
]]
function StaminaService.removePlayer(player: Player): ()
	_staminaStates[player] = nil
end

--[[
  Callback quando um jogador morre — limpa estado de stamina.
]]
function StaminaService.onPlayerDied(player: Player): ()
	StaminaService.removePlayer(player)
end

-- ============================================================
-- API: Controles de stamina
-- ============================================================

--[[
  Define se o jogador esta correndo (Shift pressionado).
  Chamado pelo servidor ao receber input do cliente.
]]
function StaminaService.setRunning(player: Player, running: boolean): ()
	local state = _staminaStates[player]
	if not state then
		return
	end
	state.isRunning = running
end

--[[
  Define se o jogador esta em dash.
  Durante dash, regeneracao de stamina e pausada.
]]
function StaminaService.setDashing(player: Player, dashing: boolean): ()
	local state = _staminaStates[player]
	if not state then
		return
	end
	state.isDashing = dashing
end

--[[
  Tenta executar um pulo.
  Retorna true se o pulo foi permitido.
  - Verifica cooldown de 2s
  - Verifica stamina minima (10)
  - Consome 10 de stamina
]]
function StaminaService.tryJump(player: Player): boolean
	local state = _staminaStates[player]
	if not state then
		return false
	end

	local config = GameConstants.Stamina
	local now = os.clock()

	-- Verificar cooldown
	if now - state.jumpCooldown < config.JUMP_COOLDOWN then
		return false
	end

	-- Verificar stamina
	if state.stamina < config.JUMP_COST then
		return false
	end

	-- Consumir stamina e registrar cooldown
	state.stamina = state.stamina - config.JUMP_COST
	state.jumpCooldown = now

	-- Notificar
	StaminaService.jumpUsed:Fire(player)
	StaminaService.staminaChanged:Fire(player, state.stamina, state.maxStamina)

	-- Aplicar forca de pulo no personagem
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- JumpPower alto o suficiente para saltar a hitbox do M1
			-- (M1 hitbox tem alcance limitado; altura do pulo ~10 studs)
			humanoid.JumpPower = 70
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	return true
end

-- ============================================================
-- API: Consulta de estado
-- ============================================================

function StaminaService.getStamina(player: Player): number
	local state = _staminaStates[player]
	if state then
		return state.stamina
	end
	return 0
end

function StaminaService.getMaxStamina(player: Player): number
	local state = _staminaStates[player]
	if state then
		return state.maxStamina
	end
	return 0
end

function StaminaService.isExhausted(player: Player): boolean
	local state = _staminaStates[player]
	if state then
		return state.isExhausted
	end
	return false
end

function StaminaService.canJump(player: Player): boolean
	local state = _staminaStates[player]
	if not state then
		return false
	end
	local now = os.clock()
	return state.stamina >= GameConstants.Stamina.JUMP_COST
		and (now - state.jumpCooldown) >= GameConstants.Stamina.JUMP_COOLDOWN
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

function StaminaService.Init(): ()
	print("[TheBrokenBox] StaminaService.Init()")
	_staminaStates = {}
end

function StaminaService.Start(): ()
	print("[TheBrokenBox] StaminaService.Start() — iniciando loop de Heartbeat...")

	-- Conectar ao Heartbeat para atualizacao por frame
	_heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		for _, state in pairs(_staminaStates) do
			updateStaminaTick(state, deltaTime)
		end
	end)

	-- Limpar quando o jogo fecha (anti memory leak)
	game:BindToClose(function()
		if _heartbeatConnection then
			_heartbeatConnection:Disconnect()
			_heartbeatConnection = nil
		end
	end)
end

return StaminaService
