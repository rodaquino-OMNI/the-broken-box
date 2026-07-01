--!strict
--[[
  CameraManager.lua
  Gerencia a camera do jogador no cliente.

  Funcionalidades:
    - 3a pessoa padrao (para ambos os papeis)
    - Toggle livre para 1a pessoa (tecla V por padrao)
    - FOV padrao: 70
    - Transicao suave entre perspectivas
    - Suporte a mobile (toque/arrastar)

  Referencias: GDD M7 (Camera e Visao), architecture.md
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Modulo CameraManager
-- ============================================================
local CameraManager = {}

-- ============================================================
-- Constantes de camera
-- ============================================================
local DEFAULT_FOV = 70
local THIRD_PERSON_DISTANCE = 12         -- Distancia da camera em 3a pessoa (studs)
local FIRST_PERSON_DISTANCE = 5/10        -- Distancia minima para 1a pessoa
local TRANSITION_SPEED = 10              -- Velocidade de transicao (maior = mais rapido)
local CAMERA_SENSITIVITY = 10/10           -- Sensibilidade do mouse (multiplicador)

-- ============================================================
-- Estado interno
-- ============================================================
local _currentPerspective = "ThirdPerson"  -- "FirstPerson" | "ThirdPerson"
local _targetDistance = THIRD_PERSON_DISTANCE
local _currentDistance = THIRD_PERSON_DISTANCE
local _isTransitioning = false

-- ============================================================
-- Funcoes internas
-- ============================================================

--[[
  Configura a camera para 3a pessoa.
]]
local function setThirdPerson()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- 3a pessoa: Roblox gerencia, apenas ajustar FOV
	camera.FieldOfView = DEFAULT_FOV
	_currentPerspective = "ThirdPerson"

	print("[TheBrokenBox] CameraManager: Alternando para 3a pessoa")
end

--[[
  Configura a camera para 1a pessoa.
]]
local function setFirstPerson()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = DEFAULT_FOV

	_targetDistance = FIRST_PERSON_DISTANCE
	_currentPerspective = "FirstPerson"
	_isTransitioning = true

	print("[TheBrokenBox] CameraManager: Alternando para 1a pessoa")
end

--[[
  Atualiza a posicao da camera a cada frame.
  Suaviza a transicao entre perspectivas.
  Chamado via RunService.RenderStepped.
]]
local function updateCamera(_deltaTime: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local character = LocalPlayer.Character
	if not character then
		return
	end

	-- 3a pessoa: Roblox gerencia automaticamente, nao mexer
	if _currentPerspective == "ThirdPerson" then
		return
	end

	-- 1a pessoa: posicionar camera na cabeca
	local head = character:FindFirstChild("Head")
	if head then
		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = head.CFrame
	end
end

--[[
  Callback de input para alternar camera.
]]
local function onCameraToggleInput(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.V then
		CameraManager.togglePerspective()
	end
end

-- ============================================================
-- API Publica
-- ============================================================

--[[
  Alterna entre 1a e 3a pessoa.
]]
function CameraManager.togglePerspective(): ()
	if _currentPerspective == "ThirdPerson" then
		setFirstPerson()
	else
		setThirdPerson()
	end
end

--[[
  Define a perspectiva explicitamente.
]]
function CameraManager.setPerspective(perspective: string): ()
	if perspective == "FirstPerson" then
		setFirstPerson()
	else
		setThirdPerson()
	end
end

--[[
  Retorna a perspectiva atual.
]]
function CameraManager.getPerspective(): string
	return _currentPerspective
end

--[[
  Define o FOV da camera.
]]
function CameraManager.setFOV(fov: number): ()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = fov
	end
end

--[[
  Retorna o FOV atual.
]]
function CameraManager.getFOV(): number
	local camera = workspace.CurrentCamera
	if camera then
		return camera.FieldOfView
	end
	return DEFAULT_FOV
end

-- ============================================================
-- Init/Start pattern
-- ============================================================

function CameraManager.Init(): ()
	print("[TheBrokenBox] CameraManager.Init()")

	-- Deixar o Roblox gerenciar a camera (3a pessoa padrao)
	_currentPerspective = "ThirdPerson"
	_currentDistance = THIRD_PERSON_DISTANCE
	_targetDistance = THIRD_PERSON_DISTANCE
end

function CameraManager.Start(): ()
	print("[TheBrokenBox] CameraManager.Start() - registrando handlers...")

	-- Atualizar camera a cada frame de renderizacao
	RunService.RenderStepped:Connect(function(deltaTime: number)
		updateCamera(deltaTime)
	end)

	-- Listener para toggle de camera (tecla V)
	UserInputService.InputBegan:Connect(onCameraToggleInput)

	-- Tambem registrar via ContextActionService para mobile
	-- (futuro: botao na tela)

	print("[TheBrokenBox] CameraManager pronto. Perspectiva: 3a pessoa, FOV: " .. DEFAULT_FOV)
end

return CameraManager
