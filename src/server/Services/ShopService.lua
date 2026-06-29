--!strict
--[[
  ShopService.lua
  Servico de dominio que gerencia a economia de moedas,
  desbloqueio de personagens e a loja "A Caixa".

  Sinais expostos:
    coinsUpdated      - (player: Player, newTotal: number)
    characterUnlocked - (player: Player, characterClass: string)

  Ganhos de moedas:
    - missionCompleted: +15 (COIN_MISSAO)
    - playerEscaped:    +40 (COIN_FUGA)

  Personagens gratuitos: Distorcido, Sackboy, Medico
  Personagens pagos: Soldado, Robo

  Init/Start pattern.
  Referencias: GDD Progressao de Jogador, architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local Signal = require(ReplicatedStorage.Util.Signal)

local ShopService = {}
ShopService.Name = "ShopService"

-- ============================================================
-- Sinais do servico
-- ============================================================
ShopService.coinsUpdated = Signal.new()      -- (player: Player, newTotal: number)
ShopService.characterUnlocked = Signal.new() -- (player: Player, characterClass: string)

-- ============================================================
-- Estado interno
-- ============================================================
local _dataStoreManager: any = nil  -- Injetado via Init

-- Personagens gratuitos (sempre disponiveis)
local FREE_CHARACTERS = {
	["Distorcido"] = true,
	["Sackboy"] = true,
	["Medico"] = true,
}

-- Precos de desbloqueio (do GameConstants)
local UNLOCK_PRICES: { [string]: number } = {
	["Soldado"] = GameConstants.Economy.UNLOCK_COST_SOLDADO,  -- 150
	["Robo"] = GameConstants.Economy.UNLOCK_COST_ROBO,         -- 200
}

-- Conexoes
local _connections = {}

-- ============================================================
-- API: Precos e verificacao
-- ============================================================

--[[
  Retorna o preco de desbloqueio de um personagem.
  Retorna 0 para gratuitos, nil para inexistente.
]]
function ShopService.getUnlockPrice(characterClass: string): number
	if FREE_CHARACTERS[characterClass] then
		return 0
	end
	return UNLOCK_PRICES[characterClass]
end

--[[
  Verifica se um personagem e gratuito.
]]
function ShopService.isCharacterFree(characterClass: string): boolean
	return FREE_CHARACTERS[characterClass] == true
end

--[[
  Retorna o saldo de moedas de um jogador.
]]
function ShopService.getCoins(player: Player): number
	if not _dataStoreManager then
		warn("[TheBrokenBox] ShopService: DataStoreManager nao injetado!")
		return 0
	end
	local data = _dataStoreManager.getPlayerData(player)
	return data.coins or 0
end

--[[
  Verifica se um jogador pode comprar um personagem.
]]
function ShopService.canAfford(player: Player, characterClass: string): boolean
	local price = ShopService.getUnlockPrice(characterClass)
	if price == nil then
		return false  -- Personagem inexistente
	end
	if price == 0 then
		return true   -- Gratuito, sempre "pode comprar"
	end
	return ShopService.getCoins(player) >= price
end

--[[
  Verifica se um personagem esta disponivel para o jogador
  (gratuito OU ja desbloqueado).
]]
function ShopService.isCharacterAvailable(player: Player, characterClass: string): boolean
	if ShopService.isCharacterFree(characterClass) then
		return true
	end
	if not _dataStoreManager then
		return false
	end
	return _dataStoreManager.isCharacterUnlocked(player, characterClass)
end

-- ============================================================
-- API: Ganho e gasto de moedas
-- ============================================================

--[[
  Adiciona moedas a um jogador e persiste.
  Usado pelos sinais missionCompleted (+15) e playerEscaped (+40).
]]
function ShopService.addCoins(player: Player, amount: number): number
	if not _dataStoreManager then
		warn("[TheBrokenBox] ShopService: DataStoreManager nao injetado - moedas nao adicionadas.")
		return 0
	end

	local newTotal = _dataStoreManager.addCoins(player, amount)
	_dataStoreManager.savePlayerData(player)

	print("[TheBrokenBox] ShopService: +" .. amount .. " moedas para " .. player.Name .. " (total: " .. newTotal .. ")")
	ShopService.coinsUpdated:Fire(player, newTotal)

	return newTotal
end

--[[
  Compra/desbloqueia um personagem para o jogador.
  Retorna: true se sucesso, false se falhou (ja desbloqueado, sem moedas, etc.).
]]
function ShopService.buyCharacter(player: Player, characterClass: string): boolean
	if not _dataStoreManager then
		warn("[TheBrokenBox] ShopService: DataStoreManager nao injetado.")
		return false
	end

	-- Verificar se e gratuito
	if ShopService.isCharacterFree(characterClass) then
		warn("[TheBrokenBox] ShopService: " .. characterClass .. " ja e gratuito!")
		return false
	end

	-- Verificar se ja foi desbloqueado
	if _dataStoreManager.isCharacterUnlocked(player, characterClass) then
		warn("[TheBrokenBox] ShopService: " .. player.Name .. " ja possui " .. characterClass)
		return false
	end

	-- Verificar preco
	local price = ShopService.getUnlockPrice(characterClass)
	if price == nil then
		warn("[TheBrokenBox] ShopService: Personagem inexistente: " .. characterClass)
		return false
	end

	-- Verificar saldo
	if not ShopService.canAfford(player, characterClass) then
		warn("[TheBrokenBox] ShopService: " .. player.Name .. " nao tem moedas para " .. characterClass .. " (precisa: " .. price .. ", tem: " .. ShopService.getCoins(player) .. ")")
		return false
	end

	-- Gastar moedas (se nao for gratuito)
	if price > 0 then
		local spent = _dataStoreManager.spendCoins(player, price)
		if not spent then
			return false
		end
	end

	-- Desbloquear personagem
	_dataStoreManager.unlockCharacter(player, characterClass)

	-- Persistir
	_dataStoreManager.savePlayerData(player)

	print("[TheBrokenBox] ShopService: " .. player.Name .. " desbloqueou " .. characterClass .. " por " .. price .. " moedas!")

	-- Disparar sinais
	local newTotal = ShopService.getCoins(player)
	ShopService.coinsUpdated:Fire(player, newTotal)
	ShopService.characterUnlocked:Fire(player, characterClass)

	return true
end

-- ============================================================
-- API: Lista de personagens com status
-- ============================================================

--[[
  Retorna a lista de personagens com status de desbloqueio para o jogador.
  Formato: { { class, name, free, unlocked, price, role, description }, ... }
]]
function ShopService.getShopCharacters(player: Player)
	local characters = {}

	-- Cacador (sempre gratuito)
	table.insert(characters, {
		class = "Distorcido",
		name = GameConstants.Hunter.NAME,
		free = true,
		unlocked = true,
		price = 0,
		role = "Hunter",
		description = "O Cacador - criatura sobrenatural",
	})

	-- Sobreviventes gratuitos
	local freeSurvivors = { "SACKBOY", "MEDICO" }
	for _, key in ipairs(freeSurvivors) do
		local config = GameConstants.Survivors[key]
		if config then
			table.insert(characters, {
				class = config.NAME,
				name = config.NAME,
				free = true,
				unlocked = true,
				price = 0,
				role = "Survivor",
				description = config.ROLE or "",
			})
		end
	end

	-- Sobreviventes pagos
	local paidSurvivors = { "SOLDADO", "ROBO" }
	for _, key in ipairs(paidSurvivors) do
		local config = GameConstants.Survivors[key]
		if config then
			local price = UNLOCK_PRICES[config.NAME] or 0
			local unlocked = _dataStoreManager and _dataStoreManager.isCharacterUnlocked(player, config.NAME) or false

			table.insert(characters, {
				class = config.NAME,
				name = config.NAME,
				free = false,
				unlocked = unlocked,
				price = price,
				role = "Survivor",
				description = config.ROLE or "",
			})
		end
	end

	return characters
end

-- ============================================================
-- Injetar dependencia (DataStoreManager)
-- ============================================================

--[[
  Injeta o DataStoreManager como dependencia.
  Chamado pelo GameManager apos initServices().
]]
function ShopService.injectDataStoreManager(dsm: any): ()
	_dataStoreManager = dsm
	print("[TheBrokenBox] ShopService: DataStoreManager injetado.")
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

--[[
  Init(): setup sincrono.
]]
function ShopService.Init(): ()
	print("[TheBrokenBox] ShopService.Init()")
end

--[[
  Start(): listeners de sinais externos (missionCompleted, playerEscaped).
]]
function ShopService.Start(): ()
	print("[TheBrokenBox] ShopService.Start() - aguardando sinais de moedas...")
	-- Os listeners serao conectados via GameManager.wireServiceSignals()
	-- usando guard clauses (if services.MissionService then...end)
end

return ShopService
