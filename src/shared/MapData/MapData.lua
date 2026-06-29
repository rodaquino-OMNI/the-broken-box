--!strict
--[[
  MapData.lua
  Dados estaticos do mapa Criatividade Morta (shared).
  Contem TODAS as coordenadas: spawns, missoes candidatas,
  portoes, estruturas e obstaculos.

  Todas as coordenadas em studs, como tabelas {x, y, z}.
  Referenciado por MapService (server) e futuramente por
  modulos de cliente que precisem de dados do mapa.

  Referencias: GDD Design do Mapa - Criatividade Morta,
               architecture.md 32/10 (MapData)
]]

local MapData = {}

-- ============================================================
-- SPAWNS
-- ============================================================

-- Spawn fixo do Cacador (centro do mapa, area elevada)
MapData.HUNTER_SPAWN = { x = 0, y = 3, z = 0 }

-- Spawns dos Sobreviventes (8 posicoes, 4 ativos por partida)
MapData.SURVIVOR_SPAWNS = {
	{ x = -80, y = 3, z = 60 },   -- Proximo ao Castelo (externo)
	{ x = -100, y = 3, z = -40 },  -- Proximo a Caverna (externo)
	{ x = 40, y = 3, z = -90 },    -- Proximo ao Estoque (externo)
	{ x = 90, y = 3, z = 20 },     -- Campo aberto leste
	{ x = -30, y = 3, z = 100 },   -- Campo aberto norte
	{ x = -120, y = 3, z = 80 },   -- Canto noroeste
	{ x = 80, y = 3, z = -30 },    -- Canto sudeste
	{ x = 10, y = 3, z = -120 },   -- Sul distante
}

-- ============================================================
-- PORTOES DE FUGA (3 fixos)
-- ============================================================

MapData.GATES = {
	{
		id = "P1",
		name = "Portao da Caverna",
		position = { x = -100, y = -5, z = -60 },
		-- Entrada da Caverna (area rebaixada)
	},
	{
		id = "P2",
		name = "Portao do Castelo",
		position = { x = -60, y = 15, z = 80 },
		-- Interior do Castelo + subida ao topo
	},
	{
		id = "P3",
		name = "Portao do Estoque",
		position = { x = 60, y = 3, z = -80 },
		-- Centro do Estoque (labirinto)
	},
}

-- ============================================================
-- ESTRUTURAS PRINCIPAIS (bounding boxes para checks de area)
-- ============================================================

-- Castelo: estrutura alta, loopavel, escalavel
-- Funcao de perseguicao: LOOPAR
MapData.STRUCTURES = {
	CASTLE = {
		name = "Castelo",
		function = "Loopar",
		min = { x = -100, y = 0, z = 50 },
		max = { x = -30, y = 40, z = 120 },
		-- Centro aproximado: (-65, 20, 85)
	},
	CAVERN = {
		name = "Caverna",
		function = "Esconder",
		min = { x = -140, y = -15, z = -90 },
		max = { x = -60, y = 5, z = -10 },
		-- Area rebaixada, mais escura
		-- Centro aproximado: (-100, -5, -50)
	},
	WAREHOUSE = {
		name = "Estoque",
		function = "Despistar",
		min = { x = 20, y = 0, z = -130 },
		max = { x = 100, y = 15, z = -30 },
		-- Labirinto de corredores/prateleiras
		-- Centro aproximado: (60, 7, -80)
	},
}

-- ============================================================
-- LOCAIS CANDIDATOS DE MISSAO (~14, 10 ativos por partida)
-- ============================================================
-- Tipos: V1 (Disjuntor - escuridao), V2 (Gerador - barreira),
--        V3 (Petroleo - poco de oleo)
-- Distribuicao segue GDD: V1 na Caverna/aproximacoes,
--   V2 nos gargalos do Estoque e entradas do Castelo,
--   V3 no campo aberto e rampas largas.

