--!strict
--[[
  HitboxService.lua
  Servico server-authoritative de deteccao de hitboxes.
  Responsavel por criar regioes de deteccao para todos os ataques
  e resolver colisoes com corpos de personagens.

  Tipos de hitbox (ref: GDD Sistema de Hitboxes e Layers):
    1. CORPO (Body)         - hitbox de corpo de cada personagem
    2. PROJETIL (Projectile)- viaja 15/s x 2s, para em parede/alvo
    3. LINHA (InstantLine)  - 3x3x100 studs, instantanea, para na parede
    4. CUBO (AreaCube)      - cubo unico, atravessa parede
    5. REACAO (ReactionArea)- area reativa (ex.: Block do Robo)

  Layers de colisao:
    HunterAttack   - Ataques do Cacador -> Sobreviventes
    SurvivorAttack - Ataques dos Sobreviventes -> Cacador
    Environment    - Paredes, chao, obstaculos
    Invincible     - Durante i-frames (Cacador)

  Regras:
    - Dano aplicado 1x por alvo colidido (NUNCA empilha no mesmo alvo)
    - Projeteis param em paredes/chao
    - Cubos grandes ignoram ambiente
    - Toda validacao server-side (anti-exploit)

  Referencias: GDD Sistema de Hitboxes, architecture.md 7
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)

local HitboxService = {}
HitboxService.Name = "HitboxService"

-- ============================================================
-- Sinais
-- ============================================================
HitboxService.damageApplied = Signal.new()  -- (target: Player, damage: number, source: Player?)

-- ============================================================
-- Collision Groups
-- ============================================================
local COLLISION_GROUPS = {
	HUNTER_BODY = "HunterBody",
	SURVIVOR_BODY = "SurvivorBody",
	HUNTER_ATTACK = "HunterAttack",
	SURVIVOR_ATTACK = "SurvivorAttack",
	ENVIRONMENT = "Environment",
	INVINCIBLE = "Invincible",
}

-- ============================================================
-- Estado interno
-- ============================================================
local _bodyHitboxes = {}     -- { [Player] = part }
local _invinciblePlayers = {} -- { [Player] = true } durante i-frames

-- ============================================================
-- Setup de PhysicsService
-- ============================================================

--[[
  Configura os collision groups no PhysicsService.
  Define quais grupos colidem com quais.
]]
local function setupCollisionGroups()
	-- Criar grupos (se ja existirem, PhysicsService ignora)
	for _, groupName in pairs(COLLISION_GROUPS) do
		local success = pcall(function()
			PhysicsService:CreateCollisionGroup(groupName)
		end)
		if not success then
			-- Grupo ja existe - ok
		end
	end

	-- Configurar regras de colisao:
	-- HunterAttack -> SurvivorBody: SIM
	-- SurvivorAttack -> HunterBody: SIM
	-- HunterAttack -> Invincible: NAO
	-- SurvivorAttack -> Invincible: NAO
	-- Tudo -> Environment: SIM (exceto cubos de area que ignoram)

	-- Por padrao, todos os grupos colidem.
	-- Precisamos desabilitar colisoes especificas:
	local function noCollision(g1: string, g2: string)
		PhysicsService:CollisionGroupSetCollidable(g1, g2, false)
	end

	-- Ataques nao acertam alvos invenciveis
	noCollision(COLLISION_GROUPS.HUNTER_ATTACK, COLLISION_GROUPS.INVINCIBLE)
	noCollision(COLLISION_GROUPS.SURVIVOR_ATTACK, COLLISION_GROUPS.INVINCIBLE)

	-- Ataques do Cacador nao acertam o proprio Cacador
	noCollision(COLLISION_GROUPS.HUNTER_ATTACK, COLLISION_GROUPS.HUNTER_BODY)

	-- Ataques dos Sobreviventes nao acertam outros Sobreviventes
	noCollision(COLLISION_GROUPS.SURVIVOR_ATTACK, COLLISION_GROUPS.SURVIVOR_BODY)

	print("[TheBrokenBox] HitboxService: Collision groups configurados.")
end

-- ============================================================
-- API: Gerenciamento de hitboxes de corpo
-- ============================================================

--[[
  Cria a hitbox de corpo para um personagem.
  Usa uma parte invisivel anexada ao HumanoidRootPart.
]]
function HitboxService.createBodyHitbox(player: Player): ()
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- Remover hitbox anterior se existir
	HitboxService.removeBodyHitbox(player)

	-- Criar parte de colisao invisivel
	local bodyPart = Instance.new("Part")
	bodyPart.Name = "BodyHitbox"
	bodyPart.Size = Vector3.new(4, 5, 2)  -- Tamanho aproximado do corpo R6
	bodyPart.Transparency = 1.0
	bodyPart.CanCollide = true
	bodyPart.Anchored = false
	bodyPart.Massless = true
	bodyPart.CanTouch = true

	-- Weld no RootPart
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = rootPart
	weld.Parent = bodyPart

	-- Definir collision group baseado no papel
	local role = "Survivor"
	-- O papel e definido pelo MatchService, aqui usamos Survivor como padrao
	-- (MatchService atualiza o grupo quando o papel e atribuido)
	PhysicsService:SetPartCollisionGroup(bodyPart, COLLISION_GROUPS.SURVIVOR_BODY)

	bodyPart.Parent = character
	_bodyHitboxes[player] = bodyPart

	print("[TheBrokenBox] HitboxService: Hitbox de corpo criada para " .. player.Name)
end

--[[
  Remove a hitbox de corpo de um jogador.
]]
function HitboxService.removeBodyHitbox(player: Player): ()
	local part = _bodyHitboxes[player]
	if part then
		part:Destroy()
		_bodyHitboxes[player] = nil
	end
end

--[[
  Atualiza o collision group da hitbox de corpo.
  Chamado quando o papel (Hunter/Survivor) e atribuido.
]]
function HitboxService.setBodyCollisionGroup(player: Player, groupName: string): ()
	local part = _bodyHitboxes[player]
	if part then
		pcall(function()
			PhysicsService:SetPartCollisionGroup(part, groupName)
		end)
	end
end

--[[
  Callback quando jogador morre.
]]
function HitboxService.onPlayerDied(player: Player): ()
	HitboxService.removeBodyHitbox(player)
end

-- ============================================================
-- API: I-frames (invencibilidade)
-- ============================================================

--[[
  Ativa i-frames para um jogador (muda para layer Invincible).
]]
function HitboxService.setInvincible(player: Player, duration: number?): ()
	_invinciblePlayers[player] = true

	local part = _bodyHitboxes[player]
	if part then
		pcall(function()
			PhysicsService:SetPartCollisionGroup(part, COLLISION_GROUPS.INVINCIBLE)
		end)
	end

	print("[TheBrokenBox] HitboxService: " .. player.Name .. " agora invencivel" .. (duration and (" por " .. duration .. "s") or ""))

	-- Se duracao especificada, remover automaticamente
	if duration then
		task.delay(duration, function()
			HitboxService.removeInvincible(player)
		end)
	end
end

--[[
  Remove i-frames de um jogador.
]]
function HitboxService.removeInvincible(player: Player): ()
	_invinciblePlayers[player] = nil

	local part = _bodyHitboxes[player]
	if part then
		-- Restaurar collision group original
		-- (assume Survivor como padrao; MatchService ajusta se necessario)
		pcall(function()
			PhysicsService:SetPartCollisionGroup(part, COLLISION_GROUPS.SURVIVOR_BODY)
		end)
	end
end

--[[
  Verifica se um jogador esta invencivel.
]]
function HitboxService.isInvincible(player: Player): boolean
	return _invinciblePlayers[player] == true
end

-- ============================================================
-- API: Deteccao de hitbox por tipo
-- ============================================================

--[[
  Hitbox tipo CORPO: verifica se dois jogadores estao em contato
  (usando distancia entre RootParts).
  Usado para ataques corpo-a-corpo como M1 (Tapa).
]]
function HitboxService.checkBodyHit(
	attacker: Player,
	target: Player,
	range: number
): boolean
	if _invinciblePlayers[target] then
		return false
	end

	local attackerChar = attacker.Character
	local targetChar = target.Character
	if not attackerChar or not targetChar then
		return false
	end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not targetRoot then
		return false
	end

	return MathUtil.isInRadius(attackerRoot.Position, targetRoot.Position, range)
end

--[[
  Hitbox tipo CUBO (AreaCube): detecta todos os alvos dentro de um raio.
  Atravessa paredes (cubos de area ignoram ambiente).
  Usado para: Grito, Rage (pulso), Cura do Medico, Investida.

  Retorna lista de {player, distance}.
]]
function HitboxService.checkAreaCube(
	centerPosition: Vector3,
	radius: number,
	attacker: Player,
	targetLayer: string  -- "HunterAttack" | "SurvivorAttack"
): {{player: Player, distance: number}}
	local results = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player == attacker then
			continue
		end

		-- Verificar invencibilidade
		if _invinciblePlayers[player] then
			continue
		end

		local character = player.Character
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		local dist = MathUtil.distance(centerPosition, rootPart.Position)
		if dist <= radius then
			table.insert(results, { player = player, distance = dist })
		end
	end

	return results
end

--[[
  Hitbox tipo LINHA (InstantLine): verifica se um raycast atinge um alvo.
  3x3x100 studs, para na parede.
  Usado para: Bazuca (Soldado), Arma de Tinta (Sackboy).

  Retorna o primeiro alvo atingido ou nil.
]]
function HitboxService.checkInstantLine(
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
	attacker: Player,
	ignoreInvincible: boolean?
): {player: Player, hitPosition: Vector3}?
	-- Raycast para detectar paredes (Environment)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	-- Incluir apenas Environment e corpos de jogadores
	-- Na pratica, verificamos colisao com ambiente primeiro

	-- Raycast contra o ambiente
	local rayResult = Workspace:Raycast(origin, direction * maxDistance)
	local effectiveDistance = maxDistance

	if rayResult then
		-- A linha para na parede
		effectiveDistance = (rayResult.Position - origin).Magnitude
	end

	-- Verificar jogadores na linha
	local closestHit: {player: Player, hitPosition: Vector3}? = nil
	local closestDist = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player == attacker then
			continue
		end

		if ignoreInvincible and _invinciblePlayers[player] then
			continue
		end

		local character = player.Character
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		-- Verificar se o jogador esta na linha
		local toTarget = rootPart.Position - origin
		local projection = toTarget:Dot(direction)

		-- Alvo esta na direcao correta?
		if projection <= 0 or projection > effectiveDistance then
			continue
		end

		-- Alvo esta proximo o suficiente da linha? (tolerancia 3 studs = metade da largura)
		local closestPoint = origin + direction * projection
		local perpendicularDist = (rootPart.Position - closestPoint).Magnitude

		if perpendicularDist <= 3 then  -- hitbox de 3x3 studs
			if projection < closestDist then
				closestDist = projection
				closestHit = {
					player = player,
					hitPosition = closestPoint,
				}
			end
		end
	end

	return closestHit
end

--[[
  Hitbox tipo PROJETIL: cria um projetil que viaja e detecta colisao.
  Viaja 15 studs/s por ate 2s. Para em parede/alvo.
  Usado para: Braco Esticado (Pull), Agarrar (Robo).

  Retorna nil se nao acertou nada, ou {player, hitPosition}.
]]
function HitboxService.createProjectile(
	origin: Vector3,
	direction: Vector3,
	speed: number,          -- studs/s
	maxDuration: number,    -- s
	attacker: Player,
	targetLayer: string,    -- "HunterAttack" | "SurvivorAttack"
	onHit: ((target: Player, hitPosition: Vector3) -> ())?  -- callback opcional
): ()
	-- Usar corrotina para mover o projetil a cada frame
	task.spawn(function()
		local position = origin
		local elapsed = 0/10
		local stepTime = 1 / 60  -- ~60Hz

		while elapsed < maxDuration do
			local deltaTime = math.min(stepTime, maxDuration - elapsed)
			local newPosition = position + direction * speed * deltaTime

			-- Raycast contra ambiente (paredes)
			local rayResult = Workspace:Raycast(position, direction * speed * deltaTime)
			if rayResult then
				-- Projetil parou na parede
				print("[TheBrokenBox] HitboxService: Projetil atingiu parede em " .. tostring(rayResult.Position))
				return
			end

			-- Verificar colisao com jogadores na trajetoria
			for _, player in ipairs(Players:GetPlayers()) do
				if player == attacker then
					continue
				end

				if _invinciblePlayers[player] then
					continue
				end

				local character = player.Character
				if not character then
					continue
				end

				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if not rootPart then
					continue
				end

				-- Verificar se o projetil passou pelo jogador neste frame
				local dist = MathUtil.distance(position, rootPart.Position)
				if dist <= 5 then  -- Raio de colisao do projetil
					local hitPos = newPosition
					print("[TheBrokenBox] HitboxService: Projetil atingiu " .. player.Name)
					if onHit then
						onHit(player, hitPos)
					end
					return
				end
			end

			position = newPosition
			elapsed = elapsed + deltaTime
			task.wait(stepTime)
		end

		print("[TheBrokenBox] HitboxService: Projetil expirou (duracao: " .. maxDuration .. "s)")
	end)
end

-- ============================================================
-- API: Aplicacao de dano (com regra 1x por alvo)
-- ============================================================

--[[
  Aplica dano a uma lista de alvos, garantindo 1x por alvo.
  Usa um set para evitar duplicatas.
]]
function HitboxService.applyDamageToTargets(
	targets: {{player: Player}},
	damage: number,
	source: Player?
): ()
	-- Set para garantir 1x por alvo
	local hitPlayers = {}

	for _, entry in ipairs(targets) do
		local target = entry.player
		if not hitPlayers[target] then
			hitPlayers[target] = true

			-- Pular invenciveis
			if _invinciblePlayers[target] then
				continue
			end

			-- Aplicar dano (delega para MatchService)
			HitboxService.damageApplied:Fire(target, damage, source)

			print("[TheBrokenBox] HitboxService: Dano aplicado: " .. target.Name .. " recebeu " .. damage .. " de " .. (source and source.Name or "desconhecido"))
		end
	end
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

function HitboxService.Init(): ()
	print("[TheBrokenBox] HitboxService.Init()")

	-- Configurar PhysicsService collision groups
	setupCollisionGroups()

	_bodyHitboxes = {}
	_invinciblePlayers = {}
end

function HitboxService.Start(): ()
	print("[TheBrokenBox] HitboxService.Start() - registrando listeners...")

	-- Criar hitbox de corpo quando personagem spawna
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(_character: Model)
			task.wait(0.1)  -- Aguardar character carregar
			HitboxService.createBodyHitbox(player)
		end)

		-- Se ja tiver personagem
		if player.Character then
			HitboxService.createBodyHitbox(player)
		end
	end)

	-- Jogadores existentes
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			HitboxService.createBodyHitbox(player)
		end
	end

	-- Limpar hitbox quando jogador sair
	Players.PlayerRemoving:Connect(function(player: Player)
		HitboxService.removeBodyHitbox(player)
	end)

	print("[TheBrokenBox] HitboxService pronto.")
end

return HitboxService
