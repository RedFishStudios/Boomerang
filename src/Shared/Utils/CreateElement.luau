-- // Minimal Roact-inspired element builder
--    Works with ReactiveValues for menu elements that update live

export type Element = {
	Instance: Instance,

	Destroy: (self: Element)->()
}

local Element = {}
Element.__index = Element

function Element:Destroy()
	self.Instance:Destroy()

end

-- // Creates [ClassName] with [Properties]. [Children] may be instances and/or cleaner functions
return function(ClassName: string, Properties: {[string]: any}, Children: {Instance | ()->()}?): (Instance, {()->()})
	local Element = Instance.new(ClassName)
	local Connections: {RBXScriptConnection | ()->()} = {}
	local Destroyers = {}

	if Properties then
		for Property, Value in pairs(Properties) do
			local prop = Element[Property]
			if typeof(prop) == "RBXScriptSignal" then
				table.insert(Connections, prop:Connect(function(...)
					Value(Element, ...)
				end))
			elseif typeof(Value) == "table" and Value._isReactive then
				Element[Property] = Value:Get()
				local connection = Value:Subscribe(function(newValue)
					if Element.Parent then 
						Element[Property] = newValue
					else
						warn(`Cleanup setup error: Called a reactive value on an element that no longer exists! {Element.Name}`)
					end
				end)
				table.insert(Connections, connection)
			else
				--print(Property, Value)
				Element[Property] = Value
			end
		end
	end

	if Children then
		for _, Child in pairs(Children) do
			if typeof(Child) == "Instance" then
				Child.Parent = Element
			elseif typeof(Child) == "function" then
				table.insert(Destroyers, Child) -- child's destroyer
			elseif typeof(Child) == "table" then
				-- Nested destroyers from a nested element
				for _, nestedChild in pairs(Child) do
					if typeof(nestedChild) == "function" then
						table.insert(Destroyers, nestedChild)
					elseif typeof(nestedChild) == "Instance" then
						nestedChild.Parent = Element
					end
				end
			end
		end
	end

	table.insert(Destroyers, function()
		for _, Connection in pairs(Connections) do
			if typeof(Connection) == "function" then
				Connection() -- ReactiveValue unsubscribe
			elseif typeof(Connection) == "RBXScriptConnection" then
				Connection:Disconnect()
			end
		end
		table.clear(Connections)
		Element:Destroy()
	end)

	return Element, Destroyers
end