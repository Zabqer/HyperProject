local component = require("component")

for k,v in component.list() do
	print(k, v)
end
