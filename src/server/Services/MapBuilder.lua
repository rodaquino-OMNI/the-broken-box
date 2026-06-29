--!strict
--[[
  MapBuilder.lua
  Servico que constroi todo o mapa Criatividade Morta
  proceduralmente no servidor ao iniciar a partida.

  Cria no Workspace a pasta "CriatividadeMorta" com:
    - Chao base (500x500 studs, cor papela/caixa)
    - 3 estruturas: Castelo, Caverna, Estoque
    - 14 marcadores de missao (V1/V2/V3)
    - 3 arcos de portao
    - Obstaculos (caixas espalhadas)
    - Decoracao de horror (corpos de brinquedo)

  Todas as coordenadas sao lidas do MapData (shared).
  Todas as Parts sao Anchored = true.

  Init/Start pattern - compatível com GameManager.
  Referencias: GDD Design do Mapa, MapData.lua, architecture.md
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapData = require(ReplicatedStorage.MapData.MapData)

local MapBuilder = {}
MapBuilder.Name = "MapBuilder"

-- ============================================================
-- Constantes locais
-- ============================================================

local COR_CARDBOARD = Color3.fromRGB(196, 168, 130)  -- #C4A882
local COR_CINZA_ESCURO = Color3.fromRGB(60, 60, 60)
local COR_MARROM_ESCURO = Color3.fromRGB(80, 60, 40)
local COR_PEDRA = Color3.fromRGB(100, 95, 90)
local COR_LARANJA = Color3.fromRGB(220, 140, 40)
local COR_AMARELO = Color3.fromRGB(240, 200, 40)
local COR_VERMELHO_ESCURO = Color3.fromRGB(120, 30, 20)
local COR_PRETO = Color3.fromRGB(30, 30, 30)
local COR_CINZA_CLARO = Color3.fromRGB(160, 160, 165)
local COR_BRANCO_SUJO = Color3.fromRGB(230, 225, 215)
local COR_AZUL_ESCURO = Color3.fromRGB(25, 30, 60)

-- Flag: ja construiu o mapa?
local _mapBuilt = false

-- ============================================================
-- Helpers
-- ============================================================

--[[
  Cria uma Part com as propriedades fornecidas.
  Retorna a Part criada.
]]
local function criarPart(
	parent: Instance,
	nome: string,
	tamanho: Vector3,
	posicao: Vector3,
	cor: Color3?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = nome
	part.Size = tamanho
	part.Position = posicao
	part.Anchored = true
	part.CanCollide = true
	if cor then
		part.Color = cor
	end
	if material then
		part.Material = material
	end
	part.Parent = parent
	return part
end

--[[
  Cria uma parede retangular (Part fina) entre dois pontos.
]]
local function criarParede(
	parent: Instance,
	nome: string,
	de: Vector3,
	ate: Vector3,
	grossura: number,
	altura: number,
	cor: Color3?,
	material: Enum.Material?
): Part
	local centroX = (de.X + ate.X) / 2
	local centroZ = (de.Z + ate.Z) / 2
	local centroY = (de.Y + ate.Y) / 2 + altura / 2

	local deltaX = math.abs(ate.X - de.X)
	local deltaZ = math.abs(ate.Z - de.Z)
	local comprimento: number
	local tamanho: Vector3

	if deltaX > deltaZ then
		-- Parede ao longo do eixo X
		comprimento = deltaX
		tamanho = Vector3.new(comprimento, altura, grossura)
	else
		-- Parede ao longo do eixo Z
		comprimento = deltaZ
		tamanho = Vector3.new(grossura, altura, comprimento)
	end

	return criarPart(
		parent, nome,
		tamanho,
		Vector3.new(centroX, centroY, centroZ),
		cor, material
	)
end

--[[
  Cria uma PointLight com configuracao personalizada.
]]
local function criarPointLight(
	parent: Instance,
	nome: string,
	posicao: Vector3,
	brilho: number,
	alcance: number,
	cor: Color3?
): PointLight
	local luz = Instance.new("PointLight")
	luz.Name = nome
	luz.Brightness = brilho
	luz.Range = alcance
	luz.Shadows = false
	if cor then
		luz.Color = cor
	end
	-- Precisamos de um Part ou Attachment como parent da luz
	local ancora = criarPart(parent, nome .. "_Ancora", Vector3.new(0.3, 0.3, 0.3), posicao, nil, nil)
	ancora.Transparency = 1
	ancora.CanCollide = false
	luz.Parent = ancora
	return luz
end

--[[
  Cria um piso (Part plana) em uma regiao.
]]
local function criarPiso(
	parent: Instance,
	nome: string,
	minX: number, maxX: number,
	y: number,
	minZ: number, maxZ: number,
	cor: Color3?,
	material: Enum.Material?
): Part
	local largura = maxX - minX
	local profundidade = maxZ - minZ
	local centroX = (minX + maxX) / 2
	local centroZ = (minZ + maxZ) / 2
	return criarPart(
		parent, nome,
		Vector3.new(largura, 1, profundidade),
		Vector3.new(centroX, y, centroZ),
		cor, material
	)
end

--[[
  Cria multiplas Parts empilhadas para formar uma coluna/torre.
]]
local function criarColuna(
	parent: Instance,
	nome: string,
	posX: number, posZ: number,
	baseY: number, altura: number,
	lado: number,
	cor: Color3?,
	material: Enum.Material?
): { Part }
	local parts: { Part } = {}
	local segmentos = math.ceil(altura / 10)
	local alturaSegmento = altura / segmentos
	for i = 1, segmentos do
		local y = baseY + (i - 0.5) * alturaSegmento
		local p = criarPart(
			parent,
			nome .. "_Seg" .. tostring(i),
			Vector3.new(lado, alturaSegmento, lado),
			Vector3.new(posX, y, posZ),
			cor, material
		)
		table.insert(parts, p)
	end
	return parts
end

-- ============================================================
-- Construcao: Chao base
-- ============================================================

local function construirChao(parent: Instance): Part
	print("[TheBrokenBox] MapBuilder: Construindo chao base (500x500)...")

	-- Chao principal
	local chao = criarPart(
		parent, "ChaoBase",
		Vector3.new(500, 2, 500),
		Vector3.new(0, -1, 0),
		COR_CARDBOARD,
		Enum.Material.WoodPlanks
	)

	-- Grade decorativa no chao (linhas de papelao ondulado)
	for x = -240, 240, 40 do
		criarPart(
			parent, "GradeVertical_" .. tostring(x),
			Vector3.new(1, 0.2, 500),
			Vector3.new(x, 0.1, 0),
			COR_MARROM_ESCURO,
			Enum.Material.WoodPlanks
		)
	end
	for z = -240, 240, 40 do
		criarPart(
			parent, "GradeHorizontal_" .. tostring(z),
			Vector3.new(500, 0.2, 1),
			Vector3.new(0, 0.1, z),
			COR_MARROM_ESCURO,
			Enum.Material.WoodPlanks
		)
	end

	print("[TheBrokenBox] MapBuilder: Chao base concluido.")
	return chao
end

-- ============================================================
-- Construcao: Castelo
-- ============================================================

local function construirCastelo(parent: Instance): { Part }
	print("[TheBrokenBox] MapBuilder: Construindo Castelo...")

	local s = MapData.STRUCTURES.CASTLE
	local cx = (s.min.x + s.max.x) / 2   -- centro X
	local cz = (s.min.z + s.max.z) / 2   -- centro Z
	local baseY = s.min.y                 -- 0
	local altura = s.max.y - s.min.y      -- 40

	local parts: { Part } = {}

	-- === Piso do Castelo ===
	table.insert(parts, criarPiso(
		parent, "Castelo_Piso",
		s.min.x, s.max.x, baseY + 0.5,
		s.min.z, s.max.z,
		COR_CINZA_ESCURO,
		Enum.Material.Slate
	))

	-- === Torres nos cantos (4) ===
	local cantos = {
		{ x = s.min.x, z = s.min.z, nome = "TorreNO" },
		{ x = s.min.x, z = s.max.z, nome = "TorreNE" },
		{ x = s.max.x, z = s.min.z, nome = "TorreSO" },
		{ x = s.max.x, z = s.max.z, nome = "TorreSE" },
	}
	local ladoTorre = 10
	for _, canto in ipairs(cantos) do
		local colParts = criarColuna(
			parent, "Castelo_" .. canto.nome,
			canto.x, canto.z,
			baseY, altura,
			ladoTorre,
			COR_PEDRA,
			Enum.Material.Slate
		)
		for _, p in ipairs(colParts) do
			table.insert(parts, p)
		end

		-- AmEias (battlements) no topo
		local topoY = baseY + altura
		for i = -1, 1, 2 do
			for j = -1, 1, 2 do
				local ameia = criarPart(
					parent, "Castelo_Ameia_" .. canto.nome .. "_" .. tostring(i) .. tostring(j),
					Vector3.new(3, 4, 3),
					Vector3.new(canto.x + i * 4, topoY + 2, canto.z + j * 4),
					COR_PEDRA,
					Enum.Material.Slate
				)
				table.insert(parts, ameia)
			end
		end
	end

	-- === Muralhas (paredes entre torres) ===
	local muros = {
		{ de = Vector3.new(s.min.x, baseY, s.min.z), ate = Vector3.new(s.min.x, baseY, s.max.z), nome = "MuroOeste" },
		{ de = Vector3.new(s.min.x, baseY, s.max.z), ate = Vector3.new(s.max.x, baseY, s.max.z), nome = "MuroNorte" },
		{ de = Vector3.new(s.max.x, baseY, s.min.z), ate = Vector3.new(s.max.x, baseY, s.max.z), nome = "MuroLeste" },
		{ de = Vector3.new(s.min.x, baseY, s.min.z), ate = Vector3.new(s.max.x, baseY, s.min.z), nome = "MuroSul" },
	}

	for _, muro in ipairs(muros) do
		-- Dividir a muralha em segmentos para efeito visual (com frestas)
		local segmentos = 4
		local deltaX = muro.ate.X - muro.de.X
		local deltaZ = muro.ate.Z - muro.de.Z
		local stepX = deltaX / segmentos
		local stepZ = deltaZ / segmentos

		for seg = 0, segmentos - 1 do
			local segDeX = muro.de.X + seg * stepX
			local segDeZ = muro.de.Z + seg * stepZ

			-- Criar dois blocos (inferior e superior) com um vao entre eles
			-- Bloco inferior: 60% da altura
			local pInferior = criarParede(
				parent, "Castelo_" .. muro.nome .. "_Inf_" .. tostring(seg),
				Vector3.new(segDeX, baseY, segDeZ),
				Vector3.new(segDeX + stepX, baseY, segDeZ + stepZ),
				2, altura * 0.55,
				COR_PEDRA,
				Enum.Material.Slate
			)
			table.insert(parts, pInferior)

			-- Bloco superior: 30% da altura, comecando de 70%
			local supBaseY = baseY + altura * 0.70
			local supAltura = altura * 0.30
			local centroY = supBaseY + supAltura / 2
			local pSuperior = criarParede(
				parent, "Castelo_" .. muro.nome .. "_Sup_" .. tostring(seg),
				Vector3.new(segDeX, baseY, segDeZ),
				Vector3.new(segDeX + stepX, baseY, segDeZ + stepZ),
				2, supAltura,
				COR_PEDRA,
				Enum.Material.Slate
			)
			-- Reposicionar Y manualmente (criarParede calcula do de.y)
			pSuperior.Position = Vector3.new(
				pSuperior.Position.X,
				supBaseY + supAltura / 2,
				pSuperior.Position.Z
			)
			table.insert(parts, pSuperior)
		end
	end

	-- === Piso intermediario (andar 2, y=18) ===
	table.insert(parts, criarPiso(
		parent, "Castelo_Piso2",
		s.min.x + 5, s.max.x - 5,
		baseY + 18,
		s.min.z + 5, s.max.z - 5,
		COR_MARROM_ESCURO,
		Enum.Material.WoodPlanks
	))

	-- === Rampas de acesso (escalavel por fora) ===
	-- Pequenas plataformas nas paredes externas para escalada
	local plataformaSize = Vector3.new(4, 0.5, 6)
	for y = 5, 30, 8 do
		-- Lado oeste (externo)
		criarPart(
			parent, "Castelo_Escalada_O_" .. tostring(y),
			plataformaSize,
			Vector3.new(s.min.x - 3, baseY + y, cz),
			COR_MARROM_ESCURO,
			Enum.Material.WoodPlanks
		)
		-- Lado leste (externo)
		criarPart(
			parent, "Castelo_Escalada_L_" .. tostring(y),
			plataformaSize,
			Vector3.new(s.max.x + 3, baseY + y, cz),
			COR_MARROM_ESCURO,
			Enum.Material.WoodPlanks
		)
	end

	-- === Portao principal (abertura no muro sul) ===
	-- Deixar uma abertura: nao colocar parede no centro do muro sul
	-- Criar um arco de entrada
	local portaoX = cx
	local portaoZ = s.min.z
	criarPart(
		parent, "Castelo_ArcoEntrada_Topo",
		Vector3.new(10, 1, 3),
		Vector3.new(portaoX, baseY + 5, portaoZ),
		COR_PEDRA,
		Enum.Material.Slate
	)
	-- Pilares da entrada
	for lado = -1, 1, 2 do
		criarPart(
			parent, "Castelo_PilarEntrada_" .. tostring(lado),
			Vector3.new(2, 5, 3),
			Vector3.new(portaoX + lado * 5, baseY + 2.5, portaoZ),
			COR_PEDRA,
			Enum.Material.Slate
		)
	end

	print("[TheBrokenBox] MapBuilder: Castelo concluido (" .. #parts .. " parts).")
	return parts
end

-- ============================================================
-- Construcao: Caverna
-- ============================================================

local function construirCaverna(parent: Instance): { Part }
	print("[TheBrokenBox] MapBuilder: Construindo Caverna...")

	local s = MapData.STRUCTURES.CAVERN
	local cx = (s.min.x + s.max.x) / 2
	local cz = (s.min.z + s.max.z) / 2
	local parts: { Part } = {}

	-- === Piso rebaixado ===
	-- O piso fica em y negativo (area rebaixada)
	local pisoY = s.min.y  -- -15
	table.insert(parts, criarPiso(
		parent, "Caverna_Piso",
		s.min.x, s.max.x, pisoY,
		s.min.z, s.max.z,
		COR_CINZA_ESCURO,
		Enum.Material.Slate
	))

	-- === Rampas de descida (das bordas para o centro rebaixado) ===
	for lado = -1, 1, 2 do
		-- Rampa no eixo X
		local rampaX = criarPart(
			parent, "Caverna_RampaX_" .. tostring(lado),
			Vector3.new(10, 0.5, s.max.z - s.min.z),
			Vector3.new(cx + lado * 35, pisoY + 5, cz),
			COR_CINZA_ESCURO,
			Enum.Material.Slate
		)
		rampaX.Orientation = Vector3.new(0, 0, -lado * 15)
		table.insert(parts, rampaX)
	end

	-- === Paredes da caverna (formato irregular) ===
	-- Usamos multiplos blocos para simular rochas
	local paredeConfigs = {
		-- Norte
		{ x = s.min.x, z = s.max.z, dx = s.max.x - s.min.x, dz = 6, nome = "Norte" },
		-- Sul
		{ x = s.min.x, z = s.min.z - 4, dx = s.max.x - s.min.x, dz = 4, nome = "Sul" },
		-- Oeste
		{ x = s.min.x - 4, z = s.min.z, dx = 4, dz = s.max.z - s.min.z, nome = "Oeste" },
		-- Leste
		{ x = s.max.x, z = s.min.z, dx = 6, dz = s.max.z - s.min.z, nome = "Leste" },
	}

	for _, cfg in ipairs(paredeConfigs) do
		-- Criar blocos irregulares empilhados
		local largura = cfg.dx
		local profundidade = cfg.dz
		local alturaTotal = s.max.y - s.min.y  -- 20
		local blocosPorColuna = 5

		for i = 1, 3 do  -- 3 segmentos horizontais
			local offsetX = (i - 1.5) * (largura / 2.5) * 0.5
			local offsetZ = (i - 1.5) * (profundidade / 2.5) * 0.5
			local segLargura = largura / 3 * (0.8 + math.random() * 0.4)
			local segProf = profundidade / 3 * (0.8 + math.random() * 0.4)

			for j = 1, blocosPorColuna do
				local yBase = pisoY + (j - 1) * (alturaTotal / blocosPorColuna)
				local segAltura = alturaTotal / blocosPorColuna * (0.9 + math.random() * 0.2)
				local p = criarPart(
					parent, "Caverna_Parede_" .. cfg.nome .. "_" .. tostring(i) .. "_" .. tostring(j),
					Vector3.new(segLargura, segAltura, segProf),
					Vector3.new(
						cfg.x + offsetX + largura / 2 + (i - 1.5) * (largura / 4),
						yBase + segAltura / 2,
						cfg.z + offsetZ + profundidade / 2 + (i - 1.5) * (profundidade / 4)
					),
					COR_CINZA_ESCURO,
					Enum.Material.Slate
				)
				-- Variar levemente a cor para efeito de rocha
				local brilho = 7/10 + math.random() * 0.3
				p.Color = Color3.fromRGB(
					math.floor(60 * brilho),
					math.floor(55 * brilho),
					math.floor(50 * brilho)
				)
				table.insert(parts, p)
			end
		end
	end

	-- === Teto parcial (caverna coberta) ===
	-- Algumas partes do teto para sensacao de confinamento
	for i = 1, 4 do
		local tx = s.min.x + (i - 0.5) * (s.max.x - s.min.x) / 4
		local tz = cz + (i % 2 == 1 and 20 or -20)
		criarPart(
			parent, "Caverna_Teto_" .. tostring(i),
			Vector3.new(15, 2, 40),
			Vector3.new(tx, s.max.y - 1, tz),
			COR_CINZA_ESCURO,
			Enum.Material.Slate
		)
	end

	-- === Iluminacao da Caverna (luzes fracas) ===
	criarPointLight(parent, "Caverna_Luz_Centro", Vector3.new(cx, pisoY + 1, cz), 0.4, 30, COR_LARANJA)
	criarPointLight(parent, "Caverna_Luz_Entrada", Vector3.new(s.min.x + 10, pisoY + 1, s.max.z - 10), 0.3, 25, COR_AZUL_ESCURO)
	criarPointLight(parent, "Caverna_Luz_Fundo", Vector3.new(s.max.x - 10, pisoY + 1, s.min.z + 10), 0.2, 20, COR_VERMELHO_ESCURO)

	-- === Entrada da caverna (arco) ===
	local entradaX = s.min.x + 15
	local entradaZ = s.max.z
	criarPart(
		parent, "Caverna_Entrada_Arco",
		Vector3.new(12, 1.5, 3),
		Vector3.new(entradaX, pisoY + 4, entradaZ),
		COR_PEDRA,
		Enum.Material.Slate
	)
	-- Pilares da entrada
	for lado = -1, 1, 2 do
		criarColuna(
			parent, "Caverna_Entrada_Pilar_" .. tostring(lado),
			entradaX + lado * 5.5, entradaZ, pisoY, 4, 2,
			COR_PEDRA,
			Enum.Material.Slate
		)
	end

	print("[TheBrokenBox] MapBuilder: Caverna concluida (" .. #parts .. " parts).")
	return parts
end

-- ============================================================
-- Construcao: Estoque (labirinto de prateleiras)
-- ============================================================

local function construirEstoque(parent: Instance): { Part }
	print("[TheBrokenBox] MapBuilder: Construindo Estoque...")

	local s = MapData.STRUCTURES.WAREHOUSE
	local baseY = s.min.y  -- 0
	local altura = s.max.y - s.min.y  -- 15
	local parts: { Part } = {}

	-- === Piso ===
	table.insert(parts, criarPiso(
		parent, "Estoque_Piso",
		s.min.x, s.max.x, baseY + 0.5,
		s.min.z, s.max.z,
		COR_MARROM_ESCURO,
		Enum.Material.WoodPlanks
	))

	-- === Paredes externas ===
	local paredes = {
		{ nome = "Norte", minX = s.min.x, maxX = s.max.x, z = s.max.z, dx = s.max.x - s.min.x, dz = 2 },
		{ nome = "Sul",   minX = s.min.x, maxX = s.max.x, z = s.min.z, dx = s.max.x - s.min.x, dz = 2 },
		{ nome = "Oeste", minZ = s.min.z, maxZ = s.max.z, x = s.min.x, dx = 2, dz = s.max.z - s.min.z },
		{ nome = "Leste", minZ = s.min.z, maxZ = s.max.z, x = s.max.x, dx = 2, dz = s.max.z - s.min.z },
	}

	for _, parede in ipairs(paredes) do
		local p = criarParede(
			parent, "Estoque_Parede_" .. parede.nome,
			Vector3.new(parede.minX or parede.x or 0, baseY, parede.minZ or parede.z or 0),
			Vector3.new(parede.maxX or parede.x or 0, baseY, parede.maxZ or parede.z or 0),
			2, altura,
			COR_MARROM_ESCURO,
			Enum.Material.WoodPlanks
		)
		table.insert(parts, p)
	end

	-- === Teto ===
	table.insert(parts, criarPiso(
		parent, "Estoque_Teto",
		s.min.x + 2, s.max.x - 2,
		baseY + altura - 0.5,
		s.min.z + 2, s.max.z - 2,
		COR_CINZA_ESCURO,
		Enum.Material.WoodPlanks
	))

	-- === Prateleiras (labirinto) ===
	-- Prateleiras sao blocos altos formando corredores
	-- Layout: 3 fileiras horizontais (ao longo do eixo Z) com gaps para corredores
	local numFileiras = 3
	local numPrateleirasPorFileira = 4
	local margemX = s.min.x + 10
	local larguraUtil = (s.max.x - s.min.x) - 20
	local espacamentoX = larguraUtil / (numFileiras + 1)

	local prateleiraComprimentoZ = 18
	local prateleiraLarguraX = 2
	local prateleiraAltura = altura - 1  -- quase ate o teto

	for f = 1, numFileiras do
		local prateleiraX = margemX + f * espacamentoX

		for p = 1, numPrateleirasPorFileira do
			-- Alternar posicoes Z com gaps para corredores
			local variacaoZ = (p % 2 == 1) and -8 or 8
			local prateleiraZ = s.min.z + 15 + (p - 1) * ((s.max.z - s.min.z - 30) / numPrateleirasPorFileira) + variacaoZ * 0.3

			local shelf = criarPart(
				parent,
				"Estoque_Prateleira_F" .. tostring(f) .. "_P" .. tostring(p),
				Vector3.new(prateleiraLarguraX, prateleiraAltura, prateleiraComprimentoZ),
				Vector3.new(prateleiraX, baseY + prateleiraAltura / 2, prateleiraZ),
				COR_MARROM_ESCURO,
				Enum.Material.WoodPlanks
			)
			table.insert(parts, shelf)

			-- Prateleiras laterais (como orelhas) para criar corredores mais complexos
			if p % 2 == 0 then
				local lateral = criarPart(
					parent,
					"Estoque_PrateleiraLat_F" .. tostring(f) .. "_P" .. tostring(p),
					Vector3.new(8, prateleiraAltura, 1.5),
					Vector3.new(prateleiraX + 5, baseY + prateleiraAltura / 2, prateleiraZ + prateleiraComprimentoZ / 2 + 2),
					COR_MARROM_ESCURO,
					Enum.Material.WoodPlanks
				)
				table.insert(parts, lateral)
			end
		end
	end

	-- === Decoracao: caixas no Estoque ===
	for i = 1, 10 do
		local cxBox = s.min.x + 5 + math.random() * (s.max.x - s.min.x - 10)
		local czBox = s.min.z + 5 + math.random() * (s.max.z - s.min.z - 10)
		local boxSize = 2 + math.random() * 3
		criarPart(
			parent, "Estoque_Caixa_" .. tostring(i),
			Vector3.new(boxSize, boxSize, boxSize),
			Vector3.new(cxBox, baseY + boxSize / 2, czBox),
			COR_CARDBOARD,
			Enum.Material.Cardboard
		)
	end

	print("[TheBrokenBox] MapBuilder: Estoque concluido (" .. #parts .. " parts).")
	return parts
end

-- ============================================================
-- Construcao: Marcadores de Missao
-- ============================================================

--[[
  Constroi marcador visual V1 - Disjuntor (Breaker).
  Painel cinza metalico com 4 pequenas alavancas.
]]
local function construirMarkerV1(parent: Instance, pos: { x: number, y: number, z: number }, id: string)
	local baseY = pos.y
	local folder = Instance.new("Folder")
	folder.Name = "Mission_" .. id
	folder.Parent = parent

	-- Painel principal
	criarPart(
		folder, "Painel",
		Vector3.new(4, 3, 0.5),
		Vector3.new(pos.x, baseY + 1.5, pos.z),
		COR_CINZA_CLARO,
		Enum.Material.Metal
	)

	-- 4 alavancas (pequenas)
	for i = 1, 4 do
		local leverX = pos.x - 1.5 + (i - 1) * 1
		-- Haste
		criarPart(
			folder, "Alavanca_Haste_" .. tostring(i),
			Vector3.new(0.2, 1.2, 0.2),
			Vector3.new(leverX, baseY + 2, pos.z + 0.4),
			COR_CINZA_ESCURO,
			Enum.Material.Metal
		)
		-- Base da alavanca
		criarPart(
			folder, "Alavanca_Base_" .. tostring(i),
			Vector3.new(0.5, 0.3, 0.5),
			Vector3.new(leverX, baseY + 1.1, pos.z + 0.4),
			COR_VERMELHO_ESCURO,
			Enum.Material.Metal
		)
	end
end

--[[
  Constroi marcador visual V2 - Gerador.
  Caixa laranja/amarela com 5 cilindros de cabo.
]]
local function construirMarkerV2(parent: Instance, pos: { x: number, y: number, z: number }, id: string)
	local baseY = pos.y
	local folder = Instance.new("Folder")
	folder.Name = "Mission_" .. id
	folder.Parent = parent

	-- Corpo do gerador
	criarPart(
		folder, "Corpo",
		Vector3.new(5, 3, 4),
		Vector3.new(pos.x, baseY + 1.5, pos.z),
		COR_LARANJA,
		Enum.Material.Metal
	)

	-- Painel de controle (amarelo)
	criarPart(
		folder, "Painel",
		Vector3.new(3, 2, 0.3),
		Vector3.new(pos.x, baseY + 2, pos.z + 2.2),
		COR_AMARELO,
		Enum.Material.Metal
	)

	-- 5 cabos (cilindros saindo do gerador)
	for i = 1, 5 do
		local caboX = pos.x - 2 + (i - 1) * 1
		local cabo = criarPart(
			folder, "Cabo_" .. tostring(i),
			Vector3.new(0.3, 0.3, 1.5),
			Vector3.new(caboX, baseY + 2.5, pos.z - 2.5),
			COR_PRETO,
			Enum.Material.Metal
		)
		-- Rotacionar para parecer um cabo saindo horizontalmente
		cabo.Orientation = Vector3.new(90, 0, 0)
	end
end

--[[
  Constroi marcador visual V3 - Maquina de Petroleo.
  Maquina vermelha escura/preta com um ponteiro.
]]
local function construirMarkerV3(parent: Instance, pos: { x: number, y: number, z: number }, id: string)
	local baseY = pos.y
	local folder = Instance.new("Folder")
	folder.Name = "Mission_" .. id
	folder.Parent = parent

	-- Base da maquina
	criarPart(
		folder, "Base",
		Vector3.new(6, 1, 6),
		Vector3.new(pos.x, baseY + 0.5, pos.z),
		COR_PRETO,
		Enum.Material.Metal
	)

	-- Corpo principal
	criarPart(
		folder, "Corpo",
		Vector3.new(4, 4, 4),
		Vector3.new(pos.x, baseY + 3, pos.z),
		COR_VERMELHO_ESCURO,
		Enum.Material.Metal
	)

	-- Tanque de oleo (cilindro deitado)
	local tanque = criarPart(
		folder, "Tanque",
		Vector3.new(5, 2, 2),
		Vector3.new(pos.x - 3, baseY + 1, pos.z),
		COR_CINZA_ESCURO,
		Enum.Material.Metal
	)

	-- Ponteiro (haste fina vertical)
	local ponteiro = criarPart(
		folder, "Ponteiro",
		Vector3.new(0.2, 5, 0.2),
		Vector3.new(pos.x, baseY + 5.5, pos.z),
		COR_AMARELO,
		Enum.Material.Metal
	)
end

--[[
  Constroi todos os 14 marcadores de missao.
]]
local function construirMissionMarkers(parent: Instance): ()
	print("[TheBrokenBox] MapBuilder: Construindo " .. #MapData.MISSION_CANDIDATES .. " marcadores de missao...")

	for _, candidate in ipairs(MapData.MISSION_CANDIDATES) do
		if candidate.type == "V1" then
			construirMarkerV1(parent, candidate.position, candidate.id)
		elseif candidate.type == "V2" then
			construirMarkerV2(parent, candidate.position, candidate.id)
		elseif candidate.type == "V3" then
			construirMarkerV3(parent, candidate.position, candidate.id)
		end
	end

	print("[TheBrokenBox] MapBuilder: Marcadores de missao concluidos.")
end

-- ============================================================
-- Construcao: Portoes (arcos)
-- ============================================================

local function construirGates(parent: Instance): ()
	print("[TheBrokenBox] MapBuilder: Construindo " .. #MapData.GATES .. " portoes...")

	for _, gate in ipairs(MapData.GATES) do
		local gx = gate.position.x
		local gy = gate.position.y
		local gz = gate.position.z
		local folder = Instance.new("Folder")
		folder.Name = "Gate_" .. gate.id
		folder.Parent = parent

		-- Arco superior (semi-circulo simulado com 3 partes)
		criarPart(
			folder, "Arco_Topo",
			Vector3.new(10, 1.5, 2),
			Vector3.new(gx, gy + 6, gz),
			COR_PEDRA,
			Enum.Material.Slate
		)

		-- Lados inclinados do arco
		for lado = -1, 1, 2 do
			local ladoInclinado = criarPart(
				folder, "Arco_Lado_" .. tostring(lado),
				Vector3.new(2, 4, 2),
				Vector3.new(gx + lado * 4, gy + 3.5, gz),
				COR_PEDRA,
				Enum.Material.Slate
			)
			ladoInclinado.Orientation = Vector3.new(0, 0, -lado * 20)
		end

		-- Pilares
		for lado = -1, 1, 2 do
			criarColuna(
				folder, "Pilar_" .. tostring(lado),
				gx + lado * 5.5, gz, gy - 2, 7, 2.5,
				COR_PEDRA,
				Enum.Material.Slate
			)
		end

		-- Base/piso do portao
		criarPart(
			folder, "Base",
			Vector3.new(12, 0.5, 4),
			Vector3.new(gx, gy - 0.5, gz),
			COR_CINZA_ESCURO,
			Enum.Material.Slate
		)

		-- Sinalizador (luz no topo do arco)
		criarPointLight(
			folder, "Sinalizador",
			Vector3.new(gx, gy + 7, gz),
			0.5, 15,
			COR_AMARELO
		)
	end

	print("[TheBrokenBox] MapBuilder: Portoes concluidos.")
end

-- ============================================================
-- Construcao: Obstaculos (caixas de papelao)
-- ============================================================

local function construirObstaculos(parent: Instance): ()
	print("[TheBrokenBox] MapBuilder: Construindo " .. #MapData.OBSTACLES .. " obstaculos...")

	for i, obs in ipairs(MapData.OBSTACLES) do
		local pos = obs.position
		local tam = obs.size
		criarPart(
			parent, "Obstaculo_" .. tostring(i),
			Vector3.new(tam.x, tam.y, tam.z),
			Vector3.new(pos.x, pos.y, pos.z),
			COR_CARDBOARD,
			Enum.Material.Cardboard
		)

		-- Detalhes decorativos em cima (fita adesiva simulada)
		criarPart(
			parent, "Obstaculo_Fita_" .. tostring(i),
			Vector3.new(tam.x + 0.5, 0.1, 0.5),
			Vector3.new(pos.x, pos.y + tam.y / 2 + 0.05, pos.z),
			COR_MARROM_ESCURO,
			Enum.Material.SmoothPlastic
		)
	end

	print("[TheBrokenBox] MapBuilder: Obstaculos concluidos.")
end

-- ============================================================
-- Construcao: Decoracao de horror
-- ============================================================

--[[
  Cria um corpo de brinquedo deitado (R6 dummy simulado).
]]
local function criarCorpoBrinquedo(
	parent: Instance,
	nome: string,
	posicao: Vector3,
	corRoupa: Color3?
): ()
	local folder = Instance.new("Folder")
	folder.Name = nome
	folder.Parent = parent

	local baseY = posicao.Y

	-- Tronco (deitado - rotacionado 90 graus no Z)
	local tronco = criarPart(
		folder, "Tronco",
		Vector3.new(2, 3, 1.5),
		Vector3.new(posicao.X, baseY + 0.5, posicao.Z),
		corRoupa or COR_AZUL_ESCURO,
		Enum.Material.SmoothPlastic
	)
	tronco.Orientation = Vector3.new(0, 0, 90)

	-- Cabeca
	criarPart(
		folder, "Cabeca",
		Vector3.new(1.5, 1.5, 1.5),
		Vector3.new(posicao.X + 2.5, baseY + 0.3, posicao.Z),
		COR_BRANCO_SUJO,
		Enum.Material.SmoothPlastic
	)

	-- Bracos (2)
	for lado = -1, 1, 2 do
		criarPart(
			folder, "Braco_" .. tostring(lado),
			Vector3.new(1, 0.5, 0.5),
			Vector3.new(posicao.X + lado * 0.8, baseY + 0.3, posicao.Z + 1.2 * lado),
			corRoupa or COR_AZUL_ESCURO,
			Enum.Material.SmoothPlastic
		)
	end

	-- Pernas (2)
	for lado = -1, 1, 2 do
		criarPart(
			folder, "Perna_" .. tostring(lado),
			Vector3.new(1, 0.6, 0.6),
			Vector3.new(posicao.X - 1.5 + lado * 0.5, baseY + 0.3, posicao.Z + 0.8 * lado),
			COR_CINZA_ESCURO,
			Enum.Material.SmoothPlastic
		)
	end

	-- "Sangue" (mancha vermelha no chao)
	local mancha = criarPart(
		folder, "Mancha",
		Vector3.new(3, 0.05, 2),
		Vector3.new(posicao.X, baseY - 0.5, posicao.Z),
		COR_VERMELHO_ESCURO,
		Enum.Material.SmoothPlastic
	)
	mancha.Transparency = 0.3
end

local function construirDecoracaoHorror(parent: Instance): ()
	print("[TheBrokenBox] MapBuilder: Construindo decoracao de horror...")

	-- Corpos na Caverna
	local cavern = MapData.STRUCTURES.CAVERN
	local cxCavern = (cavern.min.x + cavern.max.x) / 2
	local czCavern = (cavern.min.z + cavern.max.z) / 2
	local yCavern = cavern.min.y + 0.5

	criarCorpoBrinquedo(parent, "Corpo_Caverna_1", Vector3.new(cxCavern - 15, yCavern, czCavern - 15), COR_VERMELHO_ESCURO)
	criarCorpoBrinquedo(parent, "Corpo_Caverna_2", Vector3.new(cxCavern + 10, yCavern, czCavern + 20), COR_AZUL_ESCURO)
	criarCorpoBrinquedo(parent, "Corpo_Caverna_3", Vector3.new(cxCavern + 20, yCavern, czCavern - 10), nil)

	-- Corpos no Castelo
	local castle = MapData.STRUCTURES.CASTLE
	local cxCastle = (castle.min.x + castle.max.x) / 2
	local czCastle = (castle.min.z + castle.max.z) / 2
	local yCastle = castle.min.y + 1

	criarCorpoBrinquedo(parent, "Corpo_Castelo_1", Vector3.new(cxCastle - 10, yCastle, czCastle + 10), COR_BRANCO_SUJO)
	criarCorpoBrinquedo(parent, "Corpo_Castelo_2", Vector3.new(cxCastle + 15, yCastle + 18, czCastle), nil)

	-- "Olhos" brilhantes nos cantos escuros (pequenas PointLights vermelhas)
	criarPointLight(parent, "Olho_Caverna_1", Vector3.new(cxCavern + 25, yCavern + 1, czCavern - 20), 0.3, 8, COR_VERMELHO_ESCURO)
	criarPointLight(parent, "Olho_Caverna_2", Vector3.new(cxCavern - 20, yCavern + 1, czCavern + 25), 0.3, 8, COR_VERMELHO_ESCURO)
	criarPointLight(parent, "Olho_Castelo_1", Vector3.new(cxCastle + 5, yCastle + 35, czCastle + 5), 0.2, 10, COR_VERMELHO_ESCURO)

	print("[TheBrokenBox] MapBuilder: Decoracao de horror concluida.")
end

-- ============================================================
-- Build principal
-- ============================================================

--[[
  Constroi o mapa inteiro. Idempotente: so executa uma vez.
]]
local function construirMapa(): ()
	if _mapBuilt then
		warn("[TheBrokenBox] MapBuilder: Mapa ja foi construido. Ignorando segunda chamada.")
		return
	end

	print("[TheBrokenBox] ========================================")
	print("[TheBrokenBox] MapBuilder: Iniciando construcao do mapa...")
	print("[TheBrokenBox] ========================================")

	-- Remover mapa anterior (se existir, util para reinicios)
	local mapaAntigo = Workspace:FindFirstChild("CriatividadeMorta")
	if mapaAntigo then
		mapaAntigo:Destroy()
	end

	-- Criar pasta raiz do mapa
	local raiz = Instance.new("Folder")
	raiz.Name = "CriatividadeMorta"
	raiz.Parent = Workspace

	-- Sub-pastas organizacionais
	local estruturasFolder = Instance.new("Folder")
	estruturasFolder.Name = "Estruturas"
	estruturasFolder.Parent = raiz

	local missoesFolder = Instance.new("Folder")
	missoesFolder.Name = "Missoes"
	missoesFolder.Parent = raiz

	local portoesFolder = Instance.new("Folder")
	portoesFolder.Name = "Portoes"
	portoesFolder.Parent = raiz

	local obstaculosFolder = Instance.new("Folder")
	obstaculosFolder.Name = "Obstaculos"
	obstaculosFolder.Parent = raiz

	local decoracaoFolder = Instance.new("Folder")
	decoracaoFolder.Name = "Decoracao"
	decoracaoFolder.Parent = raiz

	-- Construir cada componente
	construirChao(raiz)
	construirCastelo(estruturasFolder)
	construirCaverna(estruturasFolder)
	construirEstoque(estruturasFolder)
	construirMissionMarkers(missoesFolder)
	construirGates(portoesFolder)
	construirObstaculos(obstaculosFolder)
	construirDecoracaoHorror(decoracaoFolder)

	_mapBuilt = true

	print("[TheBrokenBox] MapBuilder: Mapa construido com sucesso!")
	print("[TheBrokenBox] ========================================")
end

-- ============================================================
-- Init / Start
-- ============================================================

--[[
  Init(): setup sincrono.
  Constroi o mapa imediatamente (antes de jogadores entrarem).
]]
function MapBuilder.Init(): ()
	print("[TheBrokenBox] MapBuilder.Init()")
	construirMapa()
end

--[[
  Start(): chamado apos wiring.
  Nada a fazer - mapa ja foi construido no Init.
]]
function MapBuilder.Start(): ()
	print("[TheBrokenBox] MapBuilder.Start() - mapa ja construido.")
end

return MapBuilder
