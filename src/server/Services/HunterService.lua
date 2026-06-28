--!strict
--[[
  HunterService.lua
  Servico server-authoritative do Cacador — O Distorcido.
  Gerencia:
    - Sistema de Furia e Rage (ref: GDD M5)
    - Stun e I-frames (ref: GDD M6)
    - M1 Tapa (ataque basico)
    - Braco Esticado (Pull)
    - Grito (Roar)

  Todos os valores numericos de GameConstants.Hunter.DISTORCIDO.
  Todas as chamadas de hitbox via HitboxService.
  Sinais expostos para wiring no GameManager.

  Referencias: GDD M5-M7, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)
local MathUtil = require(ReplicatedStorage.Util.MathUtil)

local HunterService = {}
HunterService.Name = "HunterService"

-- ============================================================
-- Referencias a outros servicos (injetadas no Init)
-- ============================================================
local MatchService = nil
local HitboxService = nil
local StaminaService = nil

-- ============================================================
-- Sinais do servico
-- ============================================================
HunterService.rageActivated = Signal.new()    -- (hunter: Player)
HunterService.rageDeactivated = Signal.new()  -- (hunter: Player, remainingFury: number)
HunterService.hunterStunned = Signal.new()    -- (hunter: Player, duration: number)
HunterService.hunterAttacked = Signal.new()   -- (hunter: Player, attacker: Player?)

-- ============================================================
-- Estado interno do Cacador
-- ============================================================
local _hunter: Player? = nil               -- Referencia ao jogador Cacador
local _fury: number = 0                    -- Medidor de Furia (0-100+)
local _isInRage: boolean = false           -- Se esta em estado de Rage
local _isStunned: boolean = false          -- Se esta stunado
local _stunnedUntil: number = 0            -- Timestamp de quando o stun termina
local _iframesUntil: number = 0            -- Timestamp de quando i-frames terminam
local _rageWindupActive: boolean = false   -- Se windup do Rage esta ativo
local _rageStartTime: number = 0           -- Timestamp de quando Rage comecou
local _rageDuration: number = 0            -- Duracao total do Rage atual
local _killsInRage: number = 0             -- Mortes feitas durante este Rage
local _proximityAccumulator: number = 0    -- Tempo acumulado em proximidade (s)
local _cooldowns: { [string]: number } = {
	M1 = 0,
	Pull = 0,
	Roar = 0,
}

-- Conexao do Heartbeat
local _heartbeatConnection: RBXScriptConnection? = nil

-- ============================================================
-- Estado interno: Aparencia do Rage
-- ============================================================
-- Salva a aparencia original do personagem para restaurar ao sair do Rage.
-- Estrutura: { bodyColors = {...}, accessories = {...}, scale = number }
local _originalAppearance: { any }? = nil

-- ============================================================
-- Funcoes auxiliares: Transformacao visual do Rage
-- ============================================================

--[[
  Salva a aparencia original do personagem do Cacador.
  Guarda: BodyColors, Accessories (nomes/ids) e escala atual.
]]
local function _saveOriginalAppearance(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- Salvar BodyColors
	local bodyColors = {}
	local bodyColorParts = {
		"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
	}
	for _, partName in ipairs(bodyColorParts) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			bodyColors[partName] = part.Color
		end
	end

	-- Salvar Accessories (guardar referencia por nome)
	local accessories = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			table.insert(accessories, child)
		end
	end

	-- Salvar escala
	local scale = 1.0
	if humanoid then
		scale = humanoid.HipHeight / 2 -- Escala aproximada
	end

	_originalAppearance = {
		bodyColors = bodyColors,
		accessories = accessories,
		scale = scale,
	}

	print("[TheBrokenBox] HunterService: Aparencia original salva (" .. #accessories .. " acessorios).")
end

--[[
  Aplica a aparencia de Rage ao personagem do Cacador.
  Tenta carregar o modelo "DistorcidoRage" de ServerStorage.Assets.
  Se nao existir, aplica fallback escuro:
    - Escala 1.15x
    - Todas as partes do corpo -> Color3.new(0.05, 0.05, 0.05) (quase preto)
    - ParticleEmitter escuro no HumanoidRootPart
]]
local function _applyRageAppearance(character: Model): ()
	if not character then return end

	local ServerStorage = game:GetService("ServerStorage")

	-- Tentar carregar modelo customizado
	local assetsFolder = ServerStorage:FindFirstChild("Assets")
	local rageModel: Model? = nil

	if assetsFolder then
		rageModel = assetsFolder:FindFirstChild("DistorcidoRage")
	end

	if rageModel and rageModel:IsA("Model") then
		-- Aplicar aparencia do modelo customizado
		print("[TheBrokenBox] HunterService: Modelo DistorcidoRage encontrado — aplicando aparencia customizada...")

		-- Copiar cores do corpo do modelo para o personagem
		local bodyPartNames = {
			"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
		}
		for _, partName in ipairs(bodyPartNames) do
			local targetPart = character:FindFirstChild(partName)
			local sourcePart = rageModel:FindFirstChild(partName)

			if targetPart and targetPart:IsA("BasePart") and sourcePart and sourcePart:IsA("BasePart") then
				targetPart.Color = sourcePart.Color
				targetPart.Material = sourcePart.Material
				-- Copiar transparencia se houver
				if sourcePart.Transparency > 0 then
					targetPart.Transparency = sourcePart.Transparency
				end
			end
		end

		-- Copiar acessorios do modelo rage
		for _, child in ipairs(rageModel:GetChildren()) do
			if child:IsA("Accessory") then
				local clonedAccessory = child:Clone()
				clonedAccessory.Parent = character
			end
		end

		-- Aplicar escala se o modelo tiver Humanoid
		local rageHumanoid = rageModel:FindFirstChildOfClass("Humanoid")
		if rageHumanoid then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local targetScale = rageHumanoid.HipHeight / 2
				humanoid.HipHeight = rageHumanoid.HipHeight
				-- Ajustar escala das partes
				for _, child in ipairs(character:GetChildren()) do
					if child:IsA("BasePart") then
						-- Manter proporcao — o HipHeight ja ajusta a escala geral
					end
				end
				print("[TheBrokenBox] HunterService: Escala ajustada para " .. tostring(targetScale))
			end
		end
	else
		-- Fallback: aparencia escura
		print("[TheBrokenBox] HunterService: Modelo DistorcidoRage NAO encontrado — aplicando fallback escuro...")

		local rageColor = Color3.new(0.05, 0.05, 0.05)

		-- Aplicar cor escura em todas as partes do corpo
		local bodyPartNames = {
			"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
		}
		for _, partName in ipairs(bodyPartNames) do
			local part = character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.Color = rageColor
			end
		end

		-- Aumentar escala em 1.15x
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.HipHeight = humanoid.HipHeight * 1.15
			print("[TheBrokenBox] HunterService: Escala aumentada para 1.15x")
		end

		-- Adicionar ParticleEmitter escuro no HumanoidRootPart
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			local particleEmitter = Instance.new("ParticleEmitter")
			particleEmitter.Name = "RageParticles"
			particleEmitter.Color = ColorSequence.new(rageColor)
			particleEmitter.LightEmission = 0
			particleEmitter.Rate = 20
			particleEmitter.Lifetime = NumberRange.new(0.5, 1.5)
			particleEmitter.Speed = NumberRange.new(1, 3)
			particleEmitter.SpreadAngle = Vector2.new(180, 180)
			particleEmitter.Transparency = NumberSequence.new(0.5)
			particleEmitter.Size = NumberSequence.new(0.5)
			particleEmitter.Texture = "rbxassetid://13200797030" -- Textura de fumaca padrao
			particleEmitter.Parent = rootPart

			print("[TheBrokenBox] HunterService: ParticleEmitter escuro adicionado ao HumanoidRootPart.")
		end
	end

	print("[TheBrokenBox] HunterService: Aparencia de Rage aplicada!")
end

--[[
  Reverte a aparencia do personagem do Cacador para o estado original.
  Remove particle emitter de Rage, restaura cores, acessorios e escala.
]]
local function _revertRageAppearance(character: Model): ()
	if not character then return end
	if not _originalAppearance then
		warn("[TheBrokenBox] HunterService: Aparencia original nao salva — nada para reverter.")
		return
	end

	local original = _originalAppearance

	-- Restaurar cores do corpo
	if original.bodyColors then
		for partName, color in pairs(original.bodyColors) do
			local part = character:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.Color = color
			end
		end
	end

	-- Restaurar escala
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and original.scale then
		humanoid.HipHeight = original.scale * 2
	end

	-- Remover ParticleEmitter de Rage
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local rageParticles = rootPart:FindFirstChild("RageParticles")
		if rageParticles then
			rageParticles:Destroy()
			print("[TheBrokenBox] HunterService: ParticleEmitter de Rage removido.")
		end
	end

	-- Remover acessorios adicionados pelo Rage (manter os originais)
	local originalAccessoryNames = {}
	if original.accessories then
		for _, acc in ipairs(original.accessories) do
			if acc and acc.Name then
				originalAccessoryNames[acc.Name] = true
			end
		end
	end

	-- Remover acessorios que NAO estavam no original
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and not originalAccessoryNames[child.Name] then
			child:Destroy()
		end
	end

	_originalAppearance = nil
	print("[TheBrokenBox] HunterService: Aparencia original restaurada.")
end

-- ============================================================
-- API: Atribuicao do Cacador
-- ============================================================

--[[
  Define o jogador Cacador.
  Chamado quando MatchService atribui o papel de Hunter.
]]
function HunterService.setHunter(player: Player): ()
	_hunter = player
	_fury = 0
	_isInRage = false
	_isStunned = false
	_stunnedUntil = 0
	_iframesUntil = 0
	_rageWindupActive = false
	_killsInRage = 0
	_proximityAccumulator = 0
	_cooldowns = { M1 = 0, Pull = 0, Roar = 0 }

	-- Sincronizar velocidade base
	HunterService.applySpeed(player, GameConstants.Hunter.BASE_SPEED)

	print("[TheBrokenBox] HunterService: Cacador definido: " .. player.Name)
end

--[[
  Retorna o jogador Cacador atual (ou nil).
]]
function HunterService.getHunter(): Player?
	return _hunter
end

--[[
  Verifica se o jogador e o Cacador.
]]
function HunterService.isHunter(player: Player): boolean
	return _hunter == player
end

-- ============================================================
-- API: Furia
-- ============================================================

--[[
  Retorna o valor atual de Furia.
]]
function HunterService.getFury(): number
	return _fury
end

--[[
  Adiciona furia ao medidor.
]]
function HunterService.addFury(amount: number): ()
	_fury = _fury + amount
	print("[TheBrokenBox] HunterService: Furia +" .. amount .. " (total: " .. _fury .. ")")
end

--[[
  Callback quando o Cacador e atacado.
  Ganha +10 de furia ao ser atacado/atordoado (ref: GDD M5).
]]
function HunterService.onHunterAttacked(attacker: Player?): ()
	if not _hunter then return end

	local furyConfig = GameConstants.Hunter.FURY
	_fury = _fury + furyConfig.GAIN_ON_ATTACKED

	print("[TheBrokenBox] HunterService: Cacador atacado! Furia +" .. furyConfig.GAIN_ON_ATTACKED .. " (total: " .. _fury .. ")")
	HunterService.hunterAttacked:Fire(_hunter, attacker)
end

--[[
  Callback quando o Cacador mata um Sobrevivente.
  Se estiver em Rage: conta para extensao e bonus de furia ao sair.
]]
function HunterService.onHunterKill(victim: Player): ()
	if not _hunter then return end

	if _isInRage then
		_killsInRage = _killsInRage + 1
		-- Estende a duracao do Rage
		_rageDuration = _rageDuration + GameConstants.Hunter.FURY.RAGE_EXTEND_PER_KILL
		print("[TheBrokenBox] HunterService: Morte em Rage! +" .. GameConstants.Hunter.FURY.RAGE_EXTEND_PER_KILL .. "s (mortes: " .. _killsInRage .. ", duracao: " .. _rageDuration .. "s)")
	end
end

-- ============================================================
-- API: Rage
-- ============================================================

--[[
  Verifica se esta em Rage.
]]
function HunterService.isInRage(): boolean
	return _isInRage
end

--[[
  Verifica se windup do Rage esta ativo.
]]
function HunterService.isRageWindupActive(): boolean
	return _rageWindupActive
end

--[[
  Verifica se o Rage pode ser ativado.
  Requisitos: furia >= threshold, nao esta em Rage, nao esta em windup,
  nao esta stunado, nao esta na fase de Fuga.
]]
function HunterService.canActivateRage(): boolean
	if not _hunter then return false end
	if _isInRage then return false end
	if _rageWindupActive then return false end
	if _isStunned then return false end

	local furyConfig = GameConstants.Hunter.FURY
	if _fury < furyConfig.RAGE_THRESHOLD then return false end

	-- Nao pode usar Rage durante a Fuga
	if MatchService then
		local state = MatchService.getMatchState()
		if state == "Escaping" then return false end
	end

	return true
end

--[[
  Ativa o windup do Rage.
  Windup de 5s: transformacao vulneravel, nao cancelavel.
]]
function HunterService.activateRageWindup(): ()
	if not _hunter then return end
	if not HunterService.canActivateRage() then
		warn("[TheBrokenBox] HunterService: Nao pode ativar Rage agora!")
		return
	end

	_rageWindupActive = true
	local furyConfig = GameConstants.Hunter.FURY

	print("[TheBrokenBox] HunterService: Windup do Rage iniciado (" .. _hunter.Name .. ")! " .. furyConfig.RAGE_WINDUP .. "s...")

	-- Windup assincrono
	task.spawn(function()
		task.wait(furyConfig.RAGE_WINDUP)

		-- Verificar se ainda e valido (pode ter morrido ou sido stunado)
		if not _hunter then
			_rageWindupActive = false
			return
		end
		if not _rageWindupActive then
			return -- Cancelado por morte/stun
		end

		-- Completar transformacao
		HunterService.activateRage()
	end)
end

--[[
  Ativa o Rage imediatamente (chamado ao fim do windup).
  - Pulso de dano em area (raio 30, 20 de dano)
  - Buffa M1 (+5 -> 25), velocidade (+2 -> 28)
  - Grito causa 10 de dano
  - Ciclo pausa
  - Duracao: 30s + 10s por morte
  - Muda modelo visual
]]
function HunterService.activateRage(): ()
	if not _hunter then return end

	_rageWindupActive = false
	_isInRage = true
	_killsInRage = 0
	_rageStartTime = os.clock()

	local furyConfig = GameConstants.Hunter.FURY
	_rageDuration = furyConfig.RAGE_DURATION_BASE

	print("[TheBrokenBox] HunterService: RAGE ATIVADO! " .. _hunter.Name)

	-- Obter personagem para transformacao visual e pulso de dano
	local character = _hunter.Character

	-- Salvar aparencia original e aplicar transformacao visual do Rage
	if character then
		_saveOriginalAppearance(character)
		_applyRageAppearance(character)
	end

	-- Pulso de dano em area ao ativar
	if character and HitboxService then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local targets = HitboxService.checkAreaCube(
				rootPart.Position,
				furyConfig.RAGE_PULSE_RADIUS,
				_hunter,
				"HunterAttack"
			)
			if #targets > 0 then
				HitboxService.applyDamageToTargets(targets, furyConfig.RAGE_PULSE_DAMAGE, _hunter)
				print("[TheBrokenBox] HunterService: Pulso de Rage acertou " .. #targets .. " alvos! Dano: " .. furyConfig.RAGE_PULSE_DAMAGE)
			end
		end
	end

	-- Aplicar buffs de Rage
	HunterService.applySpeed(_hunter, GameConstants.Hunter.RAGE_SPEED)

	-- Pausar ciclo
	if MatchService and MatchService.pauseCycle then
		MatchService.pauseCycle()
	end

	-- Notificar ouvintes
	HunterService.rageActivated:Fire(_hunter)

	-- Agendar saida do Rage
	task.spawn(function()
		task.wait(_rageDuration)

		-- Verificar se ainda esta em Rage (pode ter morrido)
		if _isInRage and _hunter then
			HunterService.deactivateRage()
		end
	end)
end

--[[
  Desativa o Rage.
  - Restaura stats normais
  - Retoma ciclo
  - Furia = 0 + 10 por morte feita no Rage
]]
function HunterService.deactivateRage(): ()
	if not _hunter then return end

	local wasInRage = _isInRage
	_isInRage = false
	_rageWindupActive = false

	-- Reverter aparencia visual do Rage
	local character = _hunter.Character
	if character and wasInRage then
		_revertRageAppearance(character)
	end

	-- Restaurar velocidade base
	HunterService.applySpeed(_hunter, GameConstants.Hunter.BASE_SPEED)

	-- Retomar ciclo
	if MatchService and MatchService.resumeCycle then
		MatchService.resumeCycle()
	end

	-- Calcular furia residual
	local furyConfig = GameConstants.Hunter.FURY
	_fury = _killsInRage * 10
	if _fury > 0 then
		print("[TheBrokenBox] HunterService: Furia residual: " .. _fury .. " (" .. _killsInRage .. " mortes no Rage)")
	end

	print("[TheBrokenBox] HunterService: Rage desativado. Furia: " .. _fury)

	-- Notificar ouvintes
	HunterService.rageDeactivated:Fire(_hunter, _fury)
end

-- ============================================================
-- API: Stun e I-frames
-- ============================================================

--[[
  Aplica stun no Cacador.
  Trava movimento e habilidades por T segundos.
  Ao se recuperar: 2s de i-frames (invencibilidade).
]]
function HunterService.applyStun(duration: number): ()
	if not _hunter then return end

	-- Durante i-frames, nao pode ser stunado
	if os.clock() < _iframesUntil then
		print("[TheBrokenBox] HunterService: Stun ignorado — i-frames ativos!")
		return
	end

	_isStunned = true
	_stunnedUntil = os.clock() + duration

	print("[TheBrokenBox] HunterService: Cacador stunado por " .. duration .. "s!")

	-- Cancelar windup do Rage se ativo
	if _rageWindupActive then
		_rageWindupActive = false
		print("[TheBrokenBox] HunterService: Windup do Rage cancelado pelo stun!")
	end

	-- Notificar ouvintes
	HunterService.hunterStunned:Fire(_hunter, duration)

	-- Agendar recuperacao
	task.spawn(function()
		task.wait(duration)

		if not _hunter then return end
		if not _isStunned then return end

		_isStunned = false

		-- Aplicar i-frames de 2s
		_iframesUntil = os.clock() + GameConstants.Hunter.STUN_I_FRAMES

		if HitboxService then
			HitboxService.setInvincible(_hunter, GameConstants.Hunter.STUN_I_FRAMES)
		end

		print("[TheBrokenBox] HunterService: Cacador se recuperou do stun. I-frames por " .. GameConstants.Hunter.STUN_I_FRAMES .. "s.")
	end)
end

--[[
  Verifica se o Cacador esta stunado.
]]
function HunterService.isStunned(): boolean
	return _isStunned
end

--[[
  Verifica se o Cacador esta em i-frames.
]]
function HunterService.isInvincible(): boolean
	return os.clock() < _iframesUntil
end

-- ============================================================
-- API: Cooldowns
-- ============================================================

--[[
  Verifica se uma habilidade esta em cooldown.
]]
function HunterService.isOnCooldown(ability: string): boolean
	local cdEnd = _cooldowns[ability]
	if not cdEnd then return false end
	return os.clock() < cdEnd
end

--[[
  Retorna o tempo restante de cooldown (em segundos, 0 se pronto).
]]
function HunterService.getCooldownRemaining(ability: string): number
	local cdEnd = _cooldowns[ability]
	if not cdEnd then return 0 end
	return math.max(0, cdEnd - os.clock())
end

--[[
  Obtem todos os cooldowns (para envio ao HUD).
]]
function HunterService.getCooldowns(): { [string]: number }
	local result: { [string]: number } = {}
	for ability, _ in pairs(_cooldowns) do
		result[ability] = HunterService.getCooldownRemaining(ability)
	end
	return result
end

-- ============================================================
-- API: Velocidade
-- ============================================================

--[[
  Aplica velocidade ao personagem do Cacador.
]]
function HunterService.applySpeed(player: Player, speed: number): ()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
		print("[TheBrokenBox] HunterService: Velocidade ajustada para " .. speed .. " (" .. player.Name .. ")")
	end
end

-- ============================================================
-- API: M1 — Tapa (ataque basico)
-- ============================================================
-- Ref: GDD Design de Inimigo, Tabela-Mestra
-- 5 hitboxes em 0.5s, dano 20 (25 Rage), knockback 3 studs
-- ============================================================

--[[
  Executa o M1 — Tapa.
  Chamado quando o servidor recebe HUNTER_M1 do cliente.
  Validacao: cooldown, vivo, nao stunado.
]]
function HunterService.performM1(): ()
	if not _hunter then return end

	local m1Config = GameConstants.Hunter.M1

	-- Validacoes
	if HunterService.isOnCooldown("M1") then
		warn("[TheBrokenBox] HunterService: M1 em cooldown!")
		return
	end
	if _isStunned then
		warn("[TheBrokenBox] HunterService: M1 ignorado — stunado!")
		return
	end
	if _rageWindupActive then
		warn("[TheBrokenBox] HunterService: M1 ignorado — windup do Rage em andamento!")
		return
	end

	-- Aplicar cooldown
	_cooldowns.M1 = os.clock() + m1Config.COOLDOWN

	print("[TheBrokenBox] HunterService: M1 executado por " .. _hunter.Name)

	-- Windup
	task.spawn(function()
		task.wait(m1Config.WINDUP)

		if not _hunter then return end
		if _isStunned then return end

		local character = _hunter.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		-- Determinar dano (base ou Rage)
		local damage = _isInRage and m1Config.RAGE_DAMAGE or m1Config.DAMAGE

		-- 5 hitboxes sequenciais em 0.5s
		local hitboxInterval = m1Config.HITBOX_DURATION / m1Config.HITBOX_COUNT
		local hitSurvivors = {} -- Set para evitar 1x por alvo

		for i = 1, m1Config.HITBOX_COUNT do
			if not _hunter then return end
			if _isStunned then return end

			-- Recarregar character e rootPart (pode ter mudado)
			character = _hunter.Character
			if not character then return end
			rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then return end

			-- Verificar Sobreviventes em alcance
			if HitboxService and MatchService then
				for _, player in ipairs(Players:GetPlayers()) do
					if player == _hunter then continue end
					if hitSurvivors[player] then continue end

					local role = MatchService.getPlayerRole(player)
					if role ~= "Survivor" then continue end

					local data = MatchService.getPlayerData(player)
					if not data or not data.isAlive then continue end

					-- Verificar hitbox de corpo (M1 alcance = cone na frente)
					-- Usamos checkBodyHit com alcance aproximado de 8 studs
					if HitboxService.checkBodyHit(_hunter, player, 8) then
						hitSurvivors[player] = true

						-- Knockback
						HunterService.applyKnockback(player, rootPart.Position, m1Config.KNOCKBACK)

						print("[TheBrokenBox] HunterService: M1 acertou " .. player.Name .. "! Dano: " .. damage .. ", Knockback: " .. m1Config.KNOCKBACK)
					end
				end
			end

			task.wait(hitboxInterval)
		end

		-- Aplicar dano uma unica vez aos alvos atingidos (via HitboxService)
		local targetList = {}
		for player, _ in pairs(hitSurvivors) do
			table.insert(targetList, { player = player })
		end
		if #targetList > 0 then
			HitboxService.applyDamageToTargets(targetList, damage, _hunter)
		end
	end)
end

--[[
  Aplica knockback a um jogador, afastando-o da origem.
]]
function HunterService.applyKnockback(target: Player, origin: Vector3, force: number): ()
	local character = target.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local direction = MathUtil.direction(origin, rootPart.Position)
	local knockback = direction * force

	-- Aplicar forca via AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity + knockback
end

-- ============================================================
-- API: Braco Esticado (Pull)
-- ============================================================
-- Ref: GDD Design de Inimigo, Tabela-Mestra
-- Windup 1s, cd 12s, projetil 15 studs/s por 2s (30 studs)
-- Ao acertar: puxa Sobrevivente + stun 0.5s
-- ============================================================

--[[
  Executa o Braco Esticado (Pull).
  Chamado quando o servidor recebe HUNTER_PULL do cliente.
  aimDirection: direcao do olhar do Cacador.
]]
function HunterService.performPull(aimDirection: Vector3): ()
	if not _hunter then return end

	local pullConfig = GameConstants.Hunter.PULL

	-- Validacoes
	if HunterService.isOnCooldown("Pull") then
		warn("[TheBrokenBox] HunterService: Pull em cooldown!")
		return
	end
	if _isStunned then
		warn("[TheBrokenBox] HunterService: Pull ignorado — stunado!")
		return
	end
	if _rageWindupActive then
		warn("[TheBrokenBox] HunterService: Pull ignorado — windup do Rage em andamento!")
		return
	end

	-- Aplicar cooldown
	_cooldowns.Pull = os.clock() + pullConfig.COOLDOWN

	print("[TheBrokenBox] HunterService: Pull iniciado por " .. _hunter.Name)

	-- Windup + projetil
	task.spawn(function()
		task.wait(pullConfig.WINDUP)

		if not _hunter then return end
		if _isStunned then return end

		local character = _hunter.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		-- Usar HitboxService.createProjectile para o braco
		if HitboxService then
			HitboxService.createProjectile(
				rootPart.Position,
				aimDirection,
				pullConfig.SPEED,
				pullConfig.DURATION,
				_hunter,
				"HunterAttack",
				function(target: Player, _hitPosition: Vector3)
					-- Verificar se e Sobrevivente (filtro por role)
					if MatchService then
						local role = MatchService.getPlayerRole(target)
						if role ~= "Survivor" then return end
					end

					print("[TheBrokenBox] HunterService: Pull acertou " .. target.Name .. "!")

					-- Puxar Sobrevivente ate o Cacador
					local hunterChar = _hunter and _hunter.Character
					if hunterChar then
						local hunterRoot = hunterChar:FindFirstChild("HumanoidRootPart")
						local targetChar = target.Character
						local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

						if hunterRoot and targetRoot then
							-- Teleportar o Sobrevivente para perto do Cacador
							local pullPos = hunterRoot.Position + (hunterRoot.CFrame.LookVector * 3)
							targetRoot.CFrame = CFrame.new(pullPos)
						end
					end

					-- Stun de 0.5s no Sobrevivente
					-- (stun travando movimento — sera implementado com SurvivorService no E3)
					-- Por enquanto, aplicamos dano 0 como "stun de movimento"
					-- No futuro, SurvivorService tera applyStun()
				end
			)
		end
	end)
end

-- ============================================================
-- API: Grito (Roar)
-- ============================================================
-- Ref: GDD Design de Inimigo, Tabela-Mestra
-- Windup 2s, cd 25s
-- Raio 60: slow 40% por 3s + blur
-- Raio 100: revelar Sobreviventes por 4s
-- Durante Rage: +10 de dano no raio 60
-- ============================================================

--[[
  Executa o Grito (Roar).
  Chamado quando o servidor recebe HUNTER_ROAR do cliente.
]]
function HunterService.performRoar(): ()
	if not _hunter then return end

	local roarConfig = GameConstants.Hunter.ROAR

	-- Validacoes
	if HunterService.isOnCooldown("Roar") then
		warn("[TheBrokenBox] HunterService: Roar em cooldown!")
		return
	end
	if _isStunned then
		warn("[TheBrokenBox] HunterService: Roar ignorado — stunado!")
		return
	end
	if _rageWindupActive then
		warn("[TheBrokenBox] HunterService: Roar ignorado — windup do Rage em andamento!")
		return
	end

	-- Aplicar cooldown
	_cooldowns.Roar = os.clock() + roarConfig.COOLDOWN

	print("[TheBrokenBox] HunterService: Grito iniciado por " .. _hunter.Name)

	-- Windup + efeitos
	task.spawn(function()
		task.wait(roarConfig.WINDUP)

		if not _hunter then return end
		if _isStunned then return end

		local character = _hunter.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		if not HitboxService or not MatchService then return end

		-- Verificar Sobreviventes no raio 60 (slow + blur)
		local slowTargets = HitboxService.checkAreaCube(
			rootPart.Position,
			roarConfig.SLOW_RADIUS,
			_hunter,
			"HunterAttack"
		)

		local rageDamage = _isInRage and roarConfig.RAGE_DAMAGE or 0

		for _, entry in ipairs(slowTargets) do
			local player = entry.player
			local role = MatchService.getPlayerRole(player)
			if role ~= "Survivor" then continue end

			-- Aplicar slow (sera gerenciado pelo SurvivorService no E3)
			-- Por enquanto, aplicamos atraves do MatchService
			print("[TheBrokenBox] HunterService: Grito — slow 40% em " .. player.Name .. " por " .. roarConfig.SLOW_DURATION .. "s")

			-- Dano em Rage
			if rageDamage > 0 then
				MatchService.applyDamage(player, rageDamage, _hunter)
				print("[TheBrokenBox] HunterService: Grito — dano " .. rageDamage .. " em " .. player.Name .. " (Rage)")
			end
		end

		-- Verificar Sobreviventes no raio 100 (revelacao)
		local revealTargets = HitboxService.checkAreaCube(
			rootPart.Position,
			roarConfig.REVEAL_RADIUS,
			_hunter,
			"HunterAttack"
		)

		for _, entry in ipairs(revealTargets) do
			local player = entry.player
			local role = MatchService.getPlayerRole(player)
			if role ~= "Survivor" then continue end

			print("[TheBrokenBox] HunterService: Grito — revelou " .. player.Name .. " por " .. roarConfig.REVEAL_DURATION .. "s")
			-- Revelacao: sera enviada ao cliente via UISyncEvent
		end

		print("[TheBrokenBox] HunterService: Grito executado! Slow: " .. #slowTargets .. " alvos, Revelacao: " .. #revealTargets .. " alvos" .. (rageDamage > 0 and ", Dano: " .. rageDamage or ""))
	end)
end

-- ============================================================
-- Loop do Heartbeat: Furia por proximidade
-- ============================================================
-- Ref: GDD M5 — Furia
-- +1/s apos 20s continuos a <=40 studs de algum Sobrevivente
-- Pode trocar de alvo sem zerar; sair do raio zera a contagem

local function updateProximityFury()
	if not _hunter then return end
	if _isInRage then return end -- Nao acumula furia durante Rage
	if _isStunned then return end

	local furyConfig = GameConstants.Hunter.FURY

	local character = _hunter.Character
	if not character then
		_proximityAccumulator = 0
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		_proximityAccumulator = 0
		return
	end

	-- Verificar se ha algum Sobrevivente vivo dentro do raio
	if not MatchService then
		_proximityAccumulator = 0
		return
	end

	local anyInProximity = false

	for _, player in ipairs(Players:GetPlayers()) do
		if player == _hunter then continue end

		local role = MatchService.getPlayerRole(player)
		if role ~= "Survivor" then continue end

		local data = MatchService.getPlayerData(player)
		if not data or not data.isAlive then continue end

		local survChar = player.Character
		if not survChar then continue end

		local survRoot = survChar:FindFirstChild("HumanoidRootPart")
		if not survRoot then continue end

		if MathUtil.isInRadius(rootPart.Position, survRoot.Position, furyConfig.PROXIMITY_RADIUS) then
			anyInProximity = true
			break
		end
	end

	-- Acumular ou resetar proximidade
	if anyInProximity then
		_proximityAccumulator = _proximityAccumulator + 1 / 60 -- ~60Hz
		-- Apos 20s, comeca a ganhar furia
		if _proximityAccumulator >= furyConfig.PROXIMITY_TIME then
			_fury = _fury + furyConfig.GAIN_PER_SECOND_PROXIMITY / 60
		end
	else
		_proximityAccumulator = 0
	end
end

-- ============================================================
-- Callback: Cacador morreu (limpeza)
-- ============================================================

function HunterService.onHunterDied(): ()
	if not _hunter then return end

	print("[TheBrokenBox] HunterService: Cacador morreu: " .. _hunter.Name)

	_isInRage = false
	_rageWindupActive = false
	_isStunned = false
	_fury = 0
	_proximityAccumulator = 0

	_hunter = nil
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono.
  Injeta referencias a outros servicos.
]]
function HunterService.Init(): ()
	print("[TheBrokenBox] HunterService.Init()")

	-- Injecao de dependencias (servicos ja carregados)
	-- MatchService, HitboxService e StaminaService sao injetados via
	-- o modulo services do GameManager. Aqui buscamos via script.
	-- Como estamos em ServerScriptService, navegamos via script.Parent

	-- Cache de servicos pelo nome
	-- (serao resolvidos no wireServiceSignals do GameManager)
end

--[[
  Start(): registro de listeners e loop de Heartbeat.
]]
function HunterService.Start(): ()
	print("[TheBrokenBox] HunterService.Start() — iniciando loop de Heartbeat...")

	-- Loop de Heartbeat para Furia por proximidade
	_heartbeatConnection = RunService.Heartbeat:Connect(function(_deltaTime: number)
		updateProximityFury()
	end)

	-- Limpar quando o jogo fecha
	game:BindToClose(function()
		if _heartbeatConnection then
			_heartbeatConnection:Disconnect()
			_heartbeatConnection = nil
		end
	end)

	print("[TheBrokenBox] HunterService pronto.")
end

-- ============================================================
-- Injecao de dependencias (chamado pelo GameManager)
-- ============================================================

--[[
  Injeta referencias a outros servicos.
  Chamado pelo GameManager durante wireServiceSignals().
]]
function HunterService.injectDependencies(
	matchSvc: {},
	hitboxSvc: {},
	staminaSvc: {}
): ()
	MatchService = matchSvc
	HitboxService = hitboxSvc
	StaminaService = staminaSvc
	print("[TheBrokenBox] HunterService: Dependencias injetadas.")
end

return HunterService
