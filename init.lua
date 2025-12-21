-- Copyright 2025 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {}
M.show_connected = true  -- Display 'DRPC' in buffer_statusbar
M.private_mode = false  -- Be more vague with details, e.g. no file or folder names
M.connect_attempts = 10  -- Maximum tries at startup to to connect
local attempts = 0
local is_connected = false  -- To track whether we're connected

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'  -- TODO: Can Discord/ARMCord even support this?
end
M.rpc = require(lib)

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

local function attach_handlers()
	events.connect(events.QUIT, function ()
		M.rpc.close()
		return nil
	end, 1)
	events.connect(events.RESET_BEFORE, function ()
		M.rpc.close() ; is_connected = false
	end)
	events.connect(events.UPDATE_UI, M.update)
end

local function remove_handlers()
	events.disconnect(events.UPDATE_UI, M.update)
	events.disconnect(events.RESET_BEFORE, function ()
		M.rpc.close() ; is_connected = false
	end)
	events.disconnect(events.QUIT, function ()
		M.rpc.close()
		return nil
	end, 1)  -- TODO: Is this right?
end

local function update_presence_details()
	-- TODO: Handle edge cases like CMake etc.
	local capitalised_type = buffer:get_lexer():sub(1,1):upper()..buffer:get_lexer():sub(2)

	-- State
	-- TODO: Details like running, editing, debugging etc.
	local task = buffer.modify and 'editing ' or 'viewing '

	local filestate = 'Untitled'
	if (M.private_mode) then
		filestate = 'a ' .. capitalised_type .. (capitalised_type:find('file') and '.' or ' file.')
	else
		if (buffer.filename) then
			local their = ''
			if (buffer.filename:match('.textadept/init.lua')
				or buffer.filename:match('.textadept\\init.lua')) then
				their = 'their Textadept ' -- Call em out
			end
			filestate = their .. buffer.filename:match('[^/\\]+$')
		end
	end
	M.presence.state = 'Currently ' .. task .. filestate

	-- Details
	-- IDEAS: Time since most recent commit? Git branch name?
	if (io.get_project_root() and (not M.private_mode)) then
		local project_name = io.get_project_root():match('[^/\\]+$')
		M.presence.details = 'Project directory: ' .. project_name
	else
		M.presence.details = ''
	end

	-- TODO: Amount of issues (LSP or from compile/run)
	--local issues = 1
	if (issues) then
		M.presence.details = ((M.presence.details == '') and 'Issues: '
			or (M.presence.details .. ' - Issues: ')) .. errors
	end

	M.presence.largeImageKey = buffer:get_lexer()
	M.presence.largeImageText = 'Working on a ' .. capitalised_type ..
		(capitalised_type:find('file') and '.' or ' file.')

end

-- Convenience wrapper that will get current details before calling rpc.update() and update UI
function M.update()
	update_presence_details()
	M.stats = M.rpc.update(M.presence)

	local spacing = CURSES and '  ' or '    '
	if (M.stats.lastCallback == 0) then
		-- Discord hasn't run any handlers yet, try sending another update
		is_connected = false
		if (attempts ~= M.connect_attempts) then
			attempts = attempts + 1
			timeout(0.2, function ()
				ui.statusbar_text = 'Attempting to connect to Discord...'
				M.update()
			end)
		else
			ui.statusbar_text = 'Could not connect to Discord.'
			M.rpc.close()  -- Just in case it's some weird connection issue
			attempts = 0
		end
	elseif (M.stats.lastCallback == 1) then
		if (is_connected == false) then
			ui.statusbar_text = 'Discord: Connected to ' .. M.stats.globalName .. '.'
			is_connected = true ; attach_handlers()
		end
	elseif (M.stats.lastCallback == 2) then
		ui.statusbar_text = 'Discord Disconnect: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false ; remove_handlers()
		M.rpc.close()
	elseif (M.stats.lastCallback == 3) then
		ui.statusbar_text = 'Discord Error: ' .. M.stats.errcode .. M.stats.errorDetails
		is_connected = false ; remove_handlers()
		M.rpc.close()
	end

	if (M.show_connected) then
		if (ui.buffer_statusbar_text:match('DRPC') == nil) then
			ui.buffer_statusbar_text = ui.buffer_statusbar_text .. spacing .. 'DRPC: '.. (is_connected and '☺' or '☹')
		else
			local without_status = string.sub(ui.buffer_statusbar_text, 1, -4)
			ui.buffer_statusbar_text = without_status .. (is_connected and '☺' or '☹')
		end
	end
end

function M.close()
	attempts = 0
	if (is_connected) then
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

	timeout(0.2, function ()
		M.rpc.init()
		M.update()
	end)
end

-- Convenience to allow user to 'start' RPC in their init.lua
-- Actually starts RPC once Textadept is fully initialised (so buffer/lexer names etc. will be present)
function M.init()
	attempts = 0
	events.connect(events.INITIALIZED, function ()
		M.connect()
	end)
end

_L['Discord RPC'] = '_Discord RPC'
local discord_menu = {
	title = _L['Discord RPC'],
	{'Connect/Reconnect', M.connect},
	{'Disconnect', M.close},
	{'Status', function ()
		ui.dialogs.message{
			title = 'Discord RPC Status',
			text =
			'Username: ' .. M.stats.username .. '\n' ..
			'Global Name: ' .. M.stats.globalName .. '\n' ..
			'User ID: ' .. M.stats.userId .. '\n' ..
			'Connected: ' .. (is_connected and 'Yes' or 'No')
		}
	end}
}

-- Add a menu entry.
local help = textadept.menu.menubar['Help']
table.insert(help, #help, discord_menu)
table.insert(help, #help, '')

return M
