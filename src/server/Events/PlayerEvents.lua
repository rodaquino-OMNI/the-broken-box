--!strict
--[[
  PlayerEvents.lua
  Handlers de eventos de jogador no servidor:
  - OnPlayerAdded: spawn do personagem, carregar dados
  - OnPlayerRemoving: cleanup, salvar dados
  - Character spawning: configura hitbox de corpo, stamina inicial

  Referencias: GDD M3 (Morte e Pos-Morte), architecture.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.GameConstants)

local PlayerEvents = {}

-- ============================================================
-- Spawn de personagem
-- ============================================================

--[[
  Configuracao inicial do personagem quando spawna.
  - Aplica walk speed base
  - Configura hitbox de corpo (collision group)
  - Inicializa atributos (HP, stamina visiveis no HUD)
]]
function PlayerEvents.onCharacterAdded(character: Model, player: Player): ()
	print("[TheBrokenBox] PlayerEvents: Personagem spawnado para " .. player.Name)

	-- Configurar WalkSpeed base (valores especificos por classe
	-- serao aplicados pelo MatchService/SurvivorService/HunterService)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConstants.Survivors.BASE_SPEED
		humanoid.JumpPower = 50  -- Altura base; ajustada por stamina
	end

	-- Aguardar um frame para garantir que o character carregou
	task.wait()

	-- Configurar collision group para hitbox de corpo
	-- (PhysicsService precisa ser configurado no HitboxService)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		-- O HitboxService vai configurar os collision groups
		-- quando fizer Init()
	end
end

-- ============================================================
-- Eventos de conexao de jogador
-- ============================================================

--[[
  Chamado quando um jogador entra no jogo.
  - Registra no MatchService
  - Configura listener de character
]]
function PlayerEvents.onPlayerAdded(player: Player): ()
	print("[TheBrokenBox] PlayerEvents: Jogador entrou: " .. player.Name .. " (UserId: " .. player.UserId .. ")")

	-- Listener de personagem spawnado
	player.CharacterAdded:Connect(function(character: Model)
		PlayerEvents.onCharacterAdded(character, player)
	end)

	-- Se ja tiver personagem (raro, mas possivel em late-join)
	if player.Character then
		PlayerEvents.onCharacterAdded(player.Character, player)
	end
end

--[[
  Chamado quando um jogador sai do jogo.
  - Cleanup no MatchService
  - (futuro) Salvar DataStore
]]
function PlayerEvents.onPlayerRemoving(player: Player): ()
	print("[TheBrokenBox] PlayerEvents: Jogador saiu: " .. player.Name)
	-- Cleanup e feito pelo MatchService via PlayerRemoving
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

function PlayerEvents.Init(): ()
	print("[TheBrokenBox] PlayerEvents.Init()")
end

function PlayerEvents.Start(): ()
	print("[TheBrokenBox] PlayerEvents.Start() - registrando listeners de jogadores...")

	-- Jogadores ja conectados (para late-join)
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerEvents.onPlayerAdded(player)
	end

	-- Novos jogadores
	Players.PlayerAdded:Connect(PlayerEvents.onPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerEvents.onPlayerRemoving)

	print("[TheBrokenBox] PlayerEvents pronto. " .. #Players:GetPlayers() .. " jogadores conectados.")
end

return PlayerEvents
