--!strict
--[[
  AudioManager.lua — Cliente. 7 canais FINAL:
    LOBBY_MUSIC     — lobby e loja (mesma)
    MAP_AMBIENT     — musica do mapa (DIFERENTE do lobby)
    CHASE_SECTION_1 — trecho 1 (> 60 studs)
    CHASE_SECTION_2 — trecho 2 (30-60 studs)
    CHASE_SECTION_3 — trecho 3 (5-30 studs)
    CHASE_SECTION_4 — trecho 4 (colado / Rage)
    FUGA            — 1 so, comeca calma, buildup natural, climax nos portoes

  4 trechos da MESMA musica, crossfade sequencial, NAO empilham.
  FUGA: comeca do inicio em "PreFuga", continua em "Fuga" sem reiniciar.
  Escuta AUDIO_MUSIC_STATE { layerState, chaseSegment }.
]]

local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local LP = P.LocalPlayer
local GC = require(RS.GameConstants)
local RU = require(RS.Util.RemoteEventUtils)

local AudioManager = {}
AudioManager.Name = "AudioManager"

local C = GC.Audio; local XF = C.CROSSFADE_DURATION
local ER = C.DISTORTION_RADIUS; local HR = C.HEARTBEAT_RADIUS

local ID = {
	L="rbxassetid://0", M="rbxassetid://0",
	C1="rbxassetid://0", C2="rbxassetid://0", C3="rbxassetid://0", C4="rbxassetid://0",
	F="rbxassetid://0", HB="rbxassetid://0",
	MC="rbxassetid://0", PD="rbxassetid://0", DMG="rbxassetid://0",
	RAGE="rbxassetid://0", GATE="rbxassetid://0", FIRE="rbxassetid://0", ESC="rbxassetid://0",
}

local lby: Sound?, amb: Sound?, ch: { Sound } = {}, fug: Sound?, hb: Sound?
local curSt = ""; local curSeg = 0; local fugOn = false
local tws: { Tween } = {}
local sfx: { [string]: Sound } = {}
local fld: Folder?
local eGui: ScreenGui?, vig: Frame?, eFr: { Frame } = {}
local gse: RemoteEvent?, gsc: RBXScriptConnection?

local function getFld(): Folder
	if fld then return fld end
	fld = Instance.new("Folder")
	fld.Name = "AudioManager_Sounds"; fld.Parent = LP:WaitForChild("PlayerGui")
	return fld
end

local function mk(id: string, nm: string, lp: boolean?): Sound
	local s = Instance.new("Sound")
	s.Name = nm; s.SoundId = id; s.Volume = 0; s.Looped = lp or false
	s.Parent = getFld(); return s
end

local function gsx(id: string, nm: string): Sound
	if sfx[nm] then return sfx[nm] end
	local s = mk(id, nm, false); sfx[nm] = s; return s
end

local function ct(): ()
	for _, t in ipairs(tws) do
		if t and t.PlaybackState == Enum.PlaybackState.Playing then t:Cancel() end
	end; tws = {}
end

