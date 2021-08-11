table.remove(args, 1)

local path = require("path")
local common = require(path.resolve(path.dirname(args[1]), "common.lua")) -- infuriating drag-and-drop behavior on windows. there is no cd() in lua
-- TODO: make drag and drop on lua do cd %~p1 on my system

for _,target in ipairs(args) do
	local split = common.split(target)
	
	os.execute(table.concat({
		"magick",
		"-bordercolor #00000000",
		common.unparse(target),
		"-border 32x32",
		"-strip",
		common.unparse(split.dir .. "\\" .. split.nametag .. "_dot2" .. split.ext)
	}, " "))
end

-- io.read()
