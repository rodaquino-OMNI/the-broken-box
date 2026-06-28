--!strict
--[[
  AudioManager.lua
  Gerenciador de audio do cliente (client-side).
  Responsavel por:
    - Trilha musical de 3 camadas com crossfade (Calma / Alerta / Perseguicao / Climax)
    - Batimentos cardiacos baseados em proximidade do Cacador
    - Distorcao de borda (vignette) quando o Cacador esta a <= 20 studs
    - SFX para eventos discretos (missao, morte, dano, Rage, etc.)
  
  Escuta comandos de audio do servidor via GameStateEvent.
  Usa Sound objects para reproducao e TweenService para crossfade.

  IMPORTANTE: Este modulo cria objetos Sound com IDs placeholder.
  Os IDs reais devem ser substituidos conforme docs/audio-asset-guide.md.

  Init/Start pattern.
  Referencias: GDD Design de Audio de Tensao, GameConstants.Audio
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

local AudioManager = {}
AudioManager.Name = "AudioManager"

-- ============================================================
-- Constantes de audio (placeholder IDs — ver docs/audio-asset-guide.md)
-- ============================================================

--[[
  PLACEHOLDER: Substituir por IDs reais do Toolbox Roblox.
  Buscar por: "bitcrushed", "lo-fi", "horror", "terror", "distortion"
]]
local AUDIO_IDS = {
	-- Trilha musical (3 camadas + climax)
	MUSIC_CALMA = "rbxassetid://0",        -- Placeholder: musica ambiente calma
	MUSIC_ALERTA = "rbxassetid://0",       -- Placeholder: tensao crescente
	MUSIC_PERSEGUICAO = "rbxassetid://0",  -- Placeholder: perseguicao intensa
	MUSIC_CLIMAX = "rbxassetid://0",       -- Placeholder: climax da fuga

	-- Batimentos cardiacos
	HEARTBEAT = "rbxassetid://0",          -- Placeholder: batimento cardiaco loop

	-- SFX
	SFX_MISSION_COMPLETE = "rbxassetid://0", -- Placeholder: missao concluida
	SFX_PLAYER_DAMAGED = "rbxassetid://0",   -- Placeholder: jogador ferido
	SFX_PLAYER_DIED = "rbxassetid://0",      -- Placeholder: jogador morto
	SFX_RAGE_ACTIVATE = "rbxassetid://0",    -- Placeholder: Rage ativado
	SFX_GATE_OPEN = "rbxassetid://0",        -- Placeholder: portao abrindo
	SFX_FIRE = "rbxassetid://0",             -- Placeholder: incendio/colapso
	SFX_ESCAPE_START = "rbxassetid://0",     -- Placeholder: inicio da fuga
}

-- ============================================================
-- Estado interno
-- ============================================================
local _musicSounds: { [string]: Sound } = {}   -- Music layer -> Sound object
local _heartbeatSound: Sound? = nil              -- Som de batimento cardiaco
local _currentLayer: string = "Calma"
local _crossfadeActive: boolean = false
local _audioFolder: Folder? = nil                -- Pasta para Sound objects

-- Tabela de tweens ativos por camada
local _activeTweens: { [string]: Tween } = {}

-- Edge distortion UI
local _edgeGui: ScreenGui? = nil
local _vignetteFrame: Frame? = nil
local _edgeFrames: { Frame } = {}  -- Top, Bottom, Left, Right edges

-- Cache de SFX para reutilizacao
local _sfxCache: { [string]: Sound } = {}

-- Conexoes
local _gameStateEvent: RemoteEvent? = nil
local _gameStateConnection: RBXScriptConnection? = nil

-- ============================================================
-- Constantes de crossfade
-- ============================================================
local AUDIO_CFG = GameConstants.Audio
local CROSSFADE_TIME = AUDIO_CFG.CROSSFADE_DURATION  -- 2s
local EDGE_DISTORTION_RADIUS = AUDIO_CFG.DISTORTION_RADIUS  -- 20 studs
local HEARTBEAT_RADIUS = AUDIO_CFG.HEARTBEAT_RADIUS  -- 40 studs

-- ============================================================
-- Cores da distorcao de borda
-- ============================================================
local EDGE_COLOR = Color3.fromRGB(0, 0, 0)  -- Preto para vignette

-- ============================================================
-- Criacao da UI de distorcao de borda
-- ============================================================

--[[
  Cria a ScreenGui com sobreposicao de vignette nas bordas.
  Escurece as bordas da tela quando o Cacador esta perto.
]]
local function createEdgeDistortion()
	-- Criar ScreenGui
	_edgeGui = Instance.new("ScreenGui")
	_edgeGui.Name = "AudioEdgeDistortion"
	_edgeGui.ResetOnSpawn = false
	_edgeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_edgeGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Frame do vignette (preenche a tela toda, usado como container)
	_vignetteFrame = Instance.new("Frame")
	_vignetteFrame.Name = "VignetteContainer"
	_vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
	_vignetteFrame.BackgroundTransparency = 1
	_vignetteFrame.BorderSizePixel = 0
	_vignetteFrame.ZIndex = 10
	_vignetteFrame.Parent = _edgeGui

	-- Criar 4 bordas com transparencia variavel
	local function createEdge(name: string, size: UDim2, position: UDim2): Frame
		local edge = Instance.new("Frame")
		edge.Name = name
		edge.Size = size
		edge.Position = position
		edge.BackgroundColor3 = EDGE_COLOR
		edge.BackgroundTransparency = 1  -- Inicia invisivel
		edge.BorderSizePixel = 0
		edge.ZIndex = 10
		edge.Parent = _vignetteFrame
		return edge
	end

	_edgeFrames[1] = createEdge("Top", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0, 0))
	_edgeFrames[2] = createEdge("Bottom", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 1, -80))
	_edgeFrames[3] = createEdge("Left", UDim2.new(0, 60, 1, 0), UDim2.new(0, 0, 0, 0))
	_edgeFrames[4] = createEdge("Right", UDim2.new(0, 60, 1, 0), UDim2.new(1, -60, 0, 0))

	print("[TheBrokenBox] AudioManager: UI de distorcao de borda criada.")
