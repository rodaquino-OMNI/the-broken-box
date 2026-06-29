--!strict
--[[
  EscapeService.lua
  Servico de dominio que gerencia a fase de Fuga e Resolucao.
  Ciclo de vida: Init/Start pattern.

  Responsabilidades:
    - Escuta o sinal cycleZero do CycleService
    - Abre os 3 portoes nas posicoes do MapData
    - Calcula janela de fuga: ESCAPE_WINDOW_BASE - (missoes pendentes * REDUCE_PER_MISSION)
    - Ativa perigos das missoes pendentes (escuridao, barreira eletrica, poco de oleo)
    - Spawna fogo estetico nos portoes
    - Detecta jogadores que cruzam os portoes (escape)
    - Dispara sinais: escapeStarted, playerEscaped, escapeEnded
    - Resolve condicao de vitoria/derrota ao fim da janela

  Sinais expostos:
    escapeStarted  - quando a janela de fuga abre
    playerEscaped  - quando um jogador escapa (player: Player, gateId: string)
    escapeEnded    - quando a janela fecha (survivorsEscaped: number, totalSurvivors: number)

  Referencias: GDD M2 Portoes e Fuga, E6 stories
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local MapData = require(ReplicatedStorage.MapData.MapData)
local Signal = require(ReplicatedStorage.Util.Signal)

local EscapeService = {}
EscapeService.Name = "EscapeService"

-- ============================================================
-- Sinais do servico
-- ============================================================
EscapeService.escapeStarted = Signal.new()   -- ()
EscapeService.playerEscaped = Signal.new()   -- (player: Player, gateId: string)
EscapeService.escapeEnded = Signal.new()     -- (survivorsEscaped: number, totalAliveAtStart: number)

-- ============================================================
-- Estado interno
-- ============================================================
local _state = {
	isEscaping = false,
	escapeWindowDuration = 0,
	escapeStartTime = 0,
	escapedPlayers = {},          -- { [Player] = gateId }
	gateConnections = {},        -- conexoes de Heartbeat para deteccao
	hazardObjects = {},          -- objetos criados (partes, luzes)
	fireObjects = {},            -- objetos de fogo estetico
	barrierImmunity = {},        -- { [Player] = lastDamageTime } para barreira V2
}

-- Cache de servicos (injetados pelo GameManager)
local _matchService = nil
local _mapService = nil
local _missionService = nil
local _shopService = nil

-- ============================================================
-- API: Injecao de dependencias
-- ============================================================

--[[
  Injeta servicos dependentes.
  Chamado pelo GameManager em wireServiceSignals().
]]
function EscapeService.injectDependencies(
	matchService: {},
	mapService: {},
	missionService: {}?,
	shopService: {}?
): ()
	_matchService = matchService
	_mapService = mapService
	_missionService = missionService
	_shopService = shopService
	print("[TheBrokenBox] EscapeService: Dependencias injetadas.")
end

-- ============================================================
-- API: Calculo da janela de fuga
-- ============================================================

--[[
  Calcula a duracao da janela de fuga baseada nas missoes pendentes.
  Formula: ESCAPE_WINDOW_BASE - (pendingCount * ESCAPE_WINDOW_REDUCE_PER_MISSION)
  Piso: ESCAPE_WINDOW_FLOOR

  Retorna a duracao em segundos.
]]
function EscapeService.calculateEscapeWindow(): number
	local pendingCount = 0

	-- Contar missoes pendentes via MissionService (se disponivel)
	if _missionService and _missionService.getPendingMissions then
		local pendingMissions = _missionService.getPendingMissions()
		if pendingMissions then
			pendingCount = #pendingMissions
		end
	end

	local base = GameConstants.Game.ESCAPE_WINDOW_BASE
	local reduce = GameConstants.Game.ESCAPE_WINDOW_REDUCE_PER_MISSION
	local floor = GameConstants.Game.ESCAPE_WINDOW_FLOOR

	local duration = base - (pendingCount * reduce)
	duration = math.max(duration, floor)

	print("[TheBrokenBox] EscapeService: Janela de fuga calculada: " .. duration .. "s (missoes pendentes: " .. pendingCount .. ")")
	return duration
end

-- ============================================================
-- API: Abertura dos portoes
-- ============================================================

--[[
  Abre os 3 portoes de fuga.
  Cria marcadores visuais na workspace nas posicoes do MapData.
]]
local function openGates()
	local gates = MapData.GATES
	local gateMarkers = {}

	for _, gate in ipairs(gates) do
		local pos = MapData.toVector3(gate.position)

		-- Criar marcador do portao na workspace
		local marker = Instance.new("Part")
		marker.Name = "Gate_" .. gate.id
		marker.Position = pos
		marker.Size = Vector3.new(10, 12, 2)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 5/10
		marker.BrickColor = BrickColor.new("Bright green")
		marker.Material = Enum.Material.Neon
		marker.Parent = Workspace

		-- Adicionar luz para visibilidade
		local pointLight = Instance.new("PointLight")
		pointLight.Name = "GateLight"
		pointLight.Range = 30
		pointLight.Brightness = 2
		pointLight.Color = Color3.fromRGB(100, 255, 100)
		pointLight.Parent = marker

		-- Billboard para identificacao
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "GateLabel"
		billboard.Size = UDim2.new(0, 200, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 8, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = marker

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Text = gate.name .. " [FUGA]"
		label.TextColor3 = Color3.fromRGB(100, 255, 100)
		label.TextSize = 16
		label.Font = Enum.Font.SourceSansBold
		label.BackgroundTransparency = 1
		label.Parent = billboard

		table.insert(gateMarkers, marker)
		print("[TheBrokenBox] EscapeService: Portao aberto: " .. gate.id .. " - " .. gate.name .. " em " .. tostring(pos))
	end

	return gateMarkers
end

-- ============================================================
-- API: Perigos das missoes pendentes
-- ============================================================

--[[
  Ativa os perigos das missoes pendentes.
  V1 (Breaker): Escuridao localizada - remove PointLights na area
  V2 (Generator): Barreira eletrica - 10 de dano, 5s de imunidade por jogador
  V3 (Oil): Poca de oleo - 35% de lentidao
]]
local function activateHazards(): ()
	if not _missionService or not _missionService.getPendingMissions then
		print("[TheBrokenBox] EscapeService: MissionService nao disponivel - sem perigos para ativar.")
		return
	end

	local pendingMissions = _missionService.getPendingMissions()
	if not pendingMissions or #pendingMissions == 0 then
		print("[TheBrokenBox] EscapeService: Nenhuma missao pendente - sem perigos.")
		return
	end

	for _, mission in ipairs(pendingMissions) do
		local pos = MapData.toVector3(mission.position)
		local missionType = mission.type

		if missionType == "V1" then
			-- V1: Escuridao localizada
			-- Remover PointLights num raio de 40 studs
			local darkZone = Instance.new("Part")
			darkZone.Name = "Hazard_Darkness_" .. mission.id
			darkZone.Position = pos
			darkZone.Size = Vector3.new(40, 20, 40)
			darkZone.Anchored = true
			darkZone.CanCollide = false
			darkZone.Transparency = 7/10
			darkZone.BrickColor = BrickColor.new("Black")
			darkZone.Material = Enum.Material.SmoothPlastic
			darkZone.Parent = Workspace

			-- Apagar luzes existentes na area
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
					local distance = (obj.Parent.Position - pos).Magnitude
					if distance <= 40 then
						obj.Enabled = false
						table.insert(_state.hazardObjects, obj)
					end
				end
			end

			table.insert(_state.hazardObjects, darkZone)
			print("[TheBrokenBox] EscapeService: Perigo V1 (Escuridao) ativado em " .. mission.id)

		elseif missionType == "V2" then
			-- V2: Barreira eletrica
			local barrier = Instance.new("Part")
			barrier.Name = "Hazard_Barrier_" .. mission.id
			barrier.Position = pos
			barrier.Size = Vector3.new(8, 10, 1)
			barrier.Anchored = true
			barrier.CanCollide = true
			barrier.Transparency = 3/10
			barrier.BrickColor = BrickColor.new("Bright yellow")
			barrier.Material = Enum.Material.Neon
			barrier.Parent = Workspace

			-- Efeito eletrico visual
			local sparkles = Instance.new("Sparkles")
			sparkles.Name = "Electric"
			sparkles.Color = Color3.fromRGB(255, 255, 100)
			sparkles.Parent = barrier

			-- Touch listener para dano
			barrier.Touched:Connect(function(hit: BasePart)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player then
					return
				end

				-- Verificar imunidade (5s)
				local now = os.clock()
				local lastHit = _state.barrierImmunity[player]
				if lastHit and (now - lastHit) < GameConstants.Missions.V2_GENERATOR.BARRIER_IMMUNITY then
					return
				end

				-- Aplicar dano
				_state.barrierImmunity[player] = now
				local damage = GameConstants.Missions.V2_GENERATOR.BARRIER_DAMAGE

				if _matchService and _matchService.applyDamage then
					_matchService.applyDamage(player, damage, nil)
					print("[TheBrokenBox] EscapeService: Barreira eletrica - " .. player.Name .. " sofreu " .. damage .. " de dano")
				end
			end)

			table.insert(_state.hazardObjects, barrier)
			print("[TheBrokenBox] EscapeService: Perigo V2 (Barreira Eletrica) ativado em " .. mission.id)

		elseif missionType == "V3" then
			-- V3: Poca de oleo (35% de lentidao)
			local oilPuddle = Instance.new("Part")
			oilPuddle.Name = "Hazard_Oil_" .. mission.id
			oilPuddle.Position = pos + Vector3.new(0, 5/100, 0)
			oilPuddle.Size = Vector3.new(20, 2/10, 20)
			oilPuddle.Anchored = true
			oilPuddle.CanCollide = false
			oilPuddle.Transparency = 4/10
			oilPuddle.BrickColor = BrickColor.new("Black")
			oilPuddle.Material = Enum.Material.SmoothPlastic
			oilPuddle.Parent = Workspace

			-- Billboard para indicar lentidao
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "OilLabel"
			billboard.Size = UDim2.new(0, 200, 0, 30)
			billboard.StudsOffset = Vector3.new(0, 4, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = oilPuddle

			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.new(1, 0, 1, 0)
			label.Text = "OLEO - LENTIDAO!"
			label.TextColor3 = Color3.fromRGB(200, 150, 50)
			label.TextSize = 14
			label.Font = Enum.Font.SourceSansBold
			label.BackgroundTransparency = 1
			label.Parent = billboard

			-- Touch listener para lentidao
			local slowPercent = GameConstants.Missions.V3_OIL.SLOW_PERCENT

			oilPuddle.Touched:Connect(function(hit: BasePart)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player then
					return
				end

				local char = player.Character
				if not char then
					return
				end

				local humanoid: Humanoid? = char:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local originalSpeed = humanoid.WalkSpeed
					local slowedSpeed = originalSpeed * (1 - slowPercent / 100)
					humanoid.WalkSpeed = slowedSpeed

					-- Restaurar velocidade ao sair
					local function restoreSpeed(otherHit: BasePart)
						local otherPlayer = Players:GetPlayerFromCharacter(otherHit.Parent)
						if otherPlayer == player then
							if humanoid then
								humanoid.WalkSpeed = originalSpeed
							end
						end
					end

					-- Conectar TouchEnded
					oilPuddle.TouchEnded:Connect(restoreSpeed)
				end
			end)

			table.insert(_state.hazardObjects, oilPuddle)
			print("[TheBrokenBox] EscapeService: Perigo V3 (Poca de Oleo) ativado em " .. mission.id)
		end
	end

	print("[TheBrokenBox] EscapeService: " .. #pendingMissions .. " perigos ativados.")
end

-- ============================================================
-- API: Fogo estetico
-- ============================================================

--[[
  Spawna fogo estetico ao redor dos portoes.
  O fogo NAO causa dano - apenas sinaliza o colapso.
]]
local function spawnAestheticFire(gateMarkers: { any }): ()
	for _, marker in ipairs(gateMarkers) do
		local pos = marker.Position

		-- Criar 3 particulas de fogo ao redor de cada portao
		for i = 1, 3 do
			local offset = Vector3.new(
				math.random(-15, 15),
				math.random(0, 5),
				math.random(-15, 15)
			)

			local firePart = Instance.new("Part")
			firePart.Name = "AestheticFire"
			firePart.Position = pos + offset
			firePart.Size = Vector3.new(1, 1, 1)
			firePart.Anchored = true
			firePart.CanCollide = false
			firePart.Transparency = 1
			firePart.Parent = Workspace

			local fire = Instance.new("Fire")
			fire.Name = "FireEffect"
			fire.Heat = 0
			fire.Size = 6
			fire.Color = Color3.fromRGB(255, 100, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 200, 50)
			fire.Enabled = true
			fire.Parent = firePart

			-- Smoke
			local smoke = Instance.new("Smoke")
			smoke.Name = "SmokeEffect"
			smoke.RiseVelocity = 2
			smoke.Size = 3
			smoke.Opacity = 3/10
			smoke.Color = Color3.fromRGB(80, 80, 80)
			smoke.Parent = firePart

			table.insert(_state.fireObjects, firePart)
		end
	end

	print("[TheBrokenBox] EscapeService: Fogo estetico spawnado nos portoes.")
end

-- ============================================================
-- API: Deteccao de escape
-- ============================================================

--[[
  Verifica se um jogador esta perto o suficiente de um portao para escapar.
  Raio de deteccao: 12 studs do centro do portao.
]]
local function checkPlayerEscape(player: Player): (boolean, string?)
	if _state.escapedPlayers[player] then
		return false, nil -- Ja escapou
	end

	local char = player.Character
	if not char or not char.PrimaryPart then
		return false, nil
	end

	local playerPos = char.PrimaryPart.Position
	local detectionRadius = 12

	for _, gate in ipairs(MapData.GATES) do
		local gatePos = MapData.toVector3(gate.position)
		local distance = (playerPos - gatePos).Magnitude

		if distance <= detectionRadius then
			return true, gate.id
		end
	end

	return false, nil
end

-- ============================================================
-- API: Coracao do escape (loop de Heartbeat)
-- ============================================================

--[[
  Inicia o loop de deteccao de escape e contagem regressiva.
]]
local function startEscapeLoop(): ()
	local endTime = _state.escapeStartTime + _state.escapeWindowDuration

	local heartBeatConnection: RBXScriptConnection?
	heartBeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = os.clock()

		-- Verificar timeout da janela
		if now >= endTime then
			-- Janela fechou
			if heartBeatConnection then
				heartBeatConnection:Disconnect()
			end
			finishEscape()
			return
		end

		-- Detectar escapes: verificar cada Sobrevivente vivo
		if _matchService then
			local survivors = _matchService.getPlayersByRole("Survivor")
			for _, player in ipairs(survivors) do
				local data = _matchService.getPlayerData(player)
				if data and data.isAlive and not _state.escapedPlayers[player] then
					local escaped, gateId = checkPlayerEscape(player)
					if escaped then
						registerEscape(player, gateId)
					end
				end
			end
		end

		-- Verificar se todos escaparam ou morreram
		if _matchService then
			local aliveCount = _matchService.getAliveSurvivorCount() or 0
			local escapedCount = tableCount(_state.escapedPlayers)

			if aliveCount == 0 or (aliveCount > 0 and escapedCount >= aliveCount) then
				-- Todos escaparam ou morreram
				if heartBeatConnection then
					heartBeatConnection:Disconnect()
				end
				finishEscape()
				return
			end
		end
	end)

	table.insert(_state.gateConnections, heartBeatConnection)
end

-- ============================================================
-- API: Registro de escape
-- ============================================================

--[[
  Registra que um jogador escapou.
  Dispara playerEscaped, concede moedas e notifica o cliente.
]]
function registerEscape(player: Player, gateId: string): ()
	if _state.escapedPlayers[player] then
		return -- Ja escapou
	end

	_state.escapedPlayers[player] = gateId

	print("[TheBrokenBox] EscapeService: " .. player.Name .. " escapou pelo portao " .. gateId .. "!")

	-- Conceder moedas de fuga (COIN_FUGA = 40)
	local coinReward = GameConstants.Economy.COIN_FUGA

	if _shopService and _shopService.addCoins then
		_shopService.addCoins(player, coinReward)
		print("[TheBrokenBox] EscapeService: +" .. coinReward .. " moedas para " .. player.Name)
	else
		print("[TheBrokenBox] EscapeService: ShopService nao disponivel - moedas nao creditadas.")
	end

	-- Disparar sinal
	EscapeService.playerEscaped:Fire(player, gateId)
end

-- ============================================================
-- API: Finalizacao e resolucao de vitoria
-- ============================================================

--[[
  Finaliza a fase de fuga.
  Resolve condicao de vitoria/derrota.
  Dispara MATCH_ENDED.
]]
function finishEscape(): ()
	if not _state.isEscaping then
		return
	end

	_state.isEscaping = false

	local escapedCount = tableCount(_state.escapedPlayers)
	local totalAliveAtStart = 0

	if _matchService then
		totalAliveAtStart = _matchService.getAliveSurvivorCount() + escapedCount
	end

	print("[TheBrokenBox] EscapeService: Fuga encerrada. Escaparam: " .. escapedCount .. " de " .. totalAliveAtStart)

	-- Limpar objetos dos portoes, perigos e fogo
	cleanupEscapeObjects()

	-- Resolver vitoria
	local winner: string
	local result: string

	if escapedCount > 0 then
		winner = "Survivors"
		if escapedCount == totalAliveAtStart then
			result = "FugaTotal"
		else
			result = "FugaParcial"
		end
	else
		winner = "Hunter"
		result = "Contencao"
	end

	print("[TheBrokenBox] EscapeService: Resultado - " .. winner .. " venceu! (" .. result .. ")")

	-- Disparar sinal de escape encerrado
	EscapeService.escapeEnded:Fire(escapedCount, totalAliveAtStart)

	-- Notificar MatchService para encerrar a partida
	-- (GameManager fara o wiring para MATCH_ENDED e setMatchState("Ended"))
	print("[TheBrokenBox] EscapeService: Partida encerrada. Vencedor: " .. winner)
end

-- ============================================================
-- API: Limpeza
-- ============================================================

--[[
  Remove todos os objetos criados durante a fuga.
]]
function cleanupEscapeObjects(): ()
	-- Desconectar Heartbeat
	for _, conn in ipairs(_state.gateConnections) do
		conn:Disconnect()
	end
	_state.gateConnections = {}

	-- Destruir marcadores de portao
	for _, marker in ipairs(Workspace:GetChildren()) do
		if marker:IsA("Part") and marker.Name:sub(1, 5) == "Gate_" then
			marker:Destroy()
		end
	end

	-- Destruir perigos
	for _, obj in ipairs(_state.hazardObjects) do
		if obj.Parent then
			obj:Destroy()
		end
	end
	_state.hazardObjects = {}

	-- Restaurar luzes apagadas (V1) - ja foram destruidas se eram Parts;
	-- para PointLight/SpotLight que foram desabilitados, reabilitar
	-- (as luzes foram armazenadas em hazardObjects e destruidas, entao
	--  se elas eram Parts, foram removidas; se so foram desabilitadas,
	--  nao temos como reabilitar sem referencia - aceitavel para MVP)

	-- Destruir fogo estetico
	for _, fire in ipairs(_state.fireObjects) do
		if fire.Parent then
			fire:Destroy()
		end
	end
	_state.fireObjects = {}

	print("[TheBrokenBox] EscapeService: Objetos da fuga removidos.")
end

-- ============================================================
-- API: Gatilho principal - ciclo zero
-- ============================================================

--[[
  Chamado quando o Ciclo zera (cycleZero do CycleService).
  Inicia a fase de fuga: abre portoes, ativa perigos, spawna fogo,
  inicia contagem e deteccao.
]]
function EscapeService.startEscape(): ()
	if _state.isEscaping then
		warn("[TheBrokenBox] EscapeService: Fuga ja esta em andamento!")
		return
	end

	print("[TheBrokenBox] EscapeService: ========================================")
	print("[TheBrokenBox] EscapeService: FUGA INICIADA!")
	print("[TheBrokenBox] EscapeService: ========================================")

	_state.isEscaping = true
	_state.escapedPlayers = {}
	_state.barrierImmunity = {}

	-- Transicionar estado da partida para Escaping
	if _matchService then
		_matchService.setMatchState("Escaping")
	end

	-- Calcular janela de fuga
	_state.escapeWindowDuration = EscapeService.calculateEscapeWindow()
	_state.escapeStartTime = os.clock()

	-- Abrir portoes
	local gateMarkers = openGates()

	-- Ativar perigos das missoes pendentes
	activateHazards()

	-- Spawnar fogo estetico
	spawnAestheticFire(gateMarkers)

	-- Disparar sinal de inicio
	EscapeService.escapeStarted:Fire()

	-- Iniciar loop de deteccao
	startEscapeLoop()

	print("[TheBrokenBox] EscapeService: Janela de fuga: " .. _state.escapeWindowDuration .. "s")
end

-- ============================================================
-- Utilitarios
-- ============================================================

--[[
  Conta quantas entradas uma tabela (dicionario) tem.
]]
local function tableCount(t: {}): number
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono.
]]
function EscapeService.Init(): ()
	print("[TheBrokenBox] EscapeService.Init()")
	_state.isEscaping = false
	_state.escapeWindowDuration = 0
	_state.escapeStartTime = 0
	_state.escapedPlayers = {}
	_state.gateConnections = {}
	_state.hazardObjects = {}
	_state.fireObjects = {}
	_state.barrierImmunity = {}
end

--[[
  Start(): registro de listeners.
]]
function EscapeService.Start(): ()
	print("[TheBrokenBox] EscapeService.Start()")
	-- O wiring com CycleService e feito pelo GameManager
	-- (cycleZero -> EscapeService.startEscape())
	print("[TheBrokenBox] EscapeService pronto. Aguardando sinal cycleZero...")
end

return EscapeService
