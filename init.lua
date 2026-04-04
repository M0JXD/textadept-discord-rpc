-- Copyright 2025-2026 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {mt = {}}
M.show_connected = true -- Display 'DRPC' in buffer_statusbar
M.private_mode = true -- Be more vague with details, e.g. no file or folder names
M.connect_attempts = 10 -- Maximum tries at startup to to connect
local last_action = 'confused at '
local attempts = 0
local is_connected = false -- To track whether we're connected

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm' -- TODO: Can Discord/ARMCord even support this?
end
M.rpc = require(lib)

-- LuaFormatter off
M.stats = {
	--username
	--globalName
	--userId
	--discriminator
	--lastCallback
	--errcode
	--errorDetails
}

M.presence = {
	send_presence = true,
	state = '',
	details = '',
	startTimestamp = os.time(),
	endTimestamp = 0,
	smallImageKey = 'textadept',
	smallImageText = 'Textadept ' .. (QT and '(Qt)' or GTK and '(GTK)' or '(curses)'),
	largeImageKey = '',
	largeImageText = ''
	-- TODO: Add Party/Match/Secret and Buttons options?
}

-- Lexer names that are not suitable for first letter capitalisation
M.display_names = {
	applescript = "AppleScript",
	asm = "ASM",
	asp = "ASP",
	autoit = "AutoIt",
	cmake = "CMake",
	coffeescript = "CoffeeScript",
	cpp = "C++",
	csharp = "C#",
	css = "CSS",
	cuda = "CUDA",
	fsharp = "F#",
	glsl = "GLSL",
	html = "HTML",
	javascript = "JavaScript",
	json = "JSON",
	matlab = "MATLAB",
	moonscript = "MoonScript",
	objective_c = "Objective-C",
	php = "PHP",
	powershell = "PowerShell",
	sql = "SQL",
	toml = "TOML",
	typescript = "TypeScript",
	vb = "Visual Basic",
	vhdl = "VHDL",
	xml = "XML",
	yaml = "YAML"
}
-- LuaFormatter on

function string.bst_insert(str, ...)
	local text, pos, value
	local spacing = CURSES and '  ' or '    '
	local _, count = str:gsub(spacing, spacing)
	count = count + 1

	local arg = table.pack(...)
	if arg.n == 1 then
		pos = count + 1
		value = arg[1]
	elseif arg.n == 2 then
		pos = arg[1]
		value = arg[2]
	end

	if pos <= 1 then
		text = value .. spacing .. str
	elseif pos >= (count + 1) then
		text = str .. spacing .. value
	else
		local c = 0
		text, count = str:gsub(spacing, function(match)
			c = c + 1
			if c == pos - 1 then return match .. value .. match end
			return match
		end)
	end
	return text
end

local function discord_status(updated)
	if not updated or updated & 3 == 0 then return end
	ui.buffer_statusbar_text = ui.buffer_statusbar_text:bst_insert('DRPC: ' ..
		(is_connected and '☺' or '☹'))
end

local function attach_handlers()
	events.connect(events.QUIT, function()
		M.rpc.close()
		return nil
	end, 1)
	events.connect(events.RESET_BEFORE, function()
		M.rpc.close();
		is_connected = false
	end)
	events.connect(events.SAVE_POINT_REACHED, M.update)
	events.connect(events.SAVE_POINT_LEFT, M.update)
	events.connect(events.BUFFER_AFTER_SWITCH, M.update)
	events.connect(events.VIEW_AFTER_SWITCH, M.update)
	events.connect(events.LEXER_LOADED, M.update)
	events.connect(events.BUFFER_NEW, M.update)
	if M.show_connected then events.connect(events.UPDATE_UI, discord_status) end

	events.connect(events.BUILD_OUTPUT, function() last_action = 'building ' end)
	events.connect(events.COMPILE_OUTPUT, function() last_action = 'compiling ' end)
	events.connect(events.RUN_OUTPUT, function() last_action = 'running ' end)
	events.connect(events.TEST_OUTPUT, function() last_action = 'testing ' end)
end

local function remove_handlers()
	events.disconnect(events.QUIT, function()
		M.rpc.close()
		return nil
	end, 1) -- TODO: Is this right?

	events.disconnect(events.RESET_BEFORE, function()
		M.rpc.close();
		is_connected = false
	end)

	events.disconnect(events.SAVE_POINT_REACHED, M.update)
	events.disconnect(events.SAVE_POINT_LEFT, M.update)
	events.disconnect(events.BUFFER_AFTER_SWITCH, M.update)
	events.disconnect(events.VIEW_AFTER_SWITCH, M.update)
	events.disconnect(events.LEXER_LOADED, M.update)
	events.disconnect(events.BUFFER_NEW, M.update)
	if M.show_connected then events.disconnect(events.UPDATE_UI, discord_status) end
end

