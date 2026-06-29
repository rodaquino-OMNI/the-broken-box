--!strict
--[[
  AudioService.lua - Servidor. 7 canais FINAL:
    LOBBY_MUSIC     - lobby e loja (mesma)
    MAP_AMBIENT     - musica do mapa (DIFERENTE do lobby)
    CHASE_SECTION_1 - trecho 1 (> 60 studs)
    CHASE_SECTION_2 - trecho 2 (30-60 studs)
    CHASE_SECTION_3 - trecho 3 (5-30 studs)
    CHASE_SECTION_4 - trecho 4 (colado / Rage)
    FUGA            - 1 musica so, comeca calma, buildup natural, climax nos portoes

  4 trechos da MESMA musica, TROCAM via crossfade, NAO empilham.
  FUGA: 1 so. Comeca do inicio qdo ciclo acaba. Nao reinicia nos portoes.
  Protocolo: AUDIO_MUSIC_STATE { layerState, chaseSegment }
  layerState: "Lobby" | "Playing" | "PreFuga" | "Fuga"
]]

local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local GC = require(RS.GameConstants)
local Sig = require(RS.Util.Signal)
local RU = require(RS.Util.RemoteEventUtils)

local AudioService = {}
AudioService.Name = "AudioService"
AudioService.audioCommand = Sig.new()

local MS = nil; local _gse: RemoteEvent = nil
local _rage = false; local _gs = "Lobby"
local _cycle: number = math.huge
local _lastSt = ""; local _lastSeg = -1
local _hbc: RBXScriptConnection = nil
local C = GC.Audio

local function sndAll(cmd: string, data: {any}): ()
	if _gse then RU.fireAll(_gse, cmd, data) end
end
local function sndP(p: Player, cmd: string, data: {any}): ()
	if _gse then RU.firePlayer(_gse, p, cmd, data) end
end
local function sndSt(st: string, seg: number): ()
	sndAll("AUDIO_MUSIC_STATE", { layerState = st, chaseSegment = seg })
	_lastSt = st; _lastSeg = seg
end
local function sndSfx(tp: string, data: {any}?): ()
	sndAll("AUDIO_SFX", { sfx = tp, data = data or {} })
end

local function minDist(): number
	if not MS then return math.huge end
	local h = MS.getHunter()
	if not h or not h.Character then return math.huge end
	local hr = h.Character:FindFirstChild("HumanoidRootPart")
	if not hr then return math.huge end
	local hp = hr.Position
	local md: number = math.huge
	for _, s in ipairs(MS.getPlayersByRole("Survivor")) do
		local d = MS.getPlayerData(s)
		if d and d.isAlive and s.Character then
			local sr = s.Character:FindFirstChild("HumanoidRootPart")
			if sr then
				local dist = (sr.Position - hp).Magnitude
				if dist < md then md = dist end
			end
		end
	end
	return md
end

local function pDist(p: Player): number
	if not MS then return math.huge end
	local h = MS.getHunter()
	if not h or not h.Character or not p.Character then return math.huge end
	local hr = h.Character:FindFirstChild("HumanoidRootPart")
	local pr = p.Character:FindFirstChild("HumanoidRootPart")
	if not hr or not pr then return math.huge end
	return (pr.Position - hr.Position).Magnitude
end

local function cSeg(dist: number): number
	if dist == math.huge then return 0 end
	if _rage then return 4 end
	if dist > C.CHASE_SEGMENT_1_MAX then return 1
	elseif dist > C.CHASE_SEGMENT_2_MAX then return 2
	elseif dist > C.CHASE_SEGMENT_3_MAX then return 3
	else return 4 end
end

local function updSt(): ()
	local st = _gs
	if st == "Lobby" or st == "Selecting" or st == "Ended" then
		if _lastSt ~= "Lobby" then sndSt("Lobby", 0) end
		return
	end
	if st == "Escaping" then
		if _lastSt ~= "Fuga" then _rage = false; sndSt("Fuga", 0) end
		return
	end
	local seg = cSeg(minDist())
	if _cycle > 0 and _cycle <= C.FUGA_PRESTES_TIME then
		if _lastSt ~= "PreFuga" then sndSt("PreFuga", 0) end
	else
		if _lastSt ~= "Playing" or _lastSeg ~= seg then sndSt("Playing", seg) end
	end
end

local function updHB(): ()
	if not MS then return end
	local h = MS.getHunter()
	if not h then return end
	for _, s in ipairs(MS.getPlayersByRole("Survivor")) do
		local d = MS.getPlayerData(s)
		if d and d.isAlive then
			local dist = pDist(s)
			if dist < C.HEARTBEAT_RADIUS then
				sndP(s, "AUDIO_HEARTBEAT", { proximity = dist })
			end
		end
	end
end

local _lastChk = 0
local function onHb(_: number): ()
	local n = os.clock()
	if n - _lastChk < 20/10 then return end
	_lastChk = n
	if MS then _gs = MS.getMatchState() end
	updSt(); updHB()
end

function AudioService.onSurvivorDamaged(p: Player, dmg: number, _src: Player): ()
	sndP(p, "AUDIO_HEARTBEAT", { proximity = pDist(p), intensity = "damaged", damage = dmg })
end
function AudioService.onRageActivated(_h: Player): ()
	_rage = true; _lastSeg = -1; updSt()
end
function AudioService.onRageDeactivated(_h: Player, _f: number): ()
	_rage = false; _lastSeg = -1; updSt()
end
function AudioService.onEscapeStarted(): ()
	_rage = false; _gs = "Escaping"; _lastSt = ""; _lastSeg = -1; updSt()
	sndSfx("escape_start")
end
function AudioService.onMissionCompleted(_p: Player, mid: string, mt: string): ()
	sndSfx("mission_complete", { missionId = mid, missionType = mt })
end
function AudioService.onPlayerDied(p: Player): ()
	sndSfx("player_died", { playerName = p.Name })
end
function AudioService.onCycleTick(t: number): ()
	_cycle = t; updSt(); updHB()
end

function AudioService.getAudioState()
	return { layerState = _lastSt, chaseSegment = _lastSeg, isRage = _rage }
end
function AudioService.isFugaActive(): boolean
	return _gs == "Escaping"
end
function AudioService.isRageActive(): boolean
	return _rage
end

function AudioService.Init(gse: RemoteEvent, ms: any): ()
	_gse = gse; MS = ms
	_rage = false; _gs = "Lobby"; _cycle = math.huge
	_lastChk = 0; _lastSt = ""; _lastSeg = -1
end

function AudioService.Start(): ()
	if _hbc then _hbc:Disconnect() end
	_hbc = Run.Heartbeat:Connect(onHb)
end

return AudioService
