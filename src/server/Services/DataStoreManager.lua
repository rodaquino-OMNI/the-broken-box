--!strict
--[[
  DataStoreManager.lua
  Gerencia persistencia de dados dos jogadores via DataStoreService.
  Com fallback para modo mock (in-memory) quando DataStoreService
  nao esta disponivel (ex.: Studio offline).

  Player data structure:
    {
      coins = number,
      unlockedCharacters = {string},
      stats = { matchesPlayed, wins, escapes, missions }
    }

  Sinais:
    dataLoaded - (player: Player, data: {})
    dataSaved  - (player: Player)

  Init/Start pattern.
  Retry com exponential backoff (max 3 tentativas).

  Referencias: GDD Progressao de Jogador, architecture.md
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService: DataStoreService

local Signal = require(ReplicatedStorage.Util.Signal)

-- ============================================================
-- Tentar obter DataStoreService (pode falhar no Studio)
-- ============================================================
local _isMockMode = false
local _dataStore: DataStore
local _mockData = {}  -- In-memory para dev

local _dsSuccess, _dsErr = pcall(function()
	DataStoreService = game:GetService("DataStoreService")
end)

if not DataStoreService then
	_isMockMode = true
	warn("[TheBrokenBox] DataStoreManager: DataStoreService indisponivel. Usando modo mock (in-memory).")
end

-- ============================================================
-- DataStoreManager
-- ============================================================
local DataStoreManager = {}
DataStoreManager.Name = "DataStoreManager"

-- Sinais
DataStoreManager.dataLoaded = Signal.new()  -- (player: Player, data: {})
DataStoreManager.dataSaved = Signal.new()   -- (player: Player)

-- ============================================================
-- Configuracao de retry
-- ============================================================
local MAX_RETRIES = 3
local BASE_DELAY = 2  -- segundos, dobra a cada tentativa

-- ============================================================
-- Dados padrao para novo jogador
-- ============================================================
local function getDefaultData(): {}
	return {
		coins = 0,
		unlockedCharacters = {},  -- Personagens desbloqueados
		stats = {
			matchesPlayed = 0,
			wins = 0,
			escapes = 0,
			missions = 0,
		},
	}
end

-- ============================================================
-- Player data cache (ativo durante a sessao)
-- ============================================================
local _playerData = {}  -- Cache em runtime

-- ============================================================
-- API: Obter/atualizar dados de um jogador
-- ============================================================

--[[
  Retorna os dados em cache de um jogador.
  Se nao carregado ainda, retorna dados padrao temporarios.
]]
function DataStoreManager.getPlayerData(player: Player): {}
	return _playerData[player] or getDefaultData()
end

--[[
  Salva os dados de um jogador no DataStore (com retry).
]]
function DataStoreManager.savePlayerData(player: Player): boolean
	local data = _playerData[player]
	if not data then
		warn("[TheBrokenBox] DataStoreManager: Tentativa de salvar dados nao carregados para " .. player.Name)
		return false
	end

	if _isMockMode then
		_mockData[player.UserId] = data
		print("[TheBrokenBox] DataStoreManager: [MOCK] Dados salvos para " .. player.Name .. " (coins: " .. data.coins .. ")")
		DataStoreManager.dataSaved:Fire(player)
		return true
	end

	-- Modo real: salvar com retry
	local key = "Player_" .. tostring(player.UserId)
	local attempt = 0
	local success = false

	while attempt < MAX_RETRIES do
		attempt = attempt + 1
		local saveSuccess, saveErr = pcall(function()
			_dataStore:SetAsync(key, data)
		end)

		if saveSuccess then
			success = true
			print("[TheBrokenBox] DataStoreManager: Dados salvos para " .. player.Name .. " (coins: " .. data.coins .. ", tentativa " .. attempt .. ")")
			DataStoreManager.dataSaved:Fire(player)
			break
		else
			warn("[TheBrokenBox] DataStoreManager: ERRO ao salvar " .. player.Name .. " (tentativa " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(saveErr))
			if attempt < MAX_RETRIES then
				local delay = BASE_DELAY * math.pow(2, attempt - 1)
				task.wait(delay)
			end
		end
	end

	if not success then
		warn("[TheBrokenBox] DataStoreManager: FALHA ao salvar dados de " .. player.Name .. " apos " .. MAX_RETRIES .. " tentativas.")
	end

	return success
end

--[[
  Atualiza os dados de um jogador em cache (nao persiste).
  Chamar savePlayerData() apos para persistir.
]]
function DataStoreManager.updatePlayerData(player: Player, updates: {}): {}
	local data = DataStoreManager.getPlayerData(player)
	for key, value in pairs(updates) do
		data[key] = value
	end
	_playerData[player] = data
	return data
end

--[[
  Adiciona moedas ao jogador (atualiza cache apenas).
  Retorna o novo total.
]]
function DataStoreManager.addCoins(player: Player, amount: number): number
	local data = DataStoreManager.getPlayerData(player)
	data.coins = (data.coins or 0) + amount
	_playerData[player] = data
	return data.coins
end

--[[
  Gasta moedas do jogador (atualiza cache apenas).
  Retorna false se saldo insuficiente.
]]
function DataStoreManager.spendCoins(player: Player, amount: number): boolean
	local data = DataStoreManager.getPlayerData(player)
	if (data.coins or 0) < amount then
		return false
	end
	data.coins = data.coins - amount
	_playerData[player] = data
	return true
end

--[[
  Verifica se um personagem esta desbloqueado.
]]
function DataStoreManager.isCharacterUnlocked(player: Player, characterClass: string): boolean
	local data = DataStoreManager.getPlayerData(player)
	if not data.unlockedCharacters then
		return false
	end
	for _, name in ipairs(data.unlockedCharacters) do
		if name == characterClass then
			return true
		end
	end
	return false
end

--[[
  Desbloqueia um personagem para o jogador (atualiza cache apenas).
  Retorna false se ja desbloqueado.
]]
function DataStoreManager.unlockCharacter(player: Player, characterClass: string): boolean
	if DataStoreManager.isCharacterUnlocked(player, characterClass) then
		return false  -- Ja desbloqueado
	end
	local data = DataStoreManager.getPlayerData(player)
	if not data.unlockedCharacters then
		data.unlockedCharacters = {}
	end
	table.insert(data.unlockedCharacters, characterClass)
	_playerData[player] = data
	return true
end

-- ============================================================
-- Carregamento de dados (PlayerAdded)
-- ============================================================

--[[
  Carrega os dados de um jogador do DataStore (com retry).
  Chamado automaticamente no PlayerAdded.
]]
function DataStoreManager._loadPlayerData(player: Player): {}
	if _isMockMode then
		-- Modo mock: usar dados salvos em memoria ou criar novos
		local existing = _mockData[player.UserId]
		if existing then
			_playerData[player] = existing
			print("[TheBrokenBox] DataStoreManager: [MOCK] Dados carregados para " .. player.Name .. " (coins: " .. existing.coins .. ")")
		else
			_playerData[player] = getDefaultData()
			print("[TheBrokenBox] DataStoreManager: [MOCK] Novos dados para " .. player.Name)
		end
		DataStoreManager.dataLoaded:Fire(player, _playerData[player])
		return _playerData[player]
	end

	-- Modo real: carregar do DataStore com retry
	local key = "Player_" .. tostring(player.UserId)
	local attempt = 0
	local loadedData: {}? = nil

	while attempt < MAX_RETRIES do
		attempt = attempt + 1
		local loadSuccess, data = pcall(function()
			return _dataStore:GetAsync(key)
		end)

		if loadSuccess then
			if data and type(data) == "table" then
				-- Garantir que todos os campos padrao existam
				local defaults = getDefaultData()
				for key, value in pairs(defaults) do
					if data[key] == nil then
						data[key] = value
					end
				end
				loadedData = data
				print("[TheBrokenBox] DataStoreManager: Dados carregados para " .. player.Name .. " (coins: " .. data.coins .. ")")
			else
				loadedData = getDefaultData()
				print("[TheBrokenBox] DataStoreManager: Novos dados para " .. player.Name .. " (primeiro acesso)")
			end
			break
		else
			warn("[TheBrokenBox] DataStoreManager: ERRO ao carregar " .. player.Name .. " (tentativa " .. attempt .. "/" .. MAX_RETRIES .. "): " .. tostring(data))
			if attempt < MAX_RETRIES then
				local delay = BASE_DELAY * math.pow(2, attempt - 1)
				task.wait(delay)
			end
		end
	end

	if not loadedData then
		warn("[TheBrokenBox] DataStoreManager: FALHA ao carregar dados de " .. player.Name .. ". Usando dados padrao.")
		loadedData = getDefaultData()
	end

	_playerData[player] = loadedData
	DataStoreManager.dataLoaded:Fire(player, loadedData)
	return loadedData
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono. Abre o DataStore.
]]
function DataStoreManager.Init(): ()
	print("[TheBrokenBox] DataStoreManager.Init() - modo: " .. (_isMockMode and "MOCK" or "REAL"))

	if not _isMockMode and DataStoreService then
		local openSuccess, storeOrErr = pcall(function()
			return DataStoreService:GetDataStore("TheBrokenBox_PlayerData")
		end)
		if openSuccess then
			_dataStore = storeOrErr
			print("[TheBrokenBox] DataStoreManager: DataStore 'TheBrokenBox_PlayerData' aberto.")
		else
			warn("[TheBrokenBox] DataStoreManager: ERRO ao abrir DataStore: " .. tostring(storeOrErr) .. ". Mudando para modo mock.")
			_isMockMode = true
		end
	end
end

--[[
  Start(): registra listeners de PlayerAdded / PlayerRemoving.
]]
function DataStoreManager.Start(): ()
	print("[TheBrokenBox] DataStoreManager.Start() - registrando listeners de persistencia...")

	-- Carregar dados quando um jogador entra
	local connAdded = Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			DataStoreManager._loadPlayerData(player)
		end)
	end)

	-- Salvar dados quando um jogador sai
	local connRemoving = Players.PlayerRemoving:Connect(function(player: Player)
		task.spawn(function()
			if _playerData[player] then
				DataStoreManager.savePlayerData(player)
				_playerData[player] = nil  -- Limpar cache
			end
		end)
	end)
end

return DataStoreManager