end

--[[
  Atualiza a opacidade das bordas baseada na distancia do Cacador.
  dist == 0: bordas totalmente visiveis (alpha = 0.5)
  dist >= EDGE_DISTORTION_RADIUS: bordas invisiveis
  Interpolacao linear entre os extremos.
]]
local function updateEdgeDistortion(dist: number): ()
	if not _vignetteFrame then
		return
	end

	local alpha: number

	if dist >= EDGE_DISTORTION_RADIUS or dist <= 0 then
		alpha = 0
	else
		-- Alpha proporcional: mais escuro quanto mais perto
		alpha = 0.5 * (1 - dist / EDGE_DISTORTION_RADIUS)
	end

	-- Aplicar a todas as bordas
	for _, edge in ipairs(_edgeFrames) do
		if edge then
			edge.BackgroundTransparency = 1 - alpha
		end
	end
end

-- ============================================================
-- Criacao e gerenciamento de Sound objects
-- ============================================================

--[[
  Cria ou obtem a pasta de audio no PlayerGui.
]]
local function getAudioFolder(): Folder
	if _audioFolder then
		return _audioFolder
	end

	_audioFolder = Instance.new("Folder")
	_audioFolder.Name = "AudioManager_Sounds"
	_audioFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")

	return _audioFolder
end

--[[
  Cria um Sound object com o ID especificado.
  looped: se o som deve tocar em loop.
]]
local function createSound(soundId: string, name: string, looped: boolean?): Sound
	local folder = getAudioFolder()

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = 0  -- Inicia mudo (crossfade depois)
	sound.Looped = looped or false
	sound.Parent = folder

	return sound
end

--[[
  Obtem ou cria um Sound para SFX (cacheado).
]]
local function getSfxSound(sfxId: string, name: string): Sound
	if _sfxCache[name] then
		return _sfxCache[name]
	end

	local sound = createSound(sfxId, name, false)
	_sfxCache[name] = sound
	return sound
end

-- ============================================================
-- Crossfade entre camadas musicais
-- ============================================================

