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

	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = DEFAULT_FOV

	_targetDistance = THIRD_PERSON_DISTANCE
	_currentPerspective = "ThirdPerson"
	_isTransitioning = true

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

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	-- Suavizar transicao de distancia
	if _isTransitioning then
		_currentDistance = _currentDistance + (_targetDistance - _currentDistance) * math.min(1, TRANSITION_SPEED * _deltaTime)
		if math.abs(_currentDistance - _targetDistance) < 1/100 then
			_currentDistance = _targetDistance
			_isTransitioning = false
		end
	end

	-- Posicionar a camera atras do personagem
	-- A direcao e baseada na orientacao da camera, nao do personagem (controle pelo mouse)
	-- O Roblox gerencia automaticamente a rotacao via Camera.CFrame
	-- Aqui apenas definimos o modo e distancia

	-- A camera Custom com CameraSubject = humanoid ja faz o tracking
	-- Definimos a distancia via Camera.CFrame manualmente se necessario
	camera.CameraSubject = humanoidRootPart

	-- Ajustar distancia (zoom)
	-- Em 3a pessoa: camera fica atras a uma distancia fixa
	-- Em 1a pessoa: camera fica na posicao da cabeca
	if _currentPerspective == "FirstPerson" then
		-- Primeira pessoa: colocar camera na posicao da cabeca
		local head = character:FindFirstChild("Head")
		if head then
			local headCFrame = head.CFrame
			camera.CFrame = headCFrame
		end
	else
		-- Terceira pessoa: o Roblox gerencia automaticamente
		-- a posicao da camera atras do personagem
		-- Apenas definimos a distancia maxima
		camera.CameraType = Enum.CameraType.Custom
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

	-- Configurar camera inicial
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = DEFAULT_FOV
		camera.CameraType = Enum.CameraType.Custom
	end

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
