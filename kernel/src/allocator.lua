--[[
		Name: allocator;
		Description: Simple allocator;
]]--

function createAllocator(useString, startAtZero)
	local list = {}
	local allocator = {
		list = list,
		index = startAtZero and 0 or 1
	}
	function allocator:new()
		local element = {}
		local index = self.index
		self.list[useString and tostring(index) or index] = element
		repeat
			self.index = self.index + 1
		until not self.list[useString and tostring(self.index) or self.index]
		element.index = index
		return element
	end
	function allocator:remove(element)
		panic("ALLOCATOR REMOVE")
	end
	return allocator, list
end