MapData.MISSION_CANDIDATES = {
	-- === CAVERNA E APROXIMACOES (V1 - Disjuntor) ===
	{
		id = "MC_01",
		position = { x = -110, y = -8, z = -50 },
		type = "V1",  -- Disjuntor (escuridao)
		structure = "Caverna",
		description = "Fundo da Caverna - area escura",
	},
	{
		id = "MC_02",
		position = { x = -90, y = -3, z = -70 },
		type = "V1",
		structure = "Caverna",
		description = "Corredor lateral da Caverna",
	},
	{
		id = "MC_03",
		position = { x = -70, y = 2, z = -40 },
		type = "V1",
		structure = "Caverna",
		description = "Entrada/saida da Caverna",
	},

	-- === CASTELO E APROXIMACOES (V2 - Gerador) ===
	{
		id = "MC_04",
		position = { x = -80, y = 5, z = 70 },
		type = "V2",  -- Gerador (barreira eletrica)
		structure = "Castelo",
		description = "Entrada do Castelo (portao principal)",
	},
	{
		id = "MC_05",
		position = { x = -50, y = 10, z = 90 },
		type = "V2",
		structure = "Castelo",
		description = "Salao principal do Castelo",
	},
	{
		id = "MC_06",
		position = { x = -70, y = 25, z = 100 },
		type = "V2",
		structure = "Castelo",
		description = "Torre superior do Castelo",
	},
	{
		id = "MC_07",
		position = { x = -40, y = 3, z = 60 },
		type = "V2",
		structure = "Castelo",
		description = "Muralha externa do Castelo",
	},

	-- === ESTOQUE (V2 - Gerador, gargalos) ===
	{
		id = "MC_08",
		position = { x = 40, y = 3, z = -100 },
		type = "V2",
		structure = "Estoque",
		description = "Corredor estreito do Estoque",
	},
	{
		id = "MC_09",
		position = { x = 80, y = 3, z = -60 },
		type = "V2",
		structure = "Estoque",
		description = "Prateleiras centrais do Estoque",
	},

	-- === CAMPO ABERTO (V3 - Petroleo) ===
	{
		id = "MC_10",
		position = { x = 20, y = 3, z = 0 },
		type = "V3",  -- Maquina de Petroleo (poca lenta)
		structure = "Campo",
		description = "Campo central - entre as tres estruturas",
	},
	{
		id = "MC_11",
		position = { x = -10, y = 3, z = 40 },
		type = "V3",
		structure = "Campo",
		description = "Campo norte - area aberta",
	},
	{
		id = "MC_12",
		position = { x = 50, y = 3, z = -10 },
		type = "V3",
		structure = "Campo",
		description = "Campo leste - rampa larga",
	},
	{
		id = "MC_13",
		position = { x = -30, y = 3, z = -110 },
		type = "V3",
		structure = "Campo",
		description = "Campo sul - entre Caverna e Estoque",
	},
	{
		id = "MC_14",
		position = { x = 0, y = 3, z = -50 },
		type = "V3",
		structure = "Campo",
		description = "Campo oeste - area de transicao",
	},
}

-- ============================================================
-- OBSTACULOS (posicoes de cobertura pelo mapa)
-- ============================================================

MapData.OBSTACLES = {
	-- Cobertura no campo aberto (pecas derrubadas, brinquedos)
	{ position = { x = 30, y = 2, z = 30 }, size = { x = 6, y = 4, z = 6 } },
	{ position = { x = -30, y = 2, z = -30 }, size = { x = 5, y = 3, z = 5 } },
	{ position = { x = 60, y = 2, z = 40 }, size = { x = 8, y = 3, z = 4 } },
	{ position = { x = -60, y = 2, z = -20 }, size = { x = 4, y = 5, z = 8 } },
	{ position = { x = 10, y = 2, z = 70 }, size = { x = 6, y = 4, z = 6 } },
	{ position = { x = -40, y = 2, z = -80 }, size = { x = 7, y = 3, z = 5 } },
	{ position = { x = 80, y = 2, z = -90 }, size = { x = 5, y = 4, z = 7 } },
	{ position = { x = -90, y = 2, z = 30 }, size = { x = 6, y = 3, z = 6 } },
}

-- ============================================================
-- UTILITARIOS
-- ============================================================

--[[
  Converte uma tabela {x, y, z} para Vector3.
  Util para servicos que precisam de Vector3 nativo do Roblox.
]]
function MapData.toVector3(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

--[[
  Retorna todos os candidatos de um tipo especifico.
]]
function MapData.getCandidatesByType(missionType: string)
	local result = {}
	for _, candidate in ipairs(MapData.MISSION_CANDIDATES) do
		if candidate.type == missionType then
			table.insert(result, candidate)
		end
	end
	return result
end

--[[
  Verifica se uma posicao (Vector3) esta dentro de uma estrutura.
  Retorna o nome da estrutura ou nil.
]]
function MapData.getStructureAtPosition(pos: Vector3): string?
	-- Verificar Castelo
	local castle = MapData.STRUCTURES.CASTLE
	if pos.X >= castle.min.x and pos.X <= castle.max.x
		and pos.Y >= castle.min.y and pos.Y <= castle.max.y
		and pos.Z >= castle.min.z and pos.Z <= castle.max.z then
		return "Castelo"
	end

	-- Verificar Caverna
	local cavern = MapData.STRUCTURES.CAVERN
	if pos.X >= cavern.min.x and pos.X <= cavern.max.x
		and pos.Y >= cavern.min.y and pos.Y <= cavern.max.y
		and pos.Z >= cavern.min.z and pos.Z <= cavern.max.z then
		return "Caverna"
	end

	-- Verificar Estoque
	local warehouse = MapData.STRUCTURES.WAREHOUSE
	if pos.X >= warehouse.min.x and pos.X <= warehouse.max.x
		and pos.Y >= warehouse.min.y and pos.Y <= warehouse.max.y
		and pos.Z >= warehouse.min.z and pos.Z <= warehouse.max.z then
		return "Estoque"
	end

	return nil
end

return MapData
