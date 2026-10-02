-- // Extremely simple, pooped inspiration of Roact
--    Cooperative with ReactiveValues for menu elements that need to update live

export type Element = {
	Instance: Instance,

	Destroy: (self: Element)->()
}

local Element = {}
Element.__index = Element

function Element:Destroy()
	self.Instance:Destroy()

end

-- // Create [classname] with [properties]. [Children] can consist of any combination of [instance] or [cleaner function]
return function(ClassName: string, Properties: {[string]: any}, Children: {Instance | ()->()}?): (Instance, {()->()})
	local Element = Instance.new(ClassName)
	local Connections: {RBXScriptConnection | ()->()} = {}
	local Destroyers = {}

	if Properties then
		for Property, Value in pairs(Properties) do
			local prop = Element[Property]
			if typeof(prop) == "RBXScriptSignal" then
				-- // Connect a signal value
				table.insert(Connections, prop:Connect(function(...)
					Value(Element, ...)
				end))
			elseif typeof(Value) == "table" and Value._isReactive then
				-- // Connect a reactive value
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
				-- // Set a normal property
				--print(Property, Value)
				Element[Property] = Value
			end
		end
	end

	-- // Assign children
	if Children then
		for _, Child in pairs(Children) do
			if typeof(Child) == "Instance" then
				Child.Parent = Element
			elseif typeof(Child) == "function" then
				table.insert(Destroyers, Child) -- Destroyer function from child elements
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
				Connection() -- Reactive Value cleaner function
			elseif typeof(Connection) == "RBXScriptConnection" then
				Connection:Disconnect() -- Connection
			end
		end
		table.clear(Connections)
		Element:Destroy()
	end)

	return Element, Destroyers
end