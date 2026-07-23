local ParticlesLibrary = {}

local ParticleAssets = game.ReplicatedStorage.Shared.Assets.Particles

local ParticlesFolder: Folder = game.Workspace:WaitForChild("Particles")

local ParticleTemplates: {[string]: Part} = {}
local function getParticle(particleName: string): Part?
   if not ParticleTemplates[particleName] then
       ParticleTemplates[particleName] = ParticleAssets:FindFirstChild(particleName)
   end
   return ParticleTemplates[particleName]
end

function ParticlesLibrary.play(particleName: string, host: Instance | Vector3, startEmit: number?, particleLifetime: number?)
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
      print(`Unrecognized host type: ${typeof(host)}`)
      return
   end
   particle.Parent = ParticlesFolder

   for _, d in pairs(particle:GetChildren()) do
      if d:IsA("ParticleEmitter") then
         d.Enabled = true
         if startEmit then
             d:Emit(startEmit)
         end
      end
   end

   if startEmit then
      for _, d in pairs(particle:GetChildren()) do
         if d:IsA("ParticleEmitter") then
            task.spawn(function()
               local emitterLifetime = math.max(d.Lifetime.Max, particleLifetime)
               local interval = emitterLifetime / startEmit
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
         local subParticleLifetime = 0
         for _, descendant in ipairs(particle:GetDescendants()) do
            if descendant:IsA("ParticleEmitter") then
               descendant.Enabled = false
               local emitterLifetime = descendant.Lifetime.Max
               if emitterLifetime > subParticleLifetime then
                  subParticleLifetime = emitterLifetime
               end
            end
         end
         print("sub particle life time: ", subParticleLifetime)
         task.wait(subParticleLifetime*1.1)
         if particle and particle.Parent then
            particle:Destroy()
         end
      end)
   end

   return particle
end

return ParticlesLibrary