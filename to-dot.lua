local path = require("path")
local common = require(path.resolve(path.dirname(table.remove(args, 1)), "common.lua")) -- infuriating drag-and-drop behavior on windows. there is no cd() in lua
-- TODO: make drag and drop on lua do cd %~p1 on my system

for _,target in ipairs(args) do
	local split = common.split(target)
	
	local success, reason, exitcode = os.execute(table.concat({
		"magick",
		"-bordercolor #00000000",
		common.unparse(target),
		"-border 32x32",
		"-strip",
		common.unparse(split.dir .. "\\" .. split.nametag .. "_dot" .. split.ext)
	}, " "))
	
	if not success then
		print("Unable to convert " .. split.tag .. " to " .. tag)
		io.read()
	end
end

-- io.read()
