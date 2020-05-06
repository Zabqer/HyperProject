--[[
		Name: allocator;
		Description: Simple allocator;
]]--

function createAllocator()
	local list = {}
	local allocator = {
		list = list,
		index = 1
	}
	function allocator:new()
		local element = {}
		local index = self.index
		self.list[index] = element
		repeat
			self.index = self.index + 1
		until not self.list[self.index]
		element.index = index
		return element
	end
	function allocator:remove(element)
		panic("ALLOCATOR REMOVE")
	end
	return allocator, list
end
