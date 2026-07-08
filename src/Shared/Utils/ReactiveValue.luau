local ReactiveValue = {}
ReactiveValue.__index = ReactiveValue

export type ReactiveValue = {
	Value: any,
	Listeners: {callback: (newValue: any)->()},
	Debounce: number?,
	Debounced: true?,
	_isReactive: true,
	_DESTROYED: true?,

	Get: (self: ReactiveValue)->(),
	Set: (self: ReactiveValue, newValue: any)->(),
	SilentSet: (self: ReactiveValue, newValue: any)->(),
	Subscribe: (self: ReactiveValue, callback: (newValue: any)->())->(),
	Destroy: (self: ReactiveValue)->()
}

function ReactiveValue.new(initialValue: any, debounce: number?)
	local self = setmetatable({
		Value = initialValue,
		Listeners = {},
		Debounce = debounce,
		_isReactive = true
	}, ReactiveValue)
	return self
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Methods

-- // Get value
function ReactiveValue:Get()
	return self.Value
end

-- // Set value (fire listeners) if not debounced!
function ReactiveValue:Set(newValue: any)
	-- If debouncable -> Debounce
	if self.Debounce then
		if self.Debounced then
			print("Reactive value debounced!")
			return
		end
		self.Debounced = true
		task.spawn(function()
			task.wait(self.Debounce)
			self.Debounced = nil
		end)
	end
	-- Set
	self.Value = newValue
	for _, callback in ipairs(self.Listeners) do
		callback(newValue)
	end
	return newValue
end

-- // Set value without firing listeners
function ReactiveValue:SilentSet(newValue: any)
	self.Value = newValue
end

-- // Subscribe to value changes. Returns cleaner function.
function ReactiveValue:Subscribe(callback: (newValue: any)->()): ()->()
	table.insert(self.Listeners, callback)
	return function()
		local index = table.find(self.Listeners, callback)
		if index then
			table.remove(self.Listeners, index)
		end
	end
end

function ReactiveValue:Destroy()
	table.clear(self)
	setmetatable(self, nil)
	self._DESTROYED = true
end

return ReactiveValue