local function fd(s: Sound?, v: number): ()
	if not s then return end
	if math.abs(s.Volume - v) < 0.01 then
		if v > 0 and not s.IsPlaying then s:Play() end
		return
	end
	if v > 0 and not s.IsPlaying then s.Volume = 0; s:Play() end
	local ti = TweenInfo.new(XF, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local t = TS:Create(s, ti, { Volume = v }); t:Play()
	table.insert(tws, t)
	if v == 0 then
		task.delay(XF + 0.1, function()
			if s and s.Volume < 0.01 and s.IsPlaying then s:Stop() end
		end)
	end
end

-- Crossfade entre trechos de chase (so 1 toca)
local function xfc(oldSeg: number, newSeg: number): ()
	if oldSeg == newSeg then return end
	if oldSeg >= 1 and oldSeg <= 4 then fd(ch[oldSeg], 0) end
	if newSeg >= 1 and newSeg <= 4 then fd(ch[newSeg], 1) end
end

-- FUGA: 1 so, toca do inicio, nao reinicia
local function startF(): ()
	if not fug then return end
	if fug.IsPlaying then fug:Stop() end
	fug.TimePosition = 0; fug.Looped = false
	fug.Volume = 0; fug:Play()
	fd(fug, 1); fugOn = true
end

local function stopAll(): ()
	fd(lby, 0); fd(amb, 0)
	for i = 1, 4 do fd(ch[i], 0) end; curSeg = 0
end

local function updMusic(st: string, seg: number): ()
	if st == curSt then
		if st == "Playing" and seg ~= curSeg then xfc(curSeg, seg); curSeg = seg end
		return
	end
	curSt = st

	if st == "Fuga" then
		fd(lby, 0); fd(amb, 0)
		for i = 1, 4 do fd(ch[i], 0) end; curSeg = 0
		if fugOn then fd(fug, 1) end
		return
	end

	if fugOn then fd(fug, 0); fugOn = false end
	stopAll(); ct()

	if st == "Lobby" then
		fd(lby, 1)
	elseif st == "Playing" then
		fd(amb, 1)
		if seg >= 1 and seg <= 4 then fd(ch[seg], 1); curSeg = seg end
	elseif st == "PreFuga" then
		startF()
	end
end

-- Edge distortion UI
local function mkEdge()
	eGui = Instance.new("ScreenGui")
	eGui.Name = "AudioEdgeDistortion"; eGui.ResetOnSpawn = false
	eGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	eGui.Parent = LP:WaitForChild("PlayerGui")
	vig = Instance.new("Frame")
	vig.Name = "Vignette"; vig.Size = UDim2.new(1, 0, 1, 0)
	vig.BackgroundTransparency = 1; vig.BorderSizePixel = 0; vig.ZIndex = 10
	vig.Parent = eGui
	local function e(n: string, sz: UDim2, pos: UDim2): Frame
		local f = Instance.new("Frame")
		f.Name = n; f.Size = sz; f.Position = pos
		f.BackgroundColor3 = Color3.fromRGB(0, 0, 0); f.BackgroundTransparency = 1
		f.BorderSizePixel = 0; f.ZIndex = 10; f.Parent = vig; return f
	end
	eFr[1] = e("Top",    UDim2.new(1, 0, 0, 80),  UDim2.new(0, 0, 0, 0))
	eFr[2] = e("Bottom", UDim2.new(1, 0, 0, 80),  UDim2.new(0, 0, 1, -80))
	eFr[3] = e("Left",   UDim2.new(0, 60, 1, 0),   UDim2.new(0, 0, 0, 0))
	eFr[4] = e("Right",  UDim2.new(0, 60, 1, 0),   UDim2.new(1, -60, 0, 0))
end

local function updEdge(d: number): ()
	if not vig then return end
	local a: number
	if d >= ER or d <= 0 then a = 0
	else a = 0.5 * (1 - d / ER) end
	for _, f in ipairs(eFr) do if f then f.BackgroundTransparency = 1 - a end end
end

-- Heartbeat
local function updHB(d: number, int: string?): ()
	if not hb then return end
	if d >= HR or d <= 0 then
		if hb.IsPlaying then hb:Stop(); hb.Volume = 0 end; return
	end
	local pf = 1 - math.clamp(d / HR, 0, 1)
	local vol = 0.2 + 0.8 * pf; local spd = 1.0 + 1.5 * pf
	if int == "damaged" then vol = math.min(1, vol + 0.3); spd = math.min(3, spd + 0.5) end
	hb.Volume = vol; hb.PlaybackSpeed = spd
	if not hb.IsPlaying then hb:Play() end
end

-- SFX
local function pSfx(id: string, nm: string, vol: number?): ()
	local s = gsx(id, nm); s.Volume = vol or 0.8
	if s.IsPlaying then s:Stop() end; s:Play()
end

local function hSfx(tp: string): ()
	if     tp == "mission_complete" then pSfx(ID.MC,   "MC",   0.7)
	elseif tp == "player_died"      then pSfx(ID.PD,   "PD",   0.9)
	elseif tp == "player_damaged"   then pSfx(ID.DMG,  "DMG",  0.6)
	elseif tp == "rage_activate"    then pSfx(ID.RAGE, "RAGE", 1.0)
	elseif tp == "gate_open"        then pSfx(ID.GATE, "GATE", 0.8)
	elseif tp == "fire"             then pSfx(ID.FIRE, "FIRE", 0.6)
	elseif tp == "escape_start"     then pSfx(ID.ESC,  "ESC",  1.0)
	end
end

-- Server commands
local function onCmd(_: Player, msg: {any}): ()
	local d = msg.data
	if msg.type == "AUDIO_MUSIC_STATE" then
		updMusic(d and d.layerState or "Lobby", d and d.chaseSegment or 0)
	elseif msg.type == "AUDIO_SFX" then
		if d and d.sfx then hSfx(d.sfx) end
	elseif msg.type == "AUDIO_HEARTBEAT" then
		local prox = d and d.proximity or math.huge
		updHB(prox, d and d.intensity); updEdge(prox)
	end
end

-- Init/Start/Stop
function AudioManager.Init(): ()
	mkEdge()
	lby   = mk(ID.L,  "Music_Lobby",  true)
	amb   = mk(ID.M,  "Music_MapAmb", true)
	ch[1] = mk(ID.C1, "Music_ChS1",   true)
	ch[2] = mk(ID.C2, "Music_ChS2",   true)
	ch[3] = mk(ID.C3, "Music_ChS3",   true)
	ch[4] = mk(ID.C4, "Music_ChS4",   true)
	fug   = mk(ID.F,  "Music_Fuga",   false)  -- nao loop
	hb    = mk(ID.HB, "Heartbeat",    true)
	local ev = RS:FindFirstChild("Events")
	if ev then gse = RU.findRemoteEvent(ev, "GameStateEvent") end
end

function AudioManager.Start(): ()
	if gse then
		gsc = gse.OnClientEvent:Connect(onCmd)
		if lby then lby.Volume = 1; lby:Play(); curSt = "Lobby" end
	end
end

function AudioManager.stopAll(): ()
	if lby and lby.IsPlaying then lby:Stop() end; lby = nil
	if amb and amb.IsPlaying then amb:Stop() end; amb = nil
	for i = 1, 4 do if ch[i] and ch[i].IsPlaying then ch[i]:Stop() end; ch[i] = nil end
	if fug and fug.IsPlaying then fug:Stop() end; fug = nil
	if hb then hb:Stop(); hb = nil end
	for _, s in pairs(sfx) do if s.IsPlaying then s:Stop() end end; sfx = {}
	ct()
	if eGui then eGui:Destroy(); eGui = nil; vig = nil; eFr = {} end
	if fld then fld:Destroy(); fld = nil end
	if gsc then gsc:Disconnect(); gsc = nil end
	curSt = ""; curSeg = 0; fugOn = false
end

return AudioManager
