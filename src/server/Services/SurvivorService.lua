--!strict
--[[
  SurvivorService.lua
  Servico que gerencia o estado e habilidades dos Sobreviventes.
  4 classes: Medico, Soldado, Sackboy, Robo.

  Sinais expostos:
    survivorDamaged  - quando um Sobrevivente toma dano
    survivorHealed   - quando um Sobrevivente recebe cura
    survivorDied     - quando um Sobrevivente morre (HP -> 0)
    abilityUsed      - quando uma habilidade e usada (para SFX/particulas)

  Referencias: GDD Sobreviventes, GameConstants.Survivors
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)

local SurvivorService = {}
SurvivorService.Name = "SurvivorService"

-- ============================================================
-- Sinais do servico
-- ============================================================
SurvivorService.survivorDamaged = Signal.new()  -- (player: Player, damage: number, source: Player)
SurvivorService.survivorHealed = Signal.new()   -- (player: Player, amount: number, healer: Player)
SurvivorService.survivorDied = Signal.new()     -- (player: Player)
SurvivorService.abilityUsed = Signal.new()      -- (player: Player, abilityName: string, className: string)

-- ============================================================
-- Estado interno
-- ============================================================
type SurvivorExtState = {
	userId: number,
	class: string,
	cooldowns: { [string]: number },
	humanoid: Humanoid,
	rootPart: BasePart,
	-- Medico
	healCounter: number,          -- Aliados curados desde o ultimo acerto de A2
	healedAllyIds: { number },    -- IDs ja curados no ciclo atual (evita double-count)
	isDashing: boolean,
	originalSpeed: number,
	-- Soldado
	isAiming: boolean,
	aimStartTime: number,
	soldadoDashActive: boolean,
	-- Sackboy
	isCharging: boolean,
	chargeLevel: number,
	chargeStartTime: number,
	surgeActive: boolean,
	surgeEndTime: number,
	-- Robo
	isBlocking: boolean,
	blockEndTime: number,
	isSelfDestructing: boolean,
	selfDestructPhase: string,     -- "none" | "windup" | "boost"
	selfDestructTimer: number,
	isGrabbing: boolean,
	-- LMS
	lmsActive: boolean,
}

local _survivorExt: { [number]: SurvivorExtState } = {}

-- Referencias injetadas
local _matchService = nil
local _gameStateEvent = nil
local _playerActionEvent = nil
local _uiSyncEvent = nil

-- ============================================================
-- Helpers: acesso ao estado
-- ============================================================

--[[
  Obtem ou cria o estado estendido de um Sobrevivente.
]]
local function getOrCreateExt(player: Player): SurvivorExtState
	local userId = player.UserId
	if _survivorExt[userId] then
		return _survivorExt[userId]
	end

	local data = _matchService:getPlayerData(player)
	if not data or data.role ~= "Survivor" then
		return nil
	end

	local ext: SurvivorExtState = {
		userId = userId,
		class = data.survivorClass or "Medico",
		cooldowns = {},
		humanoid = nil,
		rootPart = nil,
		-- Medico
		healCounter = 0,
		healedAllyIds = {},
		isDashing = false,
		originalSpeed = 22,
		-- Soldado
		isAiming = false,
		aimStartTime = 0,
		soldadoDashActive = false,
		-- Sackboy
		isCharging = false,
		chargeLevel = 0,
		chargeStartTime = 0,
		surgeActive = false,
		surgeEndTime = 0,
		-- Robo
		isBlocking = false,
		blockEndTime = 0,
		isSelfDestructing = false,
		selfDestructPhase = "none",
		selfDestructTimer = 0,
		isGrabbing = false,
		-- LMS
		lmsActive = false,
	}

	_survivorExt[userId] = ext
	return ext
end

--[[
  Atualiza as referencias de humanoid/rootPart do estado.
]]
local function refreshCharacterRefs(ext: SurvivorExtState, player: Player): ()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		ext.humanoid = humanoid
	end
	if rootPart then
		ext.rootPart = rootPart
	end
end

-- ============================================================
-- Helpers: cooldowns
-- ============================================================

--[[
  Verifica se uma habilidade esta disponivel (fora de cooldown).
]]
local function canUseAbility(ext: SurvivorExtState, abilityName: string): boolean
	local cdEnd: number = ext.cooldowns[abilityName]
	if not cdEnd then
		return true
	end
	return os.clock() >= cdEnd
end

--[[
  Inicia o cooldown de uma habilidade.
  Notifica o cliente via UISyncEvent.
]]
local function startCooldown(ext: SurvivorExtState, abilityName: string, durationSec: number): ()
	ext.cooldowns[abilityName] = os.clock() + durationSec
	if _uiSyncEvent then
		-- Buscar o Player pelo userId
		local player = Players:GetPlayerByUserId(ext.userId)
		if player then
			RemoteEventUtils.firePlayer(
				_uiSyncEvent,
				player,
				"COOLDOWN_START",
				{ ability = abilityName, duration = durationSec }
			)
		end
	end
end

-- ============================================================
-- Helpers: validacao
-- ============================================================

--[[
  Verifica se o Sobrevivente esta apto a usar habilidades.
]]
local function validateSurvivorAction(ext: SurvivorExtState): boolean
	if not ext.humanoid or ext.humanoid.Health <= 0 then
		return false  -- Morto
	end
	if ext.isSelfDestructing then
		return false  -- Em Autodestruicao
	end
	if ext.isGrabbing then
		return false  -- Em Agarrar
	end
	return true
end

-- ============================================================
-- Helpers: efeitos no Cacador
-- ============================================================

--[[
  Aplica dano ao Cacador via MatchService.
  Retorna true se o Cacador morreu.
]]
local function damageHunter(hunter: Player, damage: number, sourcePlayer: Player): boolean
	local killed = _matchService.applyDamage(hunter, damage, sourcePlayer)
	if killed then
		print("[TheBrokenBox] SurvivorService: Cacador morreu! Dano: " .. damage .. " por " .. sourcePlayer.Name)
	end
	return killed
end

--[[
  Aplica lentidao ao Cacador (multiplicador de velocidade).
  Ex.: slowAmount = 30 reduz WalkSpeed em 30%.
]]
local function slowHunter(hunter: Player, slowPercent: number, durationSec: number): ()
	local character = hunter.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local baseSpeed = GameConstants.Hunter.BASE_SPEED
	local rageSpeed = GameConstants.Hunter.RAGE_SPEED
	local currentBase = baseSpeed
	-- Verifica se esta em Rage (aproximacao: checando speed atual)
	if humanoid.WalkSpeed > baseSpeed + 1 then
		currentBase = rageSpeed
	end

	local multiplier = 1 - (slowPercent / 100)
	humanoid.WalkSpeed = currentBase * multiplier

	task.delay(durationSec, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = currentBase
		end
	end)
end

--[[
  Aplica stun no Cacador: trava movimento e habilidades.
  Nota: i-frames de 2s pos-stun sao gerenciados pelo HunterService.
  Por enquanto, apenas paramos o movimento.
]]
local function stunHunter(hunter: Player, durationSec: number): ()
	local character = hunter.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0

	task.delay(durationSec, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end

--[[
  Empurra o Cacador para longe do Sobrevivente.
]]
local function knockbackHunter(hunter: Player, fromPosition: Vector3, distance: number): ()
	local character = hunter.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local direction = (rootPart.Position - fromPosition)
	if direction.Magnitude < 1/100 then
		direction = Vector3.new(1, 0, 0)
	end
	direction = direction.Unit

	rootPart.AssemblyLinearVelocity = direction * (distance * 10)
end

-- ============================================================
-- Helpers: Hitbox
-- ============================================================

--[[
  Verifica se um jogador esta dentro de um cubo centrado em origin.
]]
local function isPlayerInCube(player: Player, origin: Vector3, halfSize: number): boolean
	local character = player.Character
	if not character then
		return false
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	local delta = rootPart.Position - origin
	return math.abs(delta.X) <= halfSize
		and math.abs(delta.Y) <= halfSize
		and math.abs(delta.Z) <= halfSize
end

--[[
  Verifica colisao de linha 3x3x100 (para Bazuca e Tinta).
  Retorna o primeiro alvo atingido ou nil.
  Para na parede (raycast).
]]
local function checkLineHitbox(
	origin: Vector3,
	direction: Vector3,
	distance: number,
	targetIsHunter: boolean
): (Player?, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist

	-- Filtra todos os survivors ou hunter dependendo do alvo
	local players = Players:GetPlayers()
	local filterList = {}
	for _, p in ipairs(players) do
		local data = _matchService:getPlayerData(p)
		if data then
			local isTarget = targetIsHunter and (data.role == "Hunter")
				or (not targetIsHunter and data.role == "Survivor")
			if not isTarget and p.Character then
				table.insert(filterList, p.Character)
			end
		end
	end
	params.FilterDescendantsInstances = filterList

	local result = workspace:Raycast(origin, direction * distance, params)
	if result and result.Instance then
		-- Encontrou parede, para aqui
		local hitCharacter = result.Instance:FindFirstAncestorOfClass("Model")
		-- Se acertou parede, retorna nil
		return nil, result.Position
	end

	-- Verifica se algum personagem esta na linha (por distancia)
	for _, p in ipairs(players) do
		local data = _matchService:getPlayerData(p)
		if data then
			local isTarget = targetIsHunter and (data.role == "Hunter")
				or (not targetIsHunter and data.role == "Survivor")
			if isTarget and p.Character then
				local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local toTarget = rootPart.Position - origin
					local proj = toTarget:Dot(direction)
					if proj > 0 and proj < distance then
						local closestPoint = origin + direction * proj
						local lateralDist = (rootPart.Position - closestPoint).Magnitude
						if lateralDist < 3 then  -- Hitbox 3x3
							return p, nil
						end
					end
				end
			end
		end
	end

	return nil, nil
end

-- ============================================================
-- MEDICO - Habilidades
-- ============================================================

local MEDICO = GameConstants.Survivors.MEDICO

--[[
  Medico A1: Pocao em Area
  - windup 2s, cd 15s, cura 25 em raio 12
  - Cada aliado curado incrementa o contador da A2
]]
local function medicoA1(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Potion") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end

	startCooldown(ext, "Potion", MEDICO.POTION.COOLDOWN)

	local rootPart = ext.rootPart
	if not rootPart then
		return
	end

	print("[TheBrokenBox] Medico " .. player.Name .. ": Pocao em Area - windup " .. MEDICO.POTION.WINDUP .. "s")

	-- Windup
	task.delay(MEDICO.POTION.WINDUP, function()
		if not ext.rootPart or ext.humanoid.Health <= 0 then
			return
		end

		local origin = ext.rootPart.Position
		local radius = MEDICO.POTION.RADIUS
		local healAmount = MEDICO.POTION.HEAL

		-- Iterar sobre todos os Sobreviventes
		local survivors = _matchService.getPlayersByRole("Survivor")
		for _, targetPlayer in survivors do
			if targetPlayer ~= player then
				local targetData = _matchService:getPlayerData(targetPlayer)
				if targetData and targetData.isAlive and targetData.survivorClass ~= "Robo" then
					if isPlayerInCube(targetPlayer, origin, radius) then
						_matchService.healPlayer(targetPlayer, healAmount)
						SurvivorService.survivorHealed:Fire(targetPlayer, healAmount, player)

						-- Incrementa contador de A2 (sem double-count)
						local allyId = targetPlayer.UserId
						local alreadyHealed = false
						for _, id in ipairs(ext.healedAllyIds) do
							if id == allyId then
								alreadyHealed = true
								break
							end
						end
						if not alreadyHealed then
							table.insert(ext.healedAllyIds, allyId)
							ext.healCounter = ext.healCounter + 1
							print("[TheBrokenBox] Medico " .. player.Name ..
								": curou " .. targetPlayer.Name .. " (contador: " .. ext.healCounter .. ")")
						end
					end
				end
			end
		end

		SurvivorService.abilityUsed:Fire(player, "Potion", "Medico")
	end)
end

--[[
  Medico A2: Investida Medicinal
  - windup 1s, cd 10s, dash 15 studs, cubo 10 ao redor de si
  - Dano 0/10/20/30 escalado por aliados curados
  - Efeitos: push (0), push+silence 3s (1), push+silence 5s (2), stun 3s+self speed+self heal 20 (3+)
  - Contador zera ao acertar o Cacador
]]
local function medicoA2(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Charge") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end
	if ext.isDashing then
		return
	end

	startCooldown(ext, "Charge", MEDICO.CHARGE.COOLDOWN)

	local rootPart = ext.rootPart
	local humanoid = ext.humanoid
	if not rootPart or not humanoid then
		return
	end

	print("[TheBrokenBox] Medico " .. player.Name .. ": Investida Medicinal - windup " .. MEDICO.CHARGE.WINDUP .. "s")

	ext.isDashing = true

	-- Windup
	task.delay(MEDICO.CHARGE.WINDUP, function()
		if not ext.rootPart or not ext.humanoid or ext.humanoid.Health <= 0 then
			ext.isDashing = false
			return
		end

		local lookDirection = ext.rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		if lookDirection.Magnitude < 1/10 then
			lookDirection = Vector3.new(1, 0, 0)
		end
		lookDirection = lookDirection.Unit

		local dashSpeed = MEDICO.CHARGE.DASH_DISTANCE / 3/10  -- ~50 studs/s, rapido
		local dashVelocity = lookDirection * dashSpeed

		-- Dash via BodyVelocity
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = dashVelocity
		bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 1e5
		bodyVelocity.P = 10000
		bodyVelocity.Parent = ext.rootPart

		-- Hitbox durante o dash
		local hitHunter = false
		local dashStart = os.clock()
		local dashDuration = 3/10

		local dashConnection: RBXScriptConnection
		dashConnection = RunService.Heartbeat:Connect(function()
			if os.clock() - dashStart > dashDuration then
				if dashConnection then
					dashConnection:Disconnect()
				end
				bodyVelocity:Destroy()
				ext.isDashing = false
				return
			end

			if hitHunter then
				return
			end

			local hunter = _matchService.getHunter()
			if not hunter then
				return
			end

			local cubeRadius = MEDICO.CHARGE.RADIUS / 2

			if isPlayerInCube(hunter, ext.rootPart.Position, cubeRadius) then
				hitHunter = true

				local counter = ext.healCounter
				local damage = MEDICO.CHARGE.DAMAGE[math.min(counter + 1, 4)]

				-- Aplica dano
				if damage > 0 then
					damageHunter(hunter, damage, player)
				end

				-- Efeitos baseados no contador
				if counter == 0 then
					-- Apenas push
					knockbackHunter(hunter, ext.rootPart.Position, 5)
				elseif counter == 1 then
					knockbackHunter(hunter, ext.rootPart.Position, 8)
					slowHunter(hunter, 100, 3)  -- Silence approximation: slow total por 3s
				elseif counter == 2 then
					knockbackHunter(hunter, ext.rootPart.Position, 12)
					slowHunter(hunter, 100, 5)
				else
					-- 3+: stun 3s + self buff
					stunHunter(hunter, 3)
					if ext.humanoid then
						ext.humanoid.WalkSpeed = ext.originalSpeed + 4
					end
					_matchService.healPlayer(player, 20)
					SurvivorService.survivorHealed:Fire(player, 20, player)
				end

				-- Zera contador
				ext.healCounter = 0
				table.clear(ext.healedAllyIds)

				print("[TheBrokenBox] Medico " .. player.Name ..
					": Investida acertou! Dano: " .. damage .. ", Contador zerado.")

				if dashConnection then
					dashConnection:Disconnect()
				end
				bodyVelocity:Destroy()
				ext.isDashing = false
			end
		end)

		SurvivorService.abilityUsed:Fire(player, "Charge", "Medico")
	end)
end

-- ============================================================
-- SOLDADO - Habilidades
-- ============================================================

local SOLDADO = GameConstants.Survivors.SOLDADO

--[[
  Soldado A1: Dash Tatico
  - windup 0.5s, cd 20s, hitbox movel, ate 15s, para em Hunter/parede
  - Dano 20, push 10 + silence 3s
]]
local function soldadoA1(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Dash") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end
	if ext.soldadoDashActive then
		return
	end

	startCooldown(ext, "Dash", SOLDADO.DASH.COOLDOWN)

	local rootPart = ext.rootPart
	local humanoid = ext.humanoid
	if not rootPart or not humanoid then
		return
	end

	print("[TheBrokenBox] Soldado " .. player.Name .. ": Dash Tatico - windup " .. SOLDADO.DASH.WINDUP .. "s")

	ext.soldadoDashActive = true
	ext.originalSpeed = humanoid.WalkSpeed

	-- Windup
	task.delay(SOLDADO.DASH.WINDUP, function()
		if not ext.rootPart or not ext.humanoid or ext.humanoid.Health <= 0 then
			ext.soldadoDashActive = false
			return
		end

		local lookDirection = ext.rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		if lookDirection.Magnitude < 1/10 then
			lookDirection = Vector3.new(1, 0, 0)
		end
		lookDirection = lookDirection.Unit

		local dashSpeed = 40  -- studs/s
		local dashVelocity = lookDirection * dashSpeed

		-- Usar velocidade do Humanoid
		humanoid.WalkSpeed = dashSpeed

		local hitHunter = false
		local dashStart = os.clock()
		local maxDuration = SOLDADO.DASH.DURATION_MAX

		local dashConnection: RBXScriptConnection
		dashConnection = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - dashStart

			if elapsed > maxDuration or hitHunter then
				if dashConnection then
					dashConnection:Disconnect()
				end
				humanoid.WalkSpeed = ext.originalSpeed
				ext.soldadoDashActive = false
				return
			end

			if hitHunter then
				return
			end

			-- Check wall collision
			local rayOrigin = ext.rootPart.Position
			local rayResult = workspace:Raycast(rayOrigin, lookDirection * 3)
			if rayResult then
				-- Hit wall, stop dash
				if dashConnection then
					dashConnection:Disconnect()
				end
				humanoid.WalkSpeed = ext.originalSpeed
				ext.soldadoDashActive = false
				return
			end

			-- Check Hunter proximity
			local hunter = _matchService.getHunter()
			if not hunter then
				return
			end

			local hunterRoot = hunter.Character and hunter.Character:FindFirstChild("HumanoidRootPart")
			if hunterRoot then
				local dist = (ext.rootPart.Position - hunterRoot.Position).Magnitude
				if dist < 5 then  -- Hitbox de colisao
					hitHunter = true

					damageHunter(hunter, SOLDADO.DASH.DAMAGE, player)
					knockbackHunter(hunter, ext.rootPart.Position, SOLDADO.DASH.KNOCKBACK)
					slowHunter(hunter, 100, SOLDADO.DASH.SILENCE_DURATION)

					print("[TheBrokenBox] Soldado " .. player.Name .. ": Dash acertou! Dano: " .. SOLDADO.DASH.DAMAGE)

					if dashConnection then
						dashConnection:Disconnect()
					end
					humanoid.WalkSpeed = ext.originalSpeed
					ext.soldadoDashActive = false
				end
			end
		end)

		SurvivorService.abilityUsed:Fire(player, "Dash", "Soldado")
	end)
end

--[[
  Soldado A2: Bazuca
  - windup 2s, cd 30s (15s cancel), aim ate 10s, hitscan 3x3x100
  - Dano 40, para na parede
]]
local function soldadoA2(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Bazooka") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end

	local rootPart = ext.rootPart
	if not rootPart then
		return
	end

	print("[TheBrokenBox] Soldado " .. player.Name .. ": Bazuca - windup " .. SOLDADO.BAZOOKA.WINDUP .. "s")

	startCooldown(ext, "Bazooka", SOLDADO.BAZOOKA.COOLDOWN)

	-- Windup
	task.delay(SOLDADO.BAZOOKA.WINDUP, function()
		if not ext.rootPart or not ext.humanoid or ext.humanoid.Health <= 0 then
			return
		end

		-- Hitscan instantaneo na direcao do olhar
		local lookDirection = ext.rootPart.CFrame.LookVector
		local origin = ext.rootPart.Position + lookDirection * 3  -- Origem um pouco a frente

		local hitTarget, hitPos = checkLineHitbox(origin, lookDirection, SOLDADO.BAZOOKA.HITBOX[3], true)

		if hitTarget then
			damageHunter(hitTarget, SOLDADO.BAZOOKA.DAMAGE, player)
			print("[TheBrokenBox] Soldado " .. player.Name .. ": Bazuca acertou! Dano: " .. SOLDADO.BAZOOKA.DAMAGE)
		else
			print("[TheBrokenBox] Soldado " .. player.Name .. ": Bazuca errou.")
		end

		SurvivorService.abilityUsed:Fire(player, "Bazooka", "Soldado")
	end)
end

-- ============================================================
-- SACKBOY - Habilidades
-- ============================================================

local SACKBOY = GameConstants.Survivors.SACKBOY

--[[
  Sackboy A1: Arma de Tinta
  - 3 cargas (1s/2s/3s windup), cd 30s
  - C1: slow 30%/2s + 5 dmg
  - C2: slow 40%/2s + silence 4s + 10 dmg
  - C3: stun 2s + blur + 15 dmg
  - Hitbox: linha 3x3x100, para na parede
]]
local function sackboyA1(player: Player, ext: SurvivorExtState, chargeLevel: number): ()
	if not canUseAbility(ext, "Ink") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end

	-- Garantir que o nivel de carga e valido
	chargeLevel = math.clamp(chargeLevel, 1, SACKBOY.INK.MAX_CHARGES)

	startCooldown(ext, "Ink", SACKBOY.INK.COOLDOWN)

	local rootPart = ext.rootPart
	if not rootPart then
		return
	end

	print("[TheBrokenBox] Sackboy " .. player.Name .. ": Arma de Tinta C" .. chargeLevel)

	local lookDirection = rootPart.CFrame.LookVector
	local origin = rootPart.Position + lookDirection * 3

	local INK = SACKBOY.INK
	local hitTarget, _ = checkLineHitbox(origin, lookDirection, INK.HITBOX[3], true)

	if hitTarget then
		local damage = INK.DAMAGE[chargeLevel]
		damageHunter(hitTarget, damage, player)

		-- Efeitos por carga
		local slowPct = INK.SLOW[chargeLevel]
		local slowDur = INK.SLOW_DURATION

		if chargeLevel == 1 then
			-- Slow 30% / 2s
			slowHunter(hitTarget, slowPct, slowDur)
		elseif chargeLevel == 2 then
			-- Slow 40% / 2s + silence 4s
			slowHunter(hitTarget, slowPct, slowDur)
			slowHunter(hitTarget, 100, INK.SILENCE_DURATION[chargeLevel])
		elseif chargeLevel == 3 then
			-- Stun 2s + blur
			stunHunter(hitTarget, INK.STUN_DURATION[chargeLevel])
		end

		print("[TheBrokenBox] Sackboy " .. player.Name .. ": Tinta C" .. chargeLevel .. " acertou! Dano: " .. damage)
	else
		print("[TheBrokenBox] Sackboy " .. player.Name .. ": Tinta C" .. chargeLevel .. " errou.")
	end

	SurvivorService.abilityUsed:Fire(player, "Ink", "Sackboy")
end

--[[
  Sackboy A2: Surto
  - cd 20s, +6 speed + jump boost por 5s
]]
local function sackboyA2(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Surge") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end

	startCooldown(ext, "Surge", SACKBOY.SURGE.COOLDOWN)

	local humanoid = ext.humanoid
	if not humanoid then
		return
	end

	print("[TheBrokenBox] Sackboy " .. player.Name .. ": Surto! +6 speed por " .. SACKBOY.SURGE.DURATION .. "s")

	ext.originalSpeed = humanoid.WalkSpeed
	ext.surgeActive = true
	ext.surgeEndTime = os.clock() + SACKBOY.SURGE.DURATION

	local newSpeed = ext.originalSpeed + SACKBOY.SURGE.SPEED_BONUS
	humanoid.WalkSpeed = newSpeed
	humanoid.JumpPower = 70  -- Jump boost

	task.delay(SACKBOY.SURGE.DURATION, function()
		if ext.humanoid and ext.humanoid.Parent then
			ext.surgeActive = false
			if not ext.lmsActive then
				ext.humanoid.WalkSpeed = ext.originalSpeed
			end
			ext.humanoid.JumpPower = 50
			print("[TheBrokenBox] Sackboy " .. player.Name .. ": Surto terminou.")
		end
	end)

	SurvivorService.abilityUsed:Fire(player, "Surge", "Sackboy")
end

-- ============================================================
-- ROBO - Habilidades
-- ============================================================

local ROBO = GameConstants.Survivors.ROBO

--[[
  Robo A1: Agarrar
  - windup 1s, cd 22s, projetil 15/s x 2s (30 range)
  - Puxa o Cacador, da 8s invencibilidade + silence
]]
local function roboA1(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Grab") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end
	if ext.isGrabbing then
		return
	end

	startCooldown(ext, "Grab", ROBO.GRAB.COOLDOWN)

	local rootPart = ext.rootPart
	if not rootPart then
		return
	end

	print("[TheBrokenBox] Robo " .. player.Name .. ": Agarrar - windup " .. ROBO.GRAB.WINDUP .. "s")

	-- Windup: Robo fica imovel
	ext.isGrabbing = true
	local origSpeed = ext.humanoid and ext.humanoid.WalkSpeed or 18
	if ext.humanoid then
		ext.humanoid.WalkSpeed = 0
	end

	task.delay(ROBO.GRAB.WINDUP, function()
		if not ext.rootPart or not ext.humanoid or ext.humanoid.Health <= 0 then
			ext.isGrabbing = false
			if ext.humanoid then
				ext.humanoid.WalkSpeed = origSpeed
			end
			return
		end

		local lookDirection = ext.rootPart.CFrame.LookVector
		local origin = ext.rootPart.Position

		-- Projetil via raycast
		local hitTarget, _ = checkLineHitbox(origin, lookDirection, ROBO.GRAB.RANGE, true)

		if hitTarget then
			local hunterChar = hitTarget.Character
			if hunterChar then
				local hunterRoot = hunterChar:FindFirstChild("HumanoidRootPart")
				if hunterRoot then
					-- Puxa o Cacador para perto do Robo
					local pullDirection = (ext.rootPart.Position - hunterRoot.Position).Unit
					hunterRoot.AssemblyLinearVelocity = pullDirection * 40

					-- 8s invencibilidade + silence
					print("[TheBrokenBox] Robo " .. player.Name .. ": Agarrar acertou! Cacador puxado.")
				end
			end
		else
			print("[TheBrokenBox] Robo " .. player.Name .. ": Agarrar errou.")
		end

		-- Robo fica imovel ate o braco voltar
		local grabEnd = os.clock() + ROBO.GRAB.DURATION

		local grabConnection: RBXScriptConnection
		grabConnection = RunService.Heartbeat:Connect(function()
			if os.clock() >= grabEnd then
				ext.isGrabbing = false
				if ext.humanoid then
					ext.humanoid.WalkSpeed = origSpeed
				end
				if grabConnection then
					grabConnection:Disconnect()
				end
			end
		end)

		SurvivorService.abilityUsed:Fire(player, "Grab", "Robo")
	end)
end

--[[
  Robo A2: Block
  - janela 1.5s, cd 14s
  - Se atingido: silence 3s no Cacador + autocura 10
]]
local function roboA2(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "Block") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end
	if ext.isBlocking then
		return
	end

	startCooldown(ext, "Block", ROBO.BLOCK.COOLDOWN)

	print("[TheBrokenBox] Robo " .. player.Name .. ": Block ativado - janela " .. ROBO.BLOCK.WINDOW .. "s")

	ext.isBlocking = true
	ext.blockEndTime = os.clock() + ROBO.BLOCK.WINDOW

	task.delay(ROBO.BLOCK.WINDOW, function()
		ext.isBlocking = false
		print("[TheBrokenBox] Robo " .. player.Name .. ": Block expirou.")
	end)

	SurvivorService.abilityUsed:Fire(player, "Block", "Robo")
end

--[[
  Callback chamado quando o Robo toma dano durante Block.
  Retorna true se o Block contra-atacou e o dano deve ser anulado.
]]
function SurvivorService.checkRoboBlock(player: Player): boolean
	local ext = _survivorExt[player.UserId]
	if not ext or not ext.isBlocking then
		return false
	end

	if os.clock() > ext.blockEndTime then
		ext.isBlocking = false
		return false
	end

	-- Contra-ataque! Silencia o Cacador + autocura
	local hunter = _matchService.getHunter()
	if hunter then
		slowHunter(hunter, 100, ROBO.BLOCK.SILENCE_DURATION)
		damageHunter(hunter, ROBO.BLOCK.DAMAGE, player)
	end

	_matchService.healPlayer(player, ROBO.BLOCK.SELF_HEAL)
	SurvivorService.survivorHealed:Fire(player, ROBO.BLOCK.SELF_HEAL, player)

	ext.isBlocking = false
	print("[TheBrokenBox] Robo " .. player.Name .. ": Block contra-atacou! Cura " .. ROBO.BLOCK.SELF_HEAL)

	return true
end

--[[
  Robo A3: Autodestruicao
  - windup 3s, cd 60s, boost de velocidade 5s -> explode
  - 100 dano ao Cacador (arremessa 100 + stun 6s)
  - Auto-dano 40 + slow 8s
]]
local function roboA3(player: Player, ext: SurvivorExtState): ()
	if not canUseAbility(ext, "SelfDestruct") then
		return
	end
	if not validateSurvivorAction(ext) then
		return
	end
	if ext.isSelfDestructing then
		return
	end

	startCooldown(ext, "SelfDestruct", ROBO.SELFDESTRUCT.COOLDOWN)

	local humanoid = ext.humanoid
	local rootPart = ext.rootPart
	if not humanoid or not rootPart then
		return
	end

	print("[TheBrokenBox] Robo " .. player.Name .. ": Autodestruicao - windup " .. ROBO.SELFDESTRUCT.WINDUP .. "s")

	ext.isSelfDestructing = true
	ext.selfDestructPhase = "windup"

	-- Windup 3s (parado)
	local origSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0

	task.delay(ROBO.SELFDESTRUCT.WINDUP, function()
		if not ext.rootPart or not ext.humanoid or ext.humanoid.Health <= 0 then
			ext.isSelfDestructing = false
			ext.selfDestructPhase = "none"
			return
		end

		-- Boost de velocidade 5s
		print("[TheBrokenBox] Robo " .. player.Name .. ": Autodestruicao - boost!")
		ext.selfDestructPhase = "boost"
		local boostSpeed = origSpeed * 15/10
		humanoid.WalkSpeed = boostSpeed

		task.delay(ROBO.SELFDESTRUCT.BOOST_DURATION, function()
			if not ext.rootPart or not ext.humanoid or ext.humanoid.Health <= 0 then
				ext.isSelfDestructing = false
				ext.selfDestructPhase = "none"
				return
			end

			-- EXPLODE!
			print("[TheBrokenBox] Robo " .. player.Name .. ": Autodestruicao - EXPLODE!")

			local origin = ext.rootPart.Position

			-- Auto-dano 40
			_matchService.applyDamage(player, ROBO.SELFDESTRUCT.SELF_DAMAGE, player)
			SurvivorService.survivorDamaged:Fire(player, ROBO.SELFDESTRUCT.SELF_DAMAGE, player)

			-- Auto-slow 8s
			humanoid.WalkSpeed = origSpeed * 5/10

			task.delay(ROBO.SELFDESTRUCT.SLOW_DURATION, function()
				if humanoid and humanoid.Parent then
					humanoid.WalkSpeed = origSpeed
				end
			end)

			-- Dano no Cacador
			local hunter = _matchService.getHunter()
			if hunter then
				local hunterRoot = hunter.Character and hunter.Character:FindFirstChild("HumanoidRootPart")
				if hunterRoot then
					local dist = (hunterRoot.Position - origin).Magnitude
					if dist < 40 then  -- Raio da explosao
						damageHunter(hunter, ROBO.SELFDESTRUCT.DAMAGE, player)

						-- Arremessa 100 studs
						local throwDir = (hunterRoot.Position - origin).Unit
						if throwDir.Magnitude < 1/10 then
							throwDir = Vector3.new(1, 1, 0).Unit
						end
						hunterRoot.AssemblyLinearVelocity = throwDir * (ROBO.SELFDESTRUCT.THROW_DISTANCE * 2)

						-- Stun 6s
						stunHunter(hunter, ROBO.SELFDESTRUCT.STUN_DURATION)

						print("[TheBrokenBox] Robo " .. player.Name .. ": Autodestruicao acertou o Cacador! Dano: " .. ROBO.SELFDESTRUCT.DAMAGE)
					end
				end
			end

			ext.isSelfDestructing = false
			ext.selfDestructPhase = "none"

			SurvivorService.abilityUsed:Fire(player, "SelfDestruct", "Robo")
		end)
	end)
end

-- ============================================================
-- Dispatch de habilidades
-- ============================================================

--[[
  Roteia a acao de habilidade para o handler correto por classe.
  Chamado pelo SurvivorEvents quando recebe SURVIVOR_A1/A2/A3.
]]
function SurvivorService.handleAbilityAction(player: Player, action: string, chargeLevel: number): ()
	local ext = getOrCreateExt(player)
	if not ext then
		warn("[TheBrokenBox] SurvivorService: Jogador nao e Sobrevivente: " .. player.Name)
		return
	end

	-- Atualizar referencias de personagem
	refreshCharacterRefs(ext, player)

	if not validateSurvivorAction(ext) then
		return
	end

	local className = ext.class

	if action == "SURVIVOR_A1" then
		if className == "Medico" then
			medicoA1(player, ext)
		elseif className == "Soldado" then
			soldadoA1(player, ext)
		elseif className == "Sackboy" then
			sackboyA1(player, ext, chargeLevel or 1)
		elseif className == "Robo" then
			roboA1(player, ext)
		end
	elseif action == "SURVIVOR_A2" then
		if className == "Medico" then
			medicoA2(player, ext)
		elseif className == "Soldado" then
			soldadoA2(player, ext)
		elseif className == "Sackboy" then
			sackboyA2(player, ext)
		elseif className == "Robo" then
			roboA2(player, ext)
		end
	elseif action == "SURVIVOR_A3" then
		if className == "Robo" then
			roboA3(player, ext)
		elseif className == "Soldado" then
			-- Soldado nao tem A3
			return
		elseif className == "Sackboy" then
			-- Sackboy nao tem A3
			return
		elseif className == "Medico" then
			-- Medico nao tem A3
			return
		end
	end
end

-- ============================================================
-- LMS (Last Man Standing) Bonuses
-- ============================================================

--[[
  Aplica bonus de LMS baseado na classe do Sobrevivente e do Cacador.
  Condicional: Soldado vs Soldado Fundido, Sackboy vs Amaldicoado
  Incondicional: Medico, Robo (sempre ao ser ultimo vivo)
]]
local function applyLMSBonus(player: Player, ext: SurvivorExtState): ()
	local className = ext.class
	local humanoid = ext.humanoid
	if not humanoid then
		return
	end

	local playerData = _matchService:getPlayerData(player)
	if not playerData then
		return
	end

	ext.lmsActive = true

	-- Bonus base (todos os ultimos sobreviventes)
	-- +2 speed universal para ultimo sobrevivente
	local baseSpeed = playerData.speed
	humanoid.WalkSpeed = baseSpeed + 2

	local bonusMsg = ""

	if className == "Medico" then
		-- LMS Incondicional: +2 speed (ja aplicado acima) + +20 stamina
		playerData.maxStamina = playerData.maxStamina + 20
		playerData.stamina = math.min(playerData.stamina + 20, playerData.maxStamina)
		bonusMsg = "+2 vel, +20 stamina"
		print("[TheBrokenBox] LMS Medico: " .. player.Name .. " - " .. bonusMsg)

	elseif className == "Soldado" then
		-- LMS Condicional: vs Soldado Fundido -> speed 22, +30% dano Bazuca
		humanoid.WalkSpeed = 22  -- Override para speed fixo 22
		bonusMsg = "+2 vel (->22), +30% dano Bazuca"
		print("[TheBrokenBox] LMS Soldado: " .. player.Name .. " - " .. bonusMsg)

	elseif className == "Sackboy" then
		-- LMS Condicional: vs Amaldicoado -> speed 28, +20 stamina
		humanoid.WalkSpeed = 28
		playerData.maxStamina = playerData.maxStamina + 10
		playerData.stamina = math.min(playerData.stamina + 10, playerData.maxStamina)
		bonusMsg = "+2 vel (->28), +10 stamina"
		print("[TheBrokenBox] LMS Sackboy: " .. player.Name .. " - " .. bonusMsg)

	elseif className == "Robo" then
		-- LMS Incondicional: +2 speed (ja aplicado) + Autodestruicao cd reduzido
		bonusMsg = "+2 vel, cd Autodestruicao reduzido"
		print("[TheBrokenBox] LMS Robo: " .. player.Name .. " - " .. bonusMsg)
	end

	-- Notificar cliente do LMS
	if _uiSyncEvent then
		RemoteEventUtils.firePlayer(
			_uiSyncEvent,
			player,
			"LMS_ACTIVATED",
			{ className = className, bonus = bonusMsg }
		)
	end
end

--[[
  Verifica e aplica LMS quando apenas 1 Sobrevivente permanece vivo.
]]
local function checkAndApplyLMS(): ()
	local survivors = _matchService.getPlayersByRole("Survivor")
	local aliveCount = 0
	local lastAlive: Player = nil

	for _, player in survivors do
		local data = _matchService:getPlayerData(player)
		if data and data.isAlive then
			aliveCount = aliveCount + 1
			lastAlive = player
		end
	end

	if aliveCount == 1 and lastAlive then
		local ext = _survivorExt[lastAlive.UserId]
		if ext and not ext.lmsActive then
			applyLMSBonus(lastAlive, ext)
		end
	end
end

-- ============================================================
-- Init/Start/Update
-- ============================================================

--[[
  Init(): setup sincrono.
  Injeta referencias para outros servicos e eventos.
]]
function SurvivorService.Init(
	gameStateEvent: RemoteEvent,
	playerActionEvent: RemoteEvent,
	uiSyncEvent: RemoteEvent,
	matchService: any
): ()
	print("[TheBrokenBox] SurvivorService.Init()")

	_gameStateEvent = gameStateEvent
	_playerActionEvent = playerActionEvent
	_uiSyncEvent = uiSyncEvent
	_matchService = matchService

	_survivorExt = {}

	-- Conectar ao sinal de dano para verificar Block do Robo
	-- e para disparar survivorDamaged
	if matchService and matchService.damageTaken then
		matchService.damageTaken:Connect(function(player: Player, damage: number, source: Player)
			local ext = _survivorExt[player.UserId]
			if ext then
				-- Verificar Block do Robo (contra-ataque)
				if ext.class == "Robo" and ext.isBlocking then
					local blocked = SurvivorService.checkRoboBlock(player)
					if blocked then
						-- O dano foi absorvido - mas como ja foi aplicado pelo
						-- MatchService, curamos de volta
						_matchService.healPlayer(player, damage)
						return
					end
				end

				-- Disparar sinal de dano
				if damage > 0 then
					SurvivorService.survivorDamaged:Fire(player, damage, source)
				end
			end
		end)
	end

	-- Conectar ao sinal de morte para disparar survivorDied e verificar LMS
	if matchService and matchService.playerDied then
		matchService.playerDied:Connect(function(player: Player)
			local ext = _survivorExt[player.UserId]
			if ext then
				SurvivorService.survivorDied:Fire(player)
				_survivorExt[player.UserId] = nil

				-- Verificar LMS apos morte
				checkAndApplyLMS()
			end
		end)
	end

	-- Conectar ao sinal de papel atribuido para inicializar estado
	if matchService and matchService.roleAssigned then
		matchService.roleAssigned:Connect(function(player: Player, role: string)
			if role == "Survivor" then
				getOrCreateExt(player)
				refreshCharacterRefs(
					_survivorExt[player.UserId],
					player
				)
			end
		end)
	end
end

--[[
  Start(): inicializacao assincrona.
  Registra listeners e configura o loop Heartbeat.
]]
function SurvivorService.Start(): ()
	print("[TheBrokenBox] SurvivorService.Start()")

	-- Registrar Sobreviventes ja existentes
	local survivors = _matchService.getPlayersByRole("Survivor")
	for _, player in survivors do
		getOrCreateExt(player)
		refreshCharacterRefs(
			_survivorExt[player.UserId],
			player
		)
	end

	-- Heartbeat: update continuo para efeitos e LMS
	RunService.Heartbeat:Connect(function(_dt: number)
		SurvivorService.update(_dt)
	end)

	print("[TheBrokenBox] SurvivorService.Start() concluido.")
end

--[[
  update(dt): chamado a cada frame do Heartbeat.
  Processa efeitos continuos: Surto do Sackboy, dash, etc.
]]
function SurvivorService.update(dt: number): ()
	local now = os.clock()

	-- Verificar LMS periodicamente (~1x/s)
	-- (pode ser otimizado com um contador)
	checkAndApplyLMS()

	-- Atualizar estados de Surto do Sackboy
	for userId, ext in _survivorExt do
		if ext.surgeActive and ext.surgeEndTime > 0 and now >= ext.surgeEndTime then
			if ext.humanoid and ext.humanoid.Parent then
				ext.surgeActive = false
				if not ext.lmsActive then
					ext.humanoid.WalkSpeed = ext.originalSpeed
				end
				ext.humanoid.JumpPower = 50
			end
		end

		-- Atualizar referencias se nil
		if not ext.rootPart or not ext.humanoid then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				refreshCharacterRefs(ext, player)
			end
		end
	end
end

-- ============================================================
-- API de consulta
-- ============================================================

--[[
  Retorna o estado estendido de um Sobrevivente.
]]
function SurvivorService.getSurvivorExt(player: Player): SurvivorExtState
	return _survivorExt[player.UserId]
end

--[[
  Verifica se um jogador e um Sobrevivente.
]]
function SurvivorService.isSurvivor(player: Player): boolean
	local data = _matchService:getPlayerData(player)
	return data ~= nil and data.role == "Survivor"
end

return SurvivorService
