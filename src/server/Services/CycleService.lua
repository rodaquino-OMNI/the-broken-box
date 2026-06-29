--!strict
--[[
  CycleService.lua
  Servico de dominio que gerencia o cronometro do Ciclo.
  Ciclo base: 240s (GameConstants.Game.CYCLE_BASE_DURATION).
  Modificadores: +20s por morte de Sobrevivente, -10s por missao concluida.
  Pausa durante Rage do Cacador.
  Quando zera: dispara cycleZero -> transicao para fase de Fuga.

  Sinais:
    cycleTick(remainingTime: number)  - a cada segundo
    cycleZero()                       - quando o cronometro zera

  Init/Start pattern, Heartbeat loop.
  Referencias: GDD M1-M2, GameConstants.Game
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

local CycleService = {}
CycleService.Name = "CycleService"

-- ============================================================
-- Sinais do servico
-- ============================================================
CycleService.cycleTick = Signal.new()   -- (remainingTime: number)
CycleService.cycleZero = Signal.new()   -- ()

-- ============================================================
-- Referencias a outros servicos (injetadas)
-- ============================================================
local MatchService = nil

-- ============================================================
-- Estado interno
-- ============================================================
local _cycleRemaining: number = 0        -- Tempo restante (s)
local _cycleActive: boolean = false      -- Se o ciclo esta rodando
local _isPaused: boolean = false         -- Se esta pausado (Rage)
local _cycleElapsed: number = 0          -- Tempo decorrido desde o inicio
local _cycleBaseDuration: number = 240   -- Duracao base

-- Conexao do Heartbeat
local _heartbeatConnection: RBXScriptConnection = nil

-- Timestamp do ultimo tick (para precisao)
local _lastTickTime: number = 0

-- ============================================================
-- Funcoes internas
-- ============================================================

--[[
  Loop de Heartbeat: decrementa o ciclo a cada segundo.
  Pausa quando _isPaused = true.
]]
local function onHeartbeat(_deltaTime: number): ()
	if not _cycleActive then
		return
	end

	if _isPaused then
		return
	end

	local now = os.clock()

	-- Verificar se passou 1s desde o ultimo tick
	if now - _lastTickTime < 10/10 then
		return
	end

	_lastTickTime = now
	_cycleRemaining = _cycleRemaining - 1

	-- Emitir tick com tempo restante
	CycleService.cycleTick:Fire(_cycleRemaining)

	-- Verificar se zerou
	if _cycleRemaining <= 0 then
		_cycleRemaining = 0
		_cycleActive = false

		print("[TheBrokenBox] CycleService: CICLO ZEROU! Iniciando Fuga...")
		CycleService.cycleZero:Fire()

		-- Desconectar Heartbeat
		if _heartbeatConnection then
			_heartbeatConnection:Disconnect()
			_heartbeatConnection = nil
		end
	end
end

-- ============================================================
-- API: Controle do Ciclo
-- ============================================================

--[[
  Inicia o ciclo (chamado quando a partida comeca - Playing).
]]
function CycleService.startCycle(): ()
	local baseDuration = GameConstants.Game.CYCLE_BASE_DURATION
	_cycleRemaining = baseDuration
	_cycleBaseDuration = baseDuration
	_cycleElapsed = 0
	_cycleActive = true
	_isPaused = false
	_lastTickTime = os.clock()

	-- Conectar Heartbeat
	if _heartbeatConnection then
		_heartbeatConnection:Disconnect()
	end
	_heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)

	print("[TheBrokenBox] CycleService: Ciclo iniciado - " .. baseDuration .. "s")
	CycleService.cycleTick:Fire(_cycleRemaining)
end

--[[
  Para o ciclo (ex.: partida terminou).
]]
function CycleService.stopCycle(): ()
	_cycleActive = false

	if _heartbeatConnection then
		_heartbeatConnection:Disconnect()
		_heartbeatConnection = nil
	end

	print("[TheBrokenBox] CycleService: Ciclo parado.")
end

--[[
  Pausa o ciclo (durante Rage do Cacador).
]]
function CycleService.pauseCycle(): ()
	if not _cycleActive then
		return
	end
	_isPaused = true
	print("[TheBrokenBox] CycleService: Ciclo pausado (Rage). Restante: " .. _cycleRemaining .. "s")
end

--[[
  Retoma o ciclo (apos Rage).
]]
function CycleService.resumeCycle(): ()
	if not _cycleActive then
		return
	end
	_isPaused = false
	_lastTickTime = os.clock() -- Resetar para nao descontar tempo pausado
	print("[TheBrokenBox] CycleService: Ciclo retomado. Restante: " .. _cycleRemaining .. "s")
end

--[[
  Adiciona tempo ao ciclo (+20s por morte de Sobrevivente).
]]
function CycleService.addTime(seconds: number): ()
	if not _cycleActive then
		return
	end
	_cycleRemaining = _cycleRemaining + seconds
	print("[TheBrokenBox] CycleService: +" .. seconds .. "s no ciclo. Total restante: " .. _cycleRemaining .. "s")
	CycleService.cycleTick:Fire(_cycleRemaining)
end

--[[
  Reduz tempo do ciclo (-10s por missao concluida).
]]
function CycleService.reduceTime(seconds: number): ()
	if not _cycleActive then
		return
	end

	-- Nao reduzir alem de 1s (sempre deixa ao menos 1s)
	_cycleRemaining = math.max(1, _cycleRemaining - seconds)

	print("[TheBrokenBox] CycleService: -" .. seconds .. "s no ciclo. Total restante: " .. _cycleRemaining .. "s")

	-- Verificar se zerou com a reducao
	if _cycleRemaining <= 1 then
		_cycleRemaining = 0
		_cycleActive = false

		print("[TheBrokenBox] CycleService: CICLO ZEROU (por reducao)! Iniciando Fuga...")
		CycleService.cycleZero:Fire()

		if _heartbeatConnection then
			_heartbeatConnection:Disconnect()
			_heartbeatConnection = nil
		end
	else
		CycleService.cycleTick:Fire(_cycleRemaining)
	end
end

-- ============================================================
-- API: Callbacks de eventos externos
-- ============================================================

--[[
  Callback: jogador morreu -> +20s no ciclo.
  Verifica se era um Sobrevivente.
]]
function CycleService.onPlayerDied(player: Player): ()
	if not _cycleActive then
		return
	end

	-- Verificar se era Sobrevivente
	if MatchService then
		local role = MatchService.getPlayerRole(player)
		if role == "Survivor" then
			local extendTime = GameConstants.Game.CYCLE_EXTEND_PER_DEATH
			CycleService.addTime(extendTime)
		end
	end
end

--[[
  Callback: missao concluida -> -10s no ciclo.
]]
function CycleService.onMissionCompleted(): ()
	if not _cycleActive then
		return
	end

	local reduceTime = GameConstants.Game.CYCLE_REDUCE_PER_MISSION
	CycleService.reduceTime(reduceTime)
end

--[[
  Callback: Rage ativado -> pausa ciclo.
]]
function CycleService.onRageActivated(): ()
	CycleService.pauseCycle()
end

--[[
  Callback: Rage desativado -> retoma ciclo.
]]
function CycleService.onRageDeactivated(): ()
	CycleService.resumeCycle()
end

-- ============================================================
-- API: Consulta de estado
-- ============================================================

--[[
  Retorna o tempo restante do ciclo.
]]
function CycleService.getRemainingTime(): number
	return _cycleRemaining
end

--[[
  Verifica se o ciclo esta ativo.
]]
function CycleService.isActive(): boolean
	return _cycleActive
end

--[[
  Verifica se o ciclo esta pausado.
]]
function CycleService.isPaused(): boolean
	return _isPaused
end

--[[
  Retorna a duracao base do ciclo.
]]
function CycleService.getBaseDuration(): number
	return _cycleBaseDuration
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono. Recebe referencia do MatchService.
]]
function CycleService.Init(matchService: any): ()
	print("[TheBrokenBox] CycleService.Init()")

	MatchService = matchService
	_cycleRemaining = 0
	_cycleActive = false
	_isPaused = false
	_cycleElapsed = 0
	_cycleBaseDuration = GameConstants.Game.CYCLE_BASE_DURATION
end

--[[
  Start(): pronto para uso.
  O ciclo e iniciado externamente quando a partida atinge Playing.
]]
function CycleService.Start(): ()
	print("[TheBrokenBox] CycleService.Start() - pronto.")
end

return CycleService
