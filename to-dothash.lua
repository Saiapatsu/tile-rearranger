local path = require("path")
local common = require(path.resolve(path.dirname(table.remove(args, 1)), "common.lua")) -- infuriating drag-and-drop behavior on windows. there is no cd() in lua
-- TODO: make drag and drop on lua do cd %~p1 on my system

for _,target in ipairs(args) do
	common.convert(target, "dothash")
end
