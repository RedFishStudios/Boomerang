local ParticlesLibrary = {}

local SimpleRemotes = require(game.ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayParticle = SimpleRemotes.getEvent("PlayParticle")
local EmitParticle = SimpleRemotes.getEvent("EmitParticle")

local ParticleAssets = game.ReplicatedStorage.Shared.Assets.Particles

local isServer = game:GetService("RunService"):IsServer()

local ParticlesFolder: Folder = game.Workspace:WaitForChild("Particles")

local registeredParticlePlayCalls: {
   [string]: {
      [string]: number
   }
} = {}

local ParticleTemplates: {[string]: Part} = {}
local function getParticle(particleName: string): Part?
   if not ParticleTemplates[particleName] then
      local particle = ParticleAssets:FindFirstChild(particleName)
      if not particle then
         warn("Particle template not found for: " .. particleName)
         return nil
      end
      ParticleTemplates[particleName] = particle
      particle.CanCollide = false
      particle.CanTouch = false
      particle.CanQuery = false
      particle.CustomPhysicalProperties = PhysicalProperties.new(.1, .1, .1, .1, .1)
   end

   return ParticleTemplates[particleName]
end

function ParticlesLibrary.destroy(particle: Part)
   local subParticleLifetime = 0
   for _, descendant in ipairs(particle:GetDescendants()) do
      if descendant:IsA("ParticleEmitter") then
         local emitterLifetime = descendant.Lifetime.Max
         if emitterLifetime > subParticleLifetime then
            subParticleLifetime = emitterLifetime
         end
      end
   end
   for _, descendant in ipairs(particle:GetDescendants()) do
      if descendant:IsA("ParticleEmitter") then
         descendant.Enabled = false
      end
   end
   task.wait(subParticleLifetime*1.1)
   if particle and particle.Parent then
      particle:Destroy()
   end
end

function ParticlesLibrary.play(particlePlayId: string, particleName: string, host: Instance | Vector3, startEmit: number?, particleLifetime: number?, anchored: boolean?)
   if isServer then
      PlayParticle:FireAllClients(particlePlayId, particleName, host, startEmit, particleLifetime, anchored)
      return
   end
   
   if registeredParticlePlayCalls[particlePlayId] and registeredParticlePlayCalls[particlePlayId][particleName] then
      local callTimedout = os.clock() - registeredParticlePlayCalls[particlePlayId][particleName] > 3
      if not callTimedout then
         return
      end
   end
   if not registeredParticlePlayCalls[particlePlayId] then
      registeredParticlePlayCalls[particlePlayId] = {}
   end
   registeredParticlePlayCalls[particlePlayId][particleName] = os.clock()

   local particleTemplate = getParticle(particleName)
   if not particleTemplate then
      warn("Particle template not found for: " .. particleName)
      return
   end
   local particle = particleTemplate:Clone()

   if typeof(host) == "Instance" then
      particle:PivotTo(host:GetPivot())
      local weld = Instance.new("WeldConstraint")
      weld.Part0 = host
      weld.Part1 = particle
      weld.Parent = particle
   elseif typeof(host) == "Vector3" then
      particle.Position = host
   else
      print(`Unrecognized host type: ${typeof(host)}`)
      return
   end
   particle.Parent = ParticlesFolder
   particle.Anchored = anchored or false

   for _, d in pairs(particle:GetChildren()) do
      if d:IsA("ParticleEmitter") then
         d.Enabled = true
      end
   end

   local subParticleLifetime = 0
   for _, descendant in ipairs(particle:GetDescendants()) do
      if descendant:IsA("ParticleEmitter") then
         local emitterLifetime = descendant.Lifetime.Max
         if emitterLifetime > subParticleLifetime then
            subParticleLifetime = emitterLifetime
         end
      end
   end
   --print("sub particle life time: ", subParticleLifetime)

   if startEmit then
      for _, d in pairs(particle:GetChildren()) do
         if d:IsA("ParticleEmitter") then
            task.spawn(function()
               local emitterLifetime = math.max(d.Lifetime.Min, particleLifetime or subParticleLifetime)
               local interval = (emitterLifetime / startEmit)*.07
               for i = 1, startEmit do
                  d:Emit(1)
                  task.wait(interval)
               end
            end)
         end
      end
   end

   if particleLifetime then
      task.spawn(function()
         task.wait(particleLifetime)
         for _, descendant in ipairs(particle:GetDescendants()) do
            if descendant:IsA("ParticleEmitter") then
               descendant.Enabled = false
            end
         end
         task.wait(subParticleLifetime*1.1)
         if particle and particle.Parent then
            particle:Destroy()
         end
      end)
   end

   return particle
end

function ParticlesLibrary.emit(particlePlayId: string, particleName: string, host: Instance | Vector3, emitCount: number)
   if isServer then
      EmitParticle:FireAllClients(particlePlayId, particleName, host, emitCount)
      return
   end
   
   if registeredParticlePlayCalls[particlePlayId] and registeredParticlePlayCalls[particlePlayId][particleName] then
      local callTimedout = os.clock() - registeredParticlePlayCalls[particlePlayId][particleName] > 3
      if not callTimedout then
         return
      end
   end
   if not registeredParticlePlayCalls[particlePlayId] then
      registeredParticlePlayCalls[particlePlayId] = {}
   end
   registeredParticlePlayCalls[particlePlayId][particleName] = os.clock()

   local particleTemplate = getParticle(particleName)
   if not particleTemplate then
      warn("Particle template not found for: " .. particleName)
      return
   end
   local particle = particleTemplate:Clone()
   particle.CustomPhysicalProperties = PhysicalProperties.new(0.01, .01, .01)

   if typeof(host) == "Instance" then
      particle:PivotTo(host:GetPivot())
      local weld = Instance.new("WeldConstraint")
      weld.Part0 = host
      weld.Part1 = particle
      weld.Parent = particle
   elseif typeof(host) == "Vector3" then
      particle.Position = host
   else
      print(`Unrecognized host type: {typeof(host)}`)
      return
   end
   particle.Parent = ParticlesFolder

   local longestLifetime = 0
   for _, d in pairs(particle:GetChildren()) do
      if d:IsA("ParticleEmitter") then
         d.Rate = 0
         d:Emit(emitCount)
         local emitterLifetime = d.Lifetime.Max
         if emitterLifetime > longestLifetime then
            longestLifetime = emitterLifetime  
         end
      end
   end

   task.spawn(function()
      task.wait(longestLifetime*2.5)
      if particle and particle.Parent then
        particle:Destroy()
      end
   end)
   
   return particle
end

local started = false

function ParticlesLibrary.init()
   if started then
      return
   end

   started = true

   if isServer then
   else
      PlayParticle.OnClientEvent:Connect(function(particlePlayId: string, particleName: string, host: Instance | Vector3, startEmit: number?, particleLifetime: number?)
         ParticlesLibrary.play(particlePlayId, particleName, host, startEmit, particleLifetime)
      end)
      EmitParticle.OnClientEvent:Connect(function(particlePlayId: string, particleName: string, host: Instance | Vector3, emitCount: number)
         ParticlesLibrary.emit(particlePlayId, particleName, host, emitCount)
      end)
   end
end

return ParticlesLibrary