local Spin = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

local SECONDS_PER_SPIN_ATTRIBUTE_NAME = "SPS"
local CLOCKWISE_ATTRIBUTE_NAME = "Clockwise"
local DEFAULT_SECONDS_PER_SPIN = 5
local RADIANS_PER_ROTATION = math.pi * 2
local NewSpin = SimpleRemotes.getEvent("NewSpin")

type SpinData = {
   Part: BasePart,
   InitialPivot: CFrame,
   SecondsPerSpin: number,
   StartedAt: number,
   Clockwise: boolean,
}

local spins: {SpinData} = {}
local connections: {RBXScriptConnection} = {}
local isServer = RunService:IsServer()

local function reset()
   table.clear(spins)
   for _, connection in connections do
      connection:Disconnect()
   end
   table.clear(connections)
end

local function findSpinById(name: string): BasePart?
   local map = workspace.Arena:FindFirstChildWhichIsA("Model")
   if not map then
      return nil
   end

   local functionalFolder = map:FindFirstChild("Functional")
   local spin = functionalFolder and functionalFolder:FindFirstChild(name)
   if spin and spin:IsA("BasePart") then
      return spin
   end
   return nil
end

local function getPivot(spinData: SpinData, serverTime: number): CFrame
   local elapsed = serverTime - spinData.StartedAt
   local angle = (elapsed / spinData.SecondsPerSpin) * RADIANS_PER_ROTATION
   if spinData.Clockwise then
      angle = -angle
   end
   return spinData.InitialPivot * CFrame.Angles(0, angle, 0)
end

local function beginRendering()
   if #connections > 0 then
      return
   end

   table.insert(connections, RunService.PreSimulation:Connect(function()
      local serverTime = workspace:GetServerTimeNow()
      for _, spinData in spins do
         spinData.Part:PivotTo(getPivot(spinData, serverTime))
      end
   end))
end

function Spin.validate(functionalChild: Instance): boolean
   if not functionalChild:IsA("Part") and not functionalChild:IsA("BasePart") and not functionalChild:IsA("MeshPart") then
      warn(`Spin.validate: functionalChild {functionalChild:GetFullName()} is not a Part, BasePart, or MeshPart`)
      return false
   end
   local secondsPerSpin = functionalChild:GetAttribute(SECONDS_PER_SPIN_ATTRIBUTE_NAME)
   if typeof(secondsPerSpin) ~= "number" or secondsPerSpin <= 0 then
      warn(`Spin.validate: functionalChild {functionalChild:GetFullName()} is missing a positive {SECONDS_PER_SPIN_ATTRIBUTE_NAME} attribute`)
      functionalChild:SetAttribute(SECONDS_PER_SPIN_ATTRIBUTE_NAME, DEFAULT_SECONDS_PER_SPIN)
   end
   return true
end

function Spin.onObjectAdded(functionalChild: BasePart, birth: number?)
   if functionalChild:GetAttribute("Invalid") then
      return
   end

   for _, spinData in spins do
      if spinData.Part == functionalChild then
         return
      end
   end

   local secondsPerSpin = functionalChild:GetAttribute(SECONDS_PER_SPIN_ATTRIBUTE_NAME)
   if typeof(secondsPerSpin) ~= "number" or secondsPerSpin <= 0 then
      secondsPerSpin = DEFAULT_SECONDS_PER_SPIN
   end

   local clockwise = functionalChild:GetAttribute(CLOCKWISE_ATTRIBUTE_NAME) == true
   local startedAt = birth or workspace:GetServerTimeNow()
   table.insert(spins, {
      Part = functionalChild,
      InitialPivot = functionalChild:GetPivot(),
      SecondsPerSpin = secondsPerSpin,
      StartedAt = startedAt,
      Clockwise = clockwise,
   })

   if isServer then
      NewSpin:FireAllClients(functionalChild.Name, startedAt, spins[#spins].InitialPivot)
   end

   beginRendering()
end

function Spin.cleanup()
   reset()
end

function Spin.init()
   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.CurrentRoundData:Subscribe(function(currentRoundData)
      if currentRoundData == nil then
         reset()
      end
   end)

   if not isServer then
      NewSpin.OnClientEvent:Connect(function(spinId: string, birth: number, initialPivot: CFrame)
         local spin = findSpinById(spinId)
         if spin then
            local currentPivot = spin:GetPivot()
            spin:PivotTo(initialPivot)
            Spin.onObjectAdded(spin, birth)
            spin:PivotTo(currentPivot)
         end
      end)
   end
end

return Spin