--[[
  Faz crossfade da camada atual para a nova camada.
  Diminui volume da camada antiga e aumenta da nova em CROSSFADE_TIME segundos.
]]
local function crossfadeToLayer(newLayer: string): ()
	if newLayer == _currentLayer and not _crossfadeActive then
		return -- Ja esta na camada correta
	end

	local oldLayer = _currentLayer
	_currentLayer = newLayer

	print("[TheBrokenBox] AudioManager: Crossfade " .. oldLayer .. " -> " .. newLayer)

	-- Iniciar nova camada (se nao estiver tocando)
	local newSound = _musicSounds[newLayer]
	if not newSound then
		warn("[TheBrokenBox] AudioManager: Som nao encontrado para camada " .. newLayer)
		return
	end

	if not newSound.IsPlaying then
		newSound.Volume = 0
		newSound:Play()
	end

	-- Cancelar tweens ativos
	for layer, tween in pairs(_activeTweens) do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
		_activeTweens[layer] = nil
	end

	_crossfadeActive = true

	-- Fazer fade in da nova camada
	local tweenInInfo = TweenInfo.new(
		CROSSFADE_TIME,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	local tweenIn = TweenService:Create(newSound, tweenInInfo, { Volume = 1 })
	tweenIn:Play()
	_activeTweens[newLayer] = tweenIn

	-- Fazer fade out da camada antiga (se diferente)
	if oldLayer ~= newLayer then
		local oldSound = _musicSounds[oldLayer]
		if oldSound then
			local tweenOutInfo = TweenInfo.new(
				CROSSFADE_TIME,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out
			)

			local tweenOut = TweenService:Create(oldSound, tweenOutInfo, { Volume = 0 })
			tweenOut:Play()
			_activeTweens[oldLayer] = tweenOut

			-- Parar o som antigo apos o fade
			task.delay(CROSSFADE_TIME, function()
				if oldSound and oldSound.Volume < 0.01 then
					oldSound:Stop()
				end
			end)
		end
	end

	-- Marcar crossfade como concluido apos o tempo
	task.delay(CROSSFADE_TIME, function()
		_crossfadeActive = false
	end)
end

--[[
  Inicializa os Sound objects das 4 camadas musicais.
]]
local function initMusicLayers(): ()
	local folder = getAudioFolder()

	local layers = {
		{ key = "Calma", id = AUDIO_IDS.MUSIC_CALMA },
		{ key = "Alerta", id = AUDIO_IDS.MUSIC_ALERTA },
		{ key = "Perseguicao", id = AUDIO_IDS.MUSIC_PERSEGUICAO },
		{ key = "Climax", id = AUDIO_IDS.MUSIC_CLIMAX },
	}

	for _, layer in ipairs(layers) do
		local sound = createSound(layer.id, "Music_" .. layer.key, true)
		_musicSounds[layer.key] = sound
	end

	print("[TheBrokenBox] AudioManager: " .. #layers .. " camadas musicais inicializadas.")
end

-- ============================================================
-- Batimentos cardiacos
-- ============================================================

--[[
  Inicializa o Sound de batimento cardiaco.
]]
local function initHeartbeat(): ()
	_heartbeatSound = createSound(AUDIO_IDS.HEARTBEAT, "Heartbeat", true)
	print("[TheBrokenBox] AudioManager: Batimento cardiaco inicializado.")
end

--[[
  Atualiza o batimento cardiaco baseado na distancia do Cacador.
  - dist >= HEARTBEAT_RADIUS: sem batimento
  - dist < HEARTBEAT_RADIUS: volume e velocidade aumentam com proximidade
  - PlaybackSpeed: 1.0 (longe) ate 2.5 (muito perto)
]]
local function updateHeartbeat(dist: number, intensity: string?): ()
	if not _heartbeatSound then
		return
	end

	if dist >= HEARTBEAT_RADIUS or dist <= 0 then
		-- Parar batimento
		if _heartbeatSound.IsPlaying then
			_heartbeatSound:Stop()
			_heartbeatSound.Volume = 0
		end
		return
	end

	-- Calcular volume e velocidade baseados na distancia
	local proximityFactor = 1 - math.clamp(dist / HEARTBEAT_RADIUS, 0, 1)
	local volume = 0.2 + (0.8 * proximityFactor)  -- 0.2 a 1.0
	local speed = 1.0 + (1.5 * proximityFactor)    -- 1.0 a 2.5

	-- Intensificar em caso de dano
	if intensity == "damaged" then
		volume = math.min(1, volume + 0.3)
		speed = math.min(3.0, speed + 0.5)
	end

	_heartbeatSound.Volume = volume
	_heartbeatSound.PlaybackSpeed = speed

	if not _heartbeatSound.IsPlaying then
		_heartbeatSound:Play()
	end
end

-- ============================================================
-- Reproducao de SFX
-- ============================================================

--[[
  Toca um SFX one-shot.
  O Sound e reutilizado de um cache.
]]
local function playSfx(sfxId: string, name: string, volume: number?): ()
	local sound = getSfxSound(sfxId, name)
	sound.Volume = volume or 0.8

	if sound.IsPlaying then
		sound:Stop()
	end

	sound:Play()
end

--[[
  Toca um SFX baseado no tipo de evento.
]]
local function handleSfxEvent(sfxType: string, data: {any}?): ()
	if sfxType == "mission_complete" then
		playSfx(AUDIO_IDS.SFX_MISSION_COMPLETE, "MissionComplete", 0.7)
	elseif sfxType == "player_died" then
		playSfx(AUDIO_IDS.SFX_PLAYER_DIED, "PlayerDied", 0.9)
	elseif sfxType == "player_damaged" then
		playSfx(AUDIO_IDS.SFX_PLAYER_DAMAGED, "PlayerDamaged", 0.6)
	elseif sfxType == "rage_activate" then
		playSfx(AUDIO_IDS.SFX_RAGE_ACTIVATE, "RageActivate", 1.0)
	elseif sfxType == "gate_open" then
		playSfx(AUDIO_IDS.SFX_GATE_OPEN, "GateOpen", 0.8)
	elseif sfxType == "fire" then
		playSfx(AUDIO_IDS.SFX_FIRE, "Fire", 0.6)
	elseif sfxType == "escape_start" then
		playSfx(AUDIO_IDS.SFX_ESCAPE_START, "EscapeStart", 1.0)
	else
		warn("[TheBrokenBox] AudioManager: SFX desconhecido: " .. tostring(sfxType))
	end

	print("[TheBrokenBox] AudioManager: SFX reproduzido — " .. tostring(sfxType))
end

-- ============================================================
-- Processamento de comandos do servidor
-- ============================================================

--[[
  Callback quando recebe comando de audio via GameStateEvent.
]]
local function onAudioCommand(_player: Player, message: {any}): ()
	local msgType = message.type
	local data = message.data

	if msgType == "AUDIO_MUSIC_LAYER" then
		-- Troca de camada musical com crossfade
		local layer = data and data.layer
		if layer then
			crossfadeToLayer(layer)
		end

	elseif msgType == "AUDIO_SFX" then
		-- Reproduzir SFX
		local sfxType = data and data.sfx
		if sfxType then
			handleSfxEvent(sfxType, data.data)
		end

	elseif msgType == "AUDIO_HEARTBEAT" then
		-- Atualizar batimento cardiaco
		local proximity = data and data.proximity or math.huge
		local intensity = data and data.intensity
		updateHeartbeat(proximity, intensity)
		-- Tambem atualizar distorcao de borda
		updateEdgeDistortion(proximity)
	else
		-- Nao e um comando de audio — ignorar silenciosamente
	end
end

-- ============================================================
-- Limpeza
-- ============================================================

--[[
  Para toda a musica e libera recursos.
]]
function AudioManager.stopAll(): ()
	-- Parar todas as camadas
	for _, sound in pairs(_musicSounds) do
		if sound.IsPlaying then
			sound:Stop()
		end
		_musicSounds = {}
	end

	-- Parar batimento
	if _heartbeatSound then
		_heartbeatSound:Stop()
		_heartbeatSound = nil
	end

	-- Limpar cache de SFX
	for _, sound in pairs(_sfxCache) do
		if sound.IsPlaying then
			sound:Stop()
		end
	end
	_sfxCache = {}

	-- Remover UI de distorcao
	if _edgeGui then
		_edgeGui:Destroy()
		_edgeGui = nil
		_vignetteFrame = nil
		_edgeFrames = {}
	end

	-- Remover pasta de audio
	if _audioFolder then
		_audioFolder:Destroy()
		_audioFolder = nil
	end

	-- Desconectar listener
	if _gameStateConnection then
		_gameStateConnection:Disconnect()
		_gameStateConnection = nil
	end

	_currentLayer = "Calma"
	_crossfadeActive = false
	_activeTweens = {}

	print("[TheBrokenBox] AudioManager: Todos os sons parados e recursos liberados.")
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono — cria UI de distorcao e Sound objects.
]]
function AudioManager.Init(): ()
	print("[TheBrokenBox] AudioManager.Init()")

	-- Criar UI de distorcao de borda
	createEdgeDistortion()

	-- Inicializar Sound objects das camadas musicais
	initMusicLayers()

	-- Inicializar batimento cardiaco
	initHeartbeat()

	-- Encontrar o GameStateEvent em ReplicatedStorage
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_gameStateEvent = RemoteEventUtils.findRemoteEvent(eventsFolder, "GameStateEvent")
	end

	if not _gameStateEvent then
		warn("[TheBrokenBox] AudioManager: GameStateEvent nao encontrado! Comandos de audio nao serao recebidos.")
	end

	print("[TheBrokenBox] AudioManager.Init() concluido.")
end

--[[
  Start(): conecta listeners e inicia a musica ambiente.
]]
function AudioManager.Start(): ()
	print("[TheBrokenBox] AudioManager.Start() — registrando listeners...")

	-- Conectar ao GameStateEvent para receber comandos de audio
	if _gameStateEvent then
		_gameStateConnection = _gameStateEvent.OnClientEvent:Connect(onAudioCommand)
		print("[TheBrokenBox] AudioManager: Listener do GameStateEvent conectado.")
	else
		warn("[TheBrokenBox] AudioManager: GameStateEvent nao disponivel! Audio nao funcionara.")
		return
	end

	-- Iniciar musica ambiente (camada Calma por padrao)
	local calmSound = _musicSounds["Calma"]
	if calmSound then
		calmSound.Volume = 1
		calmSound:Play()
		print("[TheBrokenBox] AudioManager: Musica ambiente (Calma) iniciada.")
	end

	print("[TheBrokenBox] AudioManager.Start() concluido.")
end

return AudioManager
