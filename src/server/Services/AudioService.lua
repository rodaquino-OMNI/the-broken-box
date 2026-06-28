--!strict
--[[
  AudioService.lua
  Servico server-authoritative de audio e atmosfera.
  Orquestra a trilha dinamica de 3 camadas (Calma → Alerta → Perseguicao),
  SFX de eventos e comandos de audio enviados aos clientes.

  Trilha dinamica (ref: GDD Design de Audio de Tensao):
    - Calma:     default, quando Cacador > 60 studs do Sobrevivente mais proximo
    - Alerta:    Cacador entre 30-60 studs
    - Perseguicao: Cacador < 30 studs (ou durante Rage)
    - Crossfade: 2s entre camadas

  Eventos que disparam SFX:
    - survivorDamaged -> heartbeat SFX
    - rageActivated -> Perseguicao
    - rageDeactivated -> retorna a camada apropriada
    - escapeStarted -> trilha de climax da fuga
    - missionCompleted -> SFX
    - playerDied -> SFX

  Envia comandos de audio aos clientes via GameStateEvent
  com message types AUDIO_MUSIC_LAYER, AUDIO_SFX, AUDIO_HEARTBEAT.

  Init/Start pattern.
  Referencias: GDD Design de Audio de Tensao, GameConstants.Audio
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local AudioService = {}
AudioService.Name = "AudioService"

-- ============================================================
-- Sinais do servico
-- ============================================================
AudioService.audioCommand = Signal.new()  -- (target: Player | "all", command: string, data: {})

-- ============================================================
-- Referencias a outros servicos (injetadas no Init)
-- ============================================================
local MatchService = nil
local _gameStateEvent: RemoteEvent? = nil

-- ============================================================
-- Estado interno
-- ============================================================
type MusicLayer = "Calma" | "Alerta" | "Perseguicao" | "Climax"

local _currentLayer: MusicLayer = "Calma"
local _lastLayerUpdate: number = 0         -- Timestamp da ultima mudanca (para crossfade)
local _isInRage: boolean = false           -- Se o Cacador esta em Rage
local _isEscaping: boolean = false         -- Se a partida esta na fase de Fuga
local _musicState: { currentLayer: MusicLayer, isRage: boolean, isEscaping: boolean } = {
	currentLayer = "Calma",
	isRage = false,
	isEscaping = false,
}

-- Heartbeat connection
local _heartbeatConnection: RBXScriptConnection? = nil

-- ============================================================
-- Constantes locais (do GameConstants)
-- ============================================================
local AUDIO_CFG = GameConstants.Audio

-- ============================================================
-- Funcoes internas: envio de comandos de audio
-- ============================================================

--[[
  Envia um comando de audio para todos os clientes.
]]
local function sendAudioToAll(commandType: string, data: {any}): ()
	if not _gameStateEvent then
		warn("[TheBrokenBox] AudioService: GameStateEvent nao disponivel!")
		return
	end

	RemoteEventUtils.fireAll(_gameStateEvent, commandType, data)
end

--[[
  Envia um comando de audio para um jogador especifico.
]]
local function sendAudioToPlayer(player: Player, commandType: string, data: {any}): ()
	if not _gameStateEvent then
		warn("[TheBrokenBox] AudioService: GameStateEvent nao disponivel!")
		return
	end

	RemoteEventUtils.firePlayer(_gameStateEvent, player, commandType, data)
end

--[[
  Envia comando de troca de camada musical para todos os clientes.
]]
local function sendMusicLayerCommand(layer: MusicLayer): ()
	sendAudioToAll("AUDIO_MUSIC_LAYER", {
		layer = layer,
		crossfade = AUDIO_CFG.CROSSFADE_DURATION,
	})
end

--[[
  Envia comando de SFX para todos os clientes.
]]
local function sendSfxCommand(sfxType: string, data: {any}?): ()
	sendAudioToAll("AUDIO_SFX", {
		sfx = sfxType,
		data = data or {},
	})
end

--[[
  Envia comando de batimento cardiaco para um jogador especifico.
  proximity: distancia do Cacador em studs (0 se nao ha calculo).
]]
local function sendHeartbeatCommand(player: Player, proximity: number): ()
	sendAudioToPlayer(player, "AUDIO_HEARTBEAT", {
		proximity = proximity,
	})
end

-- ============================================================
-- Calculo de proximidade Cacador -> Sobrevivente mais proximo
-- ============================================================

--[[
  Calcula a distancia entre o Cacador e o Sobrevivente mais proximo.
  Retorna a distancia em studs, ou math.huge se nao houver Cacador ou Sobreviventes.
]]
local function getMinHunterDistance(): number
	if not MatchService then
		return math.huge
	end

	local hunter = MatchService.getHunter()
	if not hunter then
		return math.huge
	end

	-- Obter posicao do Cacador
	local hunterChar = hunter.Character
	if not hunterChar then
		return math.huge
	end

	local hunterRoot = hunterChar:FindFirstChild("HumanoidRootPart")
	if not hunterRoot then
		return math.huge
	end

	local hunterPos = hunterRoot.Position

	-- Calcular distancia para cada Sobrevivente vivo
	local survivors = MatchService.getPlayersByRole("Survivor")
	local minDist: number = math.huge

	for _, survivor in ipairs(survivors) do
		local data = MatchService.getPlayerData(survivor)
		if data and data.isAlive then
			local survivorChar = survivor.Character
			if survivorChar then
				local survivorRoot = survivorChar:FindFirstChild("HumanoidRootPart")
				if survivorRoot then
					local dist = (survivorRoot.Position - hunterPos).Magnitude
					if dist < minDist then
						minDist = dist
					end
				end
			end
		end
	end

	return minDist
end

--[[
  Calcula a distancia entre o Cacador e um Sobrevivente especifico.
  Retorna a distancia em studs, ou math.huge se nao puder calcular.
]]
local function getPlayerDistanceToHunter(player: Player): number
	if not MatchService then
		return math.huge
	end

	local hunter = MatchService.getHunter()
	if not hunter then
		return math.huge
	end

	local hunterChar = hunter.Character
	local playerChar = player.Character
	if not hunterChar or not playerChar then
		return math.huge
	end

	local hunterRoot = hunterChar:FindFirstChild("HumanoidRootPart")
	local playerRoot = playerChar:FindFirstChild("HumanoidRootPart")
	if not hunterRoot or not playerRoot then
		return math.huge
	end

	return (playerRoot.Position - hunterRoot.Position).Magnitude
end

-- ============================================================
-- Logica da trilha dinamica
-- ============================================================

--[[
  Determina qual camada musical deve tocar com base na distancia.
  Regras:
    - Rage ativo: Perseguicao
    - Escaping: Climax
    - Distancia > LAYER_CALM_MAX (60 studs): Calma
    - Distancia > LAYER_ALERT_MAX (30 studs): Alerta
    - Distancia <= LAYER_ALERT_MAX: Perseguicao
]]
local function determineMusicLayer(): MusicLayer
	if _isEscaping then
		return "Climax"
	end

	if _isInRage then
		return "Perseguicao"
	end

	local minDist = getMinHunterDistance()
	local audioCfg = AUDIO_CFG

	if minDist > audioCfg.LAYER_CALM_MAX then
		return "Calma"
	elseif minDist > audioCfg.LAYER_ALERT_MAX then
		return "Alerta"
	else
		return "Perseguicao"
	end
end

--[[
  Atualiza a camada musical se necessario.
  Chamado no ciclo de Heartbeat (~1Hz).
  Evita spam: so envia comando se a camada mudou.
]]
local function updateMusicLayer(): ()
	local newLayer = determineMusicLayer()

	if newLayer ~= _currentLayer then
		local oldLayer = _currentLayer
		_currentLayer = newLayer
		_lastLayerUpdate = os.clock()

		print("[TheBrokenBox] AudioService: Camada musical alterada: " .. oldLayer .. " -> " .. newLayer)
		sendMusicLayerCommand(newLayer)

		-- Atualizar estado rastreado
		_musicState.currentLayer = newLayer
	end
end

--[[
  Envia comandos de batimento cardiaco baseados em proximidade
  para cada Sobrevivente individualmente.
  Batimentos sao audiveis ate HEARTBEAT_RADIUS (40 studs).
]]
local function updateHeartbeats(): ()
	if not MatchService then
		return
	end

	local hunter = MatchService.getHunter()
	if not hunter then
		return
	end

	local survivors = MatchService.getPlayersByRole("Survivor")
	local heartbeatRadius = AUDIO_CFG.HEARTBEAT_RADIUS

	for _, survivor in ipairs(survivors) do
		local data = MatchService.getPlayerData(survivor)
		if data and data.isAlive then
			local dist = getPlayerDistanceToHunter(survivor)
			if dist < heartbeatRadius then
				sendHeartbeatCommand(survivor, dist)
			end
		end
	end
end

-- ============================================================
-- Loop de Heartbeat (atualizacao periodica ~0.5Hz)
-- ============================================================

local _lastCheckTime: number = 0

local function onHeartbeat(_deltaTime: number): ()
	local now = os.clock()

	-- Verificar a cada 2s (evitar spam de comandos)
	if now - _lastCheckTime < 2.0 then
		return
	end

	_lastCheckTime = now

	-- Verificar estado da partida
	if MatchService then
		local state = MatchService.getMatchState()
		if state == "Escaping" and not _isEscaping then
			-- Nao forcar Climax aqui — o escapeStarted ja cuida disso
		elseif state ~= "Playing" and state ~= "Escaping" then
			return -- Nao atualizar musica fora da partida
		end
	end

	-- Atualizar camada musical
	updateMusicLayer()

	-- Atualizar batimentos cardiacos
	updateHeartbeats()
end

-- ============================================================
-- API: Callbacks de eventos externos
-- ============================================================

--[[
  Callback: Sobrevivente tomou dano -> batimento cardiaco intenso.
]]
function AudioService.onSurvivorDamaged(player: Player, damage: number, source: Player?): ()
	local dist = getPlayerDistanceToHunter(player)

	sendAudioToPlayer(player, "AUDIO_HEARTBEAT", {
		proximity = dist,
		intensity = "damaged",  -- Indica intensidade extra
		damage = damage,
	})

	print("[TheBrokenBox] AudioService: Batimento cardiaco (dano) para " .. player.Name)
end

--[[
  Callback: Rage ativado -> forca camada Perseguicao.
]]
function AudioService.onRageActivated(hunter: Player): ()
	_isInRage = true
	_currentLayer = "Perseguicao"
	_musicState.isRage = true

	print("[TheBrokenBox] AudioService: Rage ativado — forçando Perseguição")
	sendMusicLayerCommand("Perseguicao")
end

--[[
  Callback: Rage desativado -> retorna a camada apropriada.
]]
function AudioService.onRageDeactivated(hunter: Player, remainingFury: number): ()
	_isInRage = false
	_musicState.isRage = false

	-- Recalcular camada baseada na distancia
	_currentLayer = determineMusicLayer()

	print("[TheBrokenBox] AudioService: Rage desativado — retornando para " .. _currentLayer)
	sendMusicLayerCommand(_currentLayer)
end

--[[
  Callback: Fuga iniciada -> trilha de climax.
]]
function AudioService.onEscapeStarted(): ()
	_isEscaping = true
	_isInRage = false  -- Rage nao pode ser usado na Fuga
	_musicState.isEscaping = true
	_musicState.currentLayer = "Climax"
	_currentLayer = "Climax"

	print("[TheBrokenBox] AudioService: Fuga iniciada — trilha de climax!")
	sendMusicLayerCommand("Climax")

	-- SFX global de colapso/incendio
	sendSfxCommand("escape_start")
end

--[[
  Callback: Missao concluida -> SFX.
]]
function AudioService.onMissionCompleted(player: Player, missionId: string, missionType: string): ()
	print("[TheBrokenBox] AudioService: Missao concluida por " .. player.Name .. " — " .. missionId)
	sendSfxCommand("mission_complete", {
		missionId = missionId,
		missionType = missionType,
	})
end

--[[
  Callback: Jogador morreu -> SFX.
]]
function AudioService.onPlayerDied(player: Player): ()
	print("[TheBrokenBox] AudioService: Jogador morreu: " .. player.Name)
	sendSfxCommand("player_died", {
		playerName = player.Name,
	})
end

--[[
  Callback: tick do ciclo -> atualiza camada baseada na proximidade.
  Chamado pelo CycleService a cada segundo.
]]
function AudioService.onCycleTick(remainingTime: number): ()
	-- Atualizacao ja acontece via Heartbeat, mas forcar uma checagem imediata
	updateMusicLayer()
	updateHeartbeats()
end

-- ============================================================
-- API: Consulta de estado
-- ============================================================

--[[
  Retorna o estado atual da musica.
]]
function AudioService.getMusicState(): { currentLayer: MusicLayer, isRage: boolean, isEscaping: boolean }
	return _musicState
end

--[[
  Retorna a camada musical atual.
]]
function AudioService.getCurrentLayer(): MusicLayer
	return _currentLayer
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono. Recebe referencias das dependencias.
]]
function AudioService.Init(gameStateEvent: RemoteEvent, matchService: any): ()
	print("[TheBrokenBox] AudioService.Init()")

	_gameStateEvent = gameStateEvent
	MatchService = matchService

	-- Estado inicial
	_currentLayer = "Calma"
	_isInRage = false
	_isEscaping = false
	_lastCheckTime = 0
	_lastLayerUpdate = os.clock()

	_musicState = {
		currentLayer = "Calma",
		isRage = false,
		isEscaping = false,
	}
end

--[[
  Start(): inicia o loop de Heartbeat para atualizar a musica.
]]
function AudioService.Start(): ()
	print("[TheBrokenBox] AudioService.Start() — iniciando loop de musica...")

	-- Conectar Heartbeat para verificacao periodica
	if _heartbeatConnection then
		_heartbeatConnection:Disconnect()
	end
	_heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)

	print("[TheBrokenBox] AudioService.Start() concluido.")
end

return AudioService
