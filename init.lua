-- Copyright 2025-2026 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

local M = {mt = {}}
M.show_connected = true -- Display 'DRPC' status in buffer_statusbar
M.private = true -- Be more vague with details, e.g. no file or folder names
M.attempts = 20 -- Maximum allowed attempts to connect

local attempts = 0 -- Current attempt number
local last_action = 'confused at ' -- Last build/run/test action
local is_connected = false -- Are we connected to Discord?
local handlers = false -- Are handlers connected?
local old_lexer = 'Untitled' -- To track what the output buffer (probably) reflects

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm' -- TODO: Can Discord/ARMCord even support this?
end
M.rpc = require(lib)
M.edge_names = require('discord_rpc.names')

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
	events.connect(events.QUIT, M.close)
	events.connect(events.RESET_BEFORE, M.close)
	events.connect(events.SAVE_POINT_REACHED, M.update)
	events.connect(events.SAVE_POINT_LEFT, M.update)
	events.connect(events.BUFFER_AFTER_SWITCH, M.update)
	events.connect(events.VIEW_AFTER_SWITCH, M.update)
	events.connect(events.LEXER_LOADED, M.update)
	events.connect(events.BUFFER_NEW, M.update)
	if M.show_connected then events.connect(events.UPDATE_UI, discord_status) end
	handlers = true
end

local function remove_handlers()
	events.disconnect(events.QUIT, M.close)
	events.disconnect(events.RESET_BEFORE, M.close)
	events.disconnect(events.SAVE_POINT_REACHED, M.update)
	events.disconnect(events.SAVE_POINT_LEFT, M.update)
	events.disconnect(events.BUFFER_AFTER_SWITCH, M.update)
	events.disconnect(events.VIEW_AFTER_SWITCH, M.update)
	events.disconnect(events.LEXER_LOADED, M.update)
	events.disconnect(events.BUFFER_NEW, M.update)
	if M.show_connected then events.disconnect(events.UPDATE_UI, discord_status) end
	handlers = false
end

-- Update details in M.presence
local function update_presence_details()
	local task = buffer.modify and 'editing ' or 'viewing '
	local display_name
	local lexer_name

	if buffer:get_lexer() == 'output' then
		lexer_name = old_lexer
		task = last_action
	else
		lexer_name = buffer:get_lexer()
		old_lexer = lexer_name
	end

	if M.edge_names.names[lexer_name] then
		display_name = M.edge_names.names[lexer_name]
	else -- Capitalise it
		display_name = lexer_name:sub(1, 1):upper() .. lexer_name:sub(2)
	end

	local filestate = ' file.'
	if M.private then
		filestate = (M.edge_names.an[lexer_name] and 'an ' or 'a ') .. display_name ..
			(display_name:find('file') and '.' or filestate)
	else
		if buffer.filename then
			local their = ''
			if buffer.filename:match('.textadept/init.lua') or
				buffer.filename:match('.textadept\\init.lua') then
				their = 'their Textadept ' -- Call em out
			end
			filestate = their .. buffer.filename:match('[^/\\]+$')
		end
	end

	if task == 'building ' or task == 'testing ' then filestate = 'a project.' end
	M.presence.state = 'Currently ' .. task .. filestate

	-- IDEAS: Time since most recent commit? Git branch name?
	M.presence.details = ''
	if io.get_project_root() and not M.private then
		M.presence.details = 'Project directory: ' .. (io.get_project_root():match('[^/\\]+$'))
	end

	-- TODO: Amount of issues (LSP or from compile/run)
	if issues then
		M.presence.details = ((M.presence.details == '') and 'Issues: ' or
			(M.presence.details .. ' - Issues: ')) .. errors
	end

	M.presence.largeImageKey = buffer:get_lexer()
	M.presence.largeImageText = 'Working on ' .. (M.edge_names.an[lexer_name] and 'an ' or 'a ') ..
		display_name .. (display_name:find('file') and '.' or ' file.')
end

-- Get current details then update RPC and UI
function M.update()
	update_presence_details()
	M.stats = M.rpc.update(M.presence)

	if M.stats.lastCallback == 0 then
		-- Discord hasn't run any handlers yet, try sending another update
		is_connected = false
		ui.statusbar_text = 'Attempting to connect to Discord...'
		if attempts ~= M.attempts then
			attempts = attempts + 1
			timeout(0.4, function()
				M.update()
			end)
		else
			ui.statusbar_text = 'Could not connect to Discord.'
			M.close() -- Just in case it's some weird connection issue
		end
	elseif M.stats.lastCallback == 1 then
		if is_connected == false then
			ui.statusbar_text = 'Discord: Connected to ' .. M.stats.globalName .. '.'
			is_connected = true;
		end
	elseif M.stats.lastCallback == 2 then
		ui.statusbar_text = 'Discord Disconnect: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false; -- M.close()
	elseif M.stats.lastCallback == 3 then
		ui.statusbar_text = 'Discord Error: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false; -- M.close()
	end
end

function M.close()
	is_connected = false
	if handlers then remove_handlers() end
	M.rpc.close()
end

-- Connect to Discord - not suitable for calling from init.lua
function M.connect()
	M.rpc.close()
	M.presence.startTimestamp = os.time()
	if not handlers then attach_handlers() end
	attempts = 0
	timeout(0.4, function()
		M.rpc.init()
		M.update()
	end)
end

-- Allow user to 'start' RPC in their init.lua
M.mt.__call = function()
	events.connect(events.INITIALIZED, M.connect)
end
M.mt.__metatable = 'Don\'t change Discord RPC Metatable'
setmetatable(M, M.mt)

-- Just always connect these
events.connect(events.BUILD_OUTPUT, function() last_action = 'building ' end)
events.connect(events.COMPILE_OUTPUT, function() last_action = 'compiling ' end)
events.connect(events.RUN_OUTPUT, function() last_action = 'running ' end)
events.connect(events.TEST_OUTPUT, function() last_action = 'testing ' end)

-- Menu entry.
_L['Discord RPC'] = '_Discord RPC'
_L['Connect/Reconnect'] = '_Connect/Reconnect'
_L['Disconnect'] = '_Disconnect'
_L['Status'] = '_Status'
local discord_menu = {
	title = _L['Discord RPC'], {_L['Connect/Reconnect'], M.connect}, {_L['Disconnect'], M.close}, {
		_L['Status'], function()
			ui.dialogs.message{
				title = 'Discord RPC Status', text =
				-- LuaFormatter off
				'Username: ' .. M.stats.username .. '\n' ..
				'Global Name: ' .. M.stats.globalName .. '\n' ..
				'User ID: ' .. M.stats.userId .. '\n' ..
				'Discriminator: ' .. M.stats.discriminator .. '\n' ..
				'Last Callback: ' .. M.stats.lastCallback .. '\n' ..
				'Error Code: ' .. M.stats.errcode .. '\n' ..
				'Error Message: ' .. M.stats.errorDetails .. '\n' ..
				'Connected: ' .. (is_connected and 'Yes' or 'No')
				-- LuaFormatter on
			}
		end
	}
}
local help = textadept.menu.menubar['Help']
table.insert(help, #help - 1, {''})
table.insert(help, #help - 1, discord_menu)

return M
