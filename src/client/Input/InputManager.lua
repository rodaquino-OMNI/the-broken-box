--!strict
--[[
  InputManager.lua
  Gerencia inputs do jogador no cliente.
  Detecta teclas pressionadas e envia acoes ao servidor
  via RemoteEvent (PlayerActionEvent).

  Binds padrao (PC — todos remapeaveis):
    WASD      = Mover
    Mouse     = Olhar / Camera
    Shift     = Correr (segurar)
    Espaco    = Pular
    E         = Interagir (missao, portao)
    Clique Esq = M1 (Cacador)
    Q         = Habilidade 1
    Botao 1   = Habilidade 2 (ou E alternativo)
    Botao 2   = Habilidade 3 (Robo — Rage para Cacador)

  Mobile:
    Joystick virtual esquerdo = Mover
    Toque/arrastar            = Camera
    Botoes na tela            = Pular, Correr, Interagir, Habilidades

  Referencias: GDD Controles e Input, workflow-roblox.md
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer

-- Dependencias compartilhadas
local GameConstants = require(ReplicatedStorage.GameConstants)
local PlayerActionEvent = require(ReplicatedStorage.Events.PlayerActionEvent)
local RemoteEventUtils = require(ReplicatedStorage.Util.RemoteEventUtils)

-- ============================================================
-- Modulo InputManager
-- ============================================================
local InputManager = {}

-- ============================================================
-- Estado interno
-- ============================================================
local _isMoving = false
local _isSprinting = false
local _moveDirection = Vector3.new(0, 0, 0)
local _playerActionEvent: RemoteEvent? = nil

-- ============================================================
-- Mapeamento de teclas padrao (remapeaveis)
-- ============================================================
InputManager.DefaultBinds = {
	MoveForward = Enum.KeyCode.W,
	MoveBackward = Enum.KeyCode.S,
	MoveLeft = Enum.KeyCode.A,
	MoveRight = Enum.KeyCode.D,
	Sprint = Enum.KeyCode.LeftShift,
	Jump = Enum.KeyCode.Space,
	Interact = Enum.KeyCode.E,
	Ability1 = Enum.KeyCode.Q,
	Ability2 = Enum.KeyCode.F,     -- Habilidade 2 / alternativo
	Ability3 = Enum.KeyCode.R,     -- Habilidade 3 / Rage
	ToggleCamera = Enum.KeyCode.V, -- Alternar 1a/3a pessoa
}

-- ============================================================
-- Funcoes internas de input
-- ============================================================

--[[
  Envia uma acao ao servidor via PlayerActionEvent.
]]
local function sendAction(messageType: string, data: {}?)
	local event = _playerActionEvent
	if not event then
		warn("[TheBrokenBox] InputManager: PlayerActionEvent nao encontrado!")
		return
	end
	RemoteEventUtils.firePlayer(event, LocalPlayer, messageType, data or {})
end

--[[
  Calcula a direcao de movimento baseada nas teclas WASD.
]]
local function calculateMoveDirection(): Vector3
	local direction = Vector3.new(0, 0, 0)

	if UserInputService:IsKeyDown(InputManager.DefaultBinds.MoveForward) then
		direction += Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(InputManager.DefaultBinds.MoveBackward) then
		direction += Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(InputManager.DefaultBinds.MoveLeft) then
		direction += Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(InputManager.DefaultBinds.MoveRight) then
		direction += Vector3.new(1, 0, 0)
	end

	return direction
end

--[[
  Atualiza o movimento a cada frame.
  Chamado via RunService.RenderStepped.
]]
local function updateMovement()
	local direction = calculateMoveDirection()
	local isMoving = direction.Magnitude > 0
	local isSprinting = isMoving and UserInputService:IsKeyDown(InputManager.DefaultBinds.Sprint)

	if isMoving ~= _isMoving or isSprinting ~= _isSprinting or direction ~= _moveDirection then
		_isMoving = isMoving
		_isSprinting = isSprinting
		_moveDirection = direction

		sendAction(PlayerActionEvent.MESSAGES.MOVE, {
			direction = direction,
			sprinting = isSprinting,
		})
	end
end

-- ============================================================
-- Handlers de teclas
-- ============================================================

--[[
  Callback quando uma tecla e pressionada (InputBegan).
]]
local function onInputBegan(input: InputObject, gameProcessed: boolean): ()
	-- Ignorar inputs processados pelo Roblox (ex.: chat)
	if gameProcessed then
		return
	end

	local keyCode = input.KeyCode

	-- Pular (Espaco)
	if keyCode == InputManager.DefaultBinds.Jump then
		sendAction(PlayerActionEvent.MESSAGES.JUMP, {})
		return
	end

	-- Interagir (E)
	if keyCode == InputManager.DefaultBinds.Interact then
		-- Interacao generica: o servidor decide se e missao, portao, etc.
		sendAction(PlayerActionEvent.MESSAGES.INTERACT_MISSION, {})
		return
	end

	-- Alternar camera (V)
	if keyCode == InputManager.DefaultBinds.ToggleCamera then
		sendAction(PlayerActionEvent.MESSAGES.TOGGLE_CAMERA, {
			mode = "Toggle",
		})
		return
	end

	-- Habilidade 1 (Q)
	if keyCode == InputManager.DefaultBinds.Ability1 then
		sendAction(PlayerActionEvent.MESSAGES.SURVIVOR_A1, {})
		return
	end

	-- Habilidade 2 (F)
	if keyCode == InputManager.DefaultBinds.Ability2 then
		sendAction(PlayerActionEvent.MESSAGES.SURVIVOR_A2, {})
		return
	end

	-- Habilidade 3 / Rage (R)
	if keyCode == InputManager.DefaultBinds.Ability3 then
		sendAction(PlayerActionEvent.MESSAGES.SURVIVOR_A3, {})
		return
	end

	-- M1 — Clique esquerdo do mouse (Cacador)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		sendAction(PlayerActionEvent.MESSAGES.HUNTER_M1, {
			aimPosition = LocalPlayer:GetMouse().Hit.Position,
		})
		return
	end
end

--[[
  Callback quando uma tecla e solta (InputEnded).
]]
local function onInputEnded(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	-- Quando soltar Shift, parar de correr
	if input.KeyCode == InputManager.DefaultBinds.Sprint then
		_isSprinting = false
		sendAction(PlayerActionEvent.MESSAGES.MOVE, {
			direction = calculateMoveDirection(),
			sprinting = false,
		})
	end
end

-- ============================================================
-- API Publica
-- ============================================================

--[[
  Verifica se o jogador esta correndo.
]]
function InputManager.isSprinting(): boolean
	return _isSprinting
end

--[[
  Verifica se o jogador esta se movendo.
]]
function InputManager.isMoving(): boolean
	return _isMoving
end

--[[
  Retorna a direcao de movimento atual.
]]
function InputManager.getMoveDirection(): Vector3
	return _moveDirection
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

function InputManager.Init(): ()
	print("[TheBrokenBox] InputManager.Init()")

	-- Encontrar ou criar o RemoteEvent de PlayerAction
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	if eventsFolder then
		_playerActionEvent = RemoteEventUtils.findRemoteEvent(eventsFolder, PlayerActionEvent.NAME)
	end

	if not _playerActionEvent then
		warn("[TheBrokenBox] InputManager: PlayerActionEvent nao encontrado em ReplicatedStorage.Events")
	end
end

function InputManager.Start(): ()
	print("[TheBrokenBox] InputManager.Start() — registrando listeners de input...")

	-- Conectar handlers de input
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Atualizar movimento a cada frame de renderizacao
	RunService.RenderStepped:Connect(function(_deltaTime: number)
		updateMovement()
	end)

	print("[TheBrokenBox] InputManager pronto. Binds configurados.")
end

return InputManager
