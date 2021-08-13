local path = require("path")
local common = {}

--------------------------------------------------------------------------------
--                            Shell execution-related
--------------------------------------------------------------------------------

-- http://www.windowsinspired.com/understanding-the-command-line-string-and-arguments-received-by-a-windows-program/
-- http://www.windowsinspired.com/how-a-windows-programs-splits-its-command-line-into-individual-arguments/
-- Will return str such that CommandLineToArgvW or parse_cmdline, if it enters in
-- InterpretSpecialChars, will consider it one continuous argument
-- and will remain in InterpretSpecialChars afterward
-- Quotes, if necessary, will be placed around the string, not inside
-- The return value will be up to double the size of the input if it
-- consists entirely of quotes or backslashes,
-- and will output [" \""] (5 chars) for [ "] (2 chars)
-- NB! Carets, redirection etc. are handled by the shell, not here!
function common.unparse(str)
	local i = 1
	local lasti = 1 -- used to reduce amount of appends needed
	local len = #str
	local out = ""
	
	local needQuotes = false
	
	local function yeah()
		out = out .. str:sub(lasti, i-1)
		lasti = i
	end
	
	while i <= len do
		local char = str:sub(i, i)
		
		if char == "\\" then
			yeah()
			-- look for runs of \
			-- if run is followed by ", escape all of it and the "
			-- else emit as-is
			repeat i = i + 1 char = str:sub(i, i) until char ~= "\\"
			if char == "\"" then
				out = out .. ("\\"):rep((i - lasti) * 2 + 1)
				lasti = i
			else
				yeah()
			end
			
		elseif char == "\"" then
			yeah()
			out = out .. "\\"
			
		elseif char == " " or char == "\t" then
			needQuotes = true
		end
		i = i + 1
	end
	yeah()
	
	if needQuotes then
		-- trailing backslash may eat the quote
		if out:sub(-1) == "\\" then out = out .. "\\" end
		-- starting an executable on a path starting with a quote has arcane
		-- behavior, let's put the quote after the first character to avoid that
		if out:sub(1, 1) == " " or out:sub(1, 1) == "\t" then
			-- beyond saving
			return "\"" .. out .. "\""
		else
			return out:sub(1, 1) .. "\"" .. out:sub(2) .. "\""
		end
	else
		return out
	end
	
	return needQuotes and "\"" .. out .. "\"" or out
end

--------------------------------------------------------------------------------
--                              Filename management
--------------------------------------------------------------------------------

--[[
common.split(C:\Smoothing\fly_shop_empty_dot.base.111.png) = {
	href    = C:\Smoothing\fly_shop_empty_dot.base.111.png
	dir     = C:\Smoothing
	nameext = fly_shop_empty_dot.base.111.png
	nametag = fly_shop_empty_dot
	name    = fly_shop_empty
	tag     =                dot
	ext     =                   .base.111.png
	
	tag will be one of those described in common.layouts
}
]]
function common.split(target)
	local split = {}
	split.href = target
	split.dir = path.dirname(target)
	split.nameext = path.basename(target)
	split.nametag, split.ext = split.nameext:match("([^.]*)(%..*)")
	split.name, split.tag = split.nametag:match("(.*)_(.*)")
	if split.name == nil then split.name, split.tag = split.nametag, "" end
	
	if common.layouts[split.tag] == nil then
		split.name, split.tag = split.name .. "_" .. split.tag, ""
	end
	
	return split
end

--------------------------------------------------------------------------------
--                                  Conversion
--------------------------------------------------------------------------------

-- Generic conversion function
function common.convert(split, fromtag, totag)
	-- output path
	local where = split.dir .. "\\" .. split.name .. "_" .. totag .. split.ext
	
	-- get layouts
	local src = assert(common.layouts[fromtag], "Unknown tag " .. fromtag)
	local dst = assert(common.layouts[totag]  , "Unknown tag " .. totag)
	
	-- src2 is the inverse of src
	local src2 = {w = src.w, h = src.h}
	for i,v in ipairs(src) do src2[v] = i end
	
	-- dst2 is a list of imagemagick operations, each generating a tile of dst
	local dst2 = {w = dst.w, h = dst.h}
	for i,v in ipairs(dst) do dst2[i] = common.get(common.unparse(split.href), src2, v) end
	
	-- build montage command
	local command = table.concat({
		"magick montage",                    -- arrange tiles in a grid
		"-tile " .. dst2.w .. "x" .. dst2.h, -- grid size is w*h
		"-background none",                  -- transparent background
		"-geometry +0+0",                    -- no space between tiles
		table.concat(dst2, " "),
		"-strip",                            -- strip unnecessary png chunks
		common.unparse(where),               -- output
	}, " ")
	
	p(command, #command)
	
	-- run
	local success, reason, exitcode = os.execute(command)
	
	if not success then
		print("Unable to convert " .. fromtag .. " to " .. totag)
		io.read()
	end
end

--------------------------------------------------------------------------------
--                                Tile composition
--------------------------------------------------------------------------------

-- blank tile
local function empty() return "-size 32x32 xc:#00000000" end

-- clip a part out of a solid tile
local function clip(geometry)
	return function(from, src, i)
		return table.concat({"(", -- separate stack from the other images
			common.get(from, src, -1), -- solid tile
			"-crop " .. geometry, -- leave only the specified area. the
			--                        "virtual canvas" position remains!
			empty(), -- a transparent image the size of one tile
			"-flatten", -- flatten into one tile-sized layer with the tile
			--            in the right spot
		")"}, " ")
	end
end

-- overlay many tiles
local function combine(...)
	local args = {...}
	return function(from, src, i)
		local args2 = {}
		for i,v in ipairs(args) do
			args2[i] = common.get(from, src, v)
		end
		return "( " .. table.concat(args2, " ") .. " +repage -flatten )"
	end
end

common.composition = {
	[ -1] = empty, -- solid tile
	[  0] = empty, -- blank tile
	-- corners
	[  1] = --[[   (        1),]] clip("15x15+0+0"), -- nw
	[  4] = --[[   (      4  ),]] clip("15x15+17+0"), -- ne
	[  5] = combine(      4,1),
	[ 16] = --[[   (   16    ),]] clip("15x15+17+17"), -- se
	[ 17] = combine(   16  ,1),
	[ 20] = combine(   16,4  ),
	[ 21] = combine(   16,4,1),
	[ 64] = --[[   (64       ),]] clip("15x15+0+17"), -- sw
	[ 65] = combine(64     ,1),
	[ 68] = combine(64   ,4  ),
	[ 69] = combine(64   ,4,1),
	[ 80] = combine(64,16    ),
	[ 81] = combine(64,16  ,1),
	[ 84] = combine(64,16,4  ),
	[ 85] = combine(64,16,4,1),
	-- edges
	-- overlaid in the order n-e-s-w
	-- (where n means tile is to the north, e means tile is to the east etc.)
	[  2] = --[[   (         2),]] clip("15x32+0+0"), -- w
	[  8] = --[[   (8         ),]] clip("32x15+0+0"), -- n
	[ 10] = combine(8       ,2),
	[ 32] = --[[   (  32      ),]] clip("15x32+17+0"), -- e
	[ 34] = combine(  32    ,2),
	[ 40] = combine(8,32      ),
	[ 42] = combine(8,32    ,2),
	[128] = --[[   (     128  ),]] clip("32x15+0+17"), -- s
	[130] = combine(     128,2),
	[136] = combine(8   ,128  ),
	[138] = combine(8   ,128,2),
	[160] = combine(  32,128  ),
	[162] = combine(  32,128,2),
	[168] = combine(8,32,128  ),
	[170] = combine(8,32,128,2),
}

function common.get(from, src, i)
	if src[i] then
		-- exact match
		local x = (src[i]  -1)%src.w
		local y = (src[i]-x-1)/src.w
		return from .. "[32x32+" .. x*32 .. "+" .. y*32 .. "]"
		
	elseif common.composition[i] then
		return common.composition[i](from, src, i)
		
	else
		error("Unable to find or create tile " .. i)
	end
end

common.layouts = {
	[""] = { -- single tile
		w = 1, h = 1,
		-1,
	}, dot = {
		w = 3, h = 3,
		16, 128, 64,
		32,  -1,  2,
		 4,   8,  1,
	}, dothash = {
		w = 6, h = 3,
		16, 128, 64, 160, 162, 130,
		32,  -1,  2, 168, 170, 138,
		 4,   8,  1,  40,  42,  10,
	}, dagger = { -- rearranged dothash without loose ends
		w = 3, h = 6,
		 16, 128,  64,
		 32,  42,   2,
		160, 162, 130,
		168, 170, 138,
		 40,  -1,  10,
		  4,   8,   1,
		-- w = 3, h = 6,
		-- 5, 40, 168, 160, 32,  16,
		-- 8, -1, 170, 162, 42, 128,
		-- 1, 10, 138, 130,  2,  64,
	}, bruh = { -- rearranged S without loose ends
		w = 6, h = 5,
		170, 138, 69,   8, 21, 168,
		 42,  10, 17,  80, 68,  40,
		 85,  65,  4,   5,  1,  20,
		 34,   2, 16, 128, 64,  32,
		162, 130, 84, 136, 81, 160,
	}, S = {
		w = 16, h = 2,
		-1, 2, 8, 10, 32, 34, 40, 42, 128, 130, 136, 138, 160, 162, 168, 170,
		 0, 1, 4,  5, 16, 17, 20, 21,  64,  65,  68,  69,  80,  81,  84,  85,
	},
}

--------------------------------------------------------------------------------
--                                    Export
--------------------------------------------------------------------------------

return common
