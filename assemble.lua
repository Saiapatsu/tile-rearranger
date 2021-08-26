local script = table.remove(args, 1)
local path = require("path")

if args[1] == nil then
	print([[assemble.lua

Specify output filename, size of grid and optionally out-of-filename array of items")

Example of file with array in name:
assemble "bwall.base.111 4x 4 6 E C 5 7 F D 1 3 B 9 0 2 A 8.png"

Example of file with array in second argument (when array is too long for a filename):"
assemble "bwall.base.111.png" "4x 4 6 E C 5 7 F D 1 3 B 9 0 2 A 8"

Example of file with overridden name or tileset+animframe:
assemble "bwall.base.111.png" "4x 4 6 E C !bwall_5 !bwall_7 F.base.111! !bwall_D.base.111!"

The 4x4, 4x or 4 at the start of the array is the row size and may be
changed if your image isn't 4 tiles wide.]])
	return
end

local filename = args[1]

-- split filepath into directory and filename
local dir, filename = filename:match("(.-)([^\\/]+)$")

-- parse filename
local name, tsa, array_, fileext = filename:match("^([^. ]+)(%.?[^ ]*)(.*)(%.[^. ]+)$")
if args[2] then array_ = args[2] end

-- split array
local array = {}
for v in array_:gmatch("[^ ]+") do table.insert(array, v) end
local grid = table.remove(array, 1)

-- construct command
local rope = {"magick montage -background none -tile " .. grid .. " -geometry +0+0"}

for _, id in ipairs(array) do
	-- construct file name
	local name, tsa = name .. "_", tsa
	if id:sub(1, 1) == "!" then name, id = "", id:sub(2)     end
	if id:sub(-1)   == "!" then tsa,  id = "", id:sub(1, -2) end
	name = name .. id .. tsa .. fileext
	
	table.insert(rope, '"' .. name .. '"')
end

local command = (dir ~= "" and 'cd "' .. dir .. '" & ' or "") .. table.concat(rope, " ") .. ' \"' .. filename .. '"'

-- execute command
os.execute(command)