local old_display_name = 'Untitled'  -- So we can track running/building
local function update_presence_details()
	local task = buffer.modify and 'editing ' or 'viewing '
	local display_name = old_display_name

	if (M.display_names[buffer:get_lexer()]) then
		display_name = M.display_names[buffer:get_lexer()]
	elseif buffer:get_lexer() ~= 'output' then
		display_name = buffer:get_lexer():sub(1, 1):upper() .. buffer:get_lexer():sub(2)
	else
		task = last_action
	end
	old_display_name = display_name

	local filestate = ' file.'
	if M.private_mode then
		-- TODO: 'an' would sometimes be more appropriate
		filestate = 'a ' .. display_name .. (display_name:find('file') and '.' or filestate)
	else
		if buffer.filename then
			local their = ''
			if (buffer.filename:match('.textadept/init.lua') or
				buffer.filename:match('.textadept\\init.lua')) then
				their = 'their Textadept ' -- Call em out
			end
			filestate = their .. buffer.filename:match('[^/\\]+$')
		end
	end

	if task == 'building ' or task == 'testing ' then filestate = 'a project.' end
	M.presence.state = 'Currently ' .. task .. filestate

	-- Details
	-- IDEAS: Time since most recent commit? Git branch name?
	M.presence.details = ''
	if io.get_project_root() and not M.private_mode then
		M.presence.details = 'Project directory: ' .. (io.get_project_root():match('[^/\\]+$'))
	end

	-- TODO: Amount of issues (LSP or from compile/run)
	if issues then
		M.presence.details = ((M.presence.details == '') and 'Issues: ' or
			(M.presence.details .. ' - Issues: ')) .. errors
	end

	M.presence.largeImageKey = buffer:get_lexer()
	M.presence.largeImageText = 'Working on a ' .. display_name ..
		(display_name:find('file') and '.' or ' file.')
end

-- Convenience wrapper that will get current details before calling rpc.update() and update UI
function M.update()
	update_presence_details()
	M.stats = M.rpc.update(M.presence)

	if (M.stats.lastCallback == 0) then
		-- Discord hasn't run any handlers yet, try sending another update
		is_connected = false
		if (attempts ~= M.connect_attempts) then
			attempts = attempts + 1
			timeout(0.2, function()
				ui.statusbar_text = 'Attempting to connect to Discord...'
				M.update()
			end)
		else
			ui.statusbar_text = 'Could not connect to Discord.'
			M.rpc.close() -- Just in case it's some weird connection issue
			attempts = 0
		end
	elseif M.stats.lastCallback == 1 then
		if (is_connected == false) then
			ui.statusbar_text = 'Discord: Connected to ' .. M.stats.globalName .. '.'
			is_connected = true;
			attach_handlers()
		end
	elseif M.stats.lastCallback == 2 then
		ui.statusbar_text = 'Discord Disconnect: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false; -- remove_handlers()
		M.rpc.close()
	elseif M.stats.lastCallback == 3 then
		ui.statusbar_text = 'Discord Error: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false; -- remove_handlers()
		M.rpc.close()
	end
end

function M.close()
	attempts = 0
	if is_connected then
		is_connected = false
		remove_handlers()
	end
	M.rpc.close()
end

-- Manually connect to Discord - not suitable for calling from init.lua
-- NOTE: The Discord RPC library has it's own retry mechanism
-- that might mean this won't run for a while if using to reconnect
function M.connect()
	M.close()
	timeout(0.2, function()
		M.rpc.init()
		M.update()
	end)
end

-- Convenience to allow user to 'start' RPC in their init.lua
-- Actually starts RPC once Textadept is fully initialised (so buffer/lexer names etc. will be present)
M.mt.__call = function()
	attempts = 0
	events.connect(events.INITIALIZED, function() M.connect() end)
end
M.mt.__metatable = 'Don\'t change Discord RPC Metatable'
setmetatable(M, M.mt)

-- Add a menu entry.
_L['Discord RPC'] = '_Discord RPC'
_L['Connect/Reconnect'] = '_Connect/Reconnect'
_L['Disconnect'] = '_Disconnect'
_L['Status'] = '_Status'
local discord_menu = {
	title = _L['Discord RPC'], {_L['Connect/Reconnect'], M.connect}, {_L['Disconnect'], M.close}, {
		_L['Status'], function()
			ui.dialogs.message{
				title = 'Discord RPC Status',
				text = 'Username: ' .. M.stats.username .. '\n' .. 'Global Name: ' ..
					M.stats.globalName .. '\n' .. 'User ID: ' .. M.stats.userId .. '\n' ..
					'Connected: ' .. (is_connected and 'Yes' or 'No')
			}
		end
	}
}
local help = textadept.menu.menubar['Help']
table.insert(help, #help - 1, {''})
table.insert(help, #help - 1, discord_menu)

return M
