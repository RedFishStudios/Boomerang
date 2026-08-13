local DeadlyPart = {}

local DAMAGE_INTERVAL = 2

function DeadlyPart.validate(child: Instance): boolean
   if not child:IsA("BasePart") and not child:IsA("MeshPart") and not child:IsA("Part") then
      warn(`Functional child of class {script.Name} is not a part: {child.Name}`)
      return false
   end

   local optionalAttributes = {
      ["DamagePerTick"] = typeof(0), -- If nil, instant death
   }

   local attributes = child:GetAttributes()
   for attributeName, attributeType in pairs(optionalAttributes) do
      if attributes[attributeName] ~= nil and typeof(attributes[attributeName]) ~= attributeType then
         warn(`Functional child of class {script.Name} has attribute {attributeName} of type {typeof(attributes[attributeName])}, expected {attributeType}: {child.Name}`)
         return false
      end
   end

   return true
end

function DeadlyPart.onObjectAdded(object: Part)
   
end

return DeadlyPart