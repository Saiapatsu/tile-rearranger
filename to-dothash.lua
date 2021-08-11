local path = require("path")
local common = require(path.resolve(path.dirname(table.remove(args, 1)), "common.lua")) -- infuriating drag-and-drop behavior on windows. there is no cd() in lua
-- TODO: make drag and drop on lua do cd %~p1 on my system

for _,target in ipairs(args) do
	local split = common.split(target)
	local where = split.dir .. "\\" .. split.name .. "_dothash" .. split.ext
	
	local what = split.tag .. "-to-dothash"
	local success, reason, exitcode = os.execute(table.concat({
		common.unparse(path.resolve(path.dirname(args[1]), "conversion\\" .. what)),
		common.unparse(target),
		common.unparse(where),
	}, " "))
	if not success then
		p("Unable to convert " .. split.tag .. " to dothash")
		io.read()
	end
end
