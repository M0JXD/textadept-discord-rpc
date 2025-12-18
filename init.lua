-- Copyright 2025 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {}
M.show_connected = true  -- Update the statusbar
M.private_mode = false  -- Be more vague with details, e.g. no file or folder names
local is_connected = false  -- To track whether we're connected

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'  -- TODO: Can Discord/ARMCord even support this?
end
M.rpc = require(lib)

M.stats = {
	userdetails = '',
	disconnectedDetails = '',
	errorDetails = ''
}

M.presence = {
	send_presence = true,
	state = '',
	details = '',
	startTimestamp = os.time(),
	endTimestamp = 0,
	smallImageKey = 'textadept',
	smallImageText = 'Textadept ' .. (QT and '(Qt)' or GTK and '(GTK)' or CURSES and '(curses)'),
	largeImageKey = '',
	largeImageText = ''
	-- TODO: Add Party/Match/Secret and Buttons options?
}

-- Convenience wrapper that will get current details before calling rpc.update() and update UI
function M.update()
	-- TODO: Handle edge cases like CMake etc.
	local capitalised_type = buffer:get_lexer():sub(1,1):upper()..buffer:get_lexer():sub(2)

	-- State
	-- TODO: Details like running, editing, debugging etc.
	local filestate = 'unknown'
	if (M.private_mode) then
		filestate = 'a ' .. capitalised_type .. ' file.'
	else
		if (buffer.filename) then
			local their = ''
			if (buffer.filename:match('.textadept/init.lua') or buffer.filename:match('.textadept\\init.lua')) then
				their = 'their Textadept ' -- Call em out
			end
			filestate = their .. buffer.filename:match('[^/\\]+$')
		end
	end
	M.presence.state = 'Currently ' .. (buffer.modify and 'editing ' or 'viewing ') .. filestate

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
		M.presence.details = ((M.presence.details == '') and 'Issues: ' or (M.presence.details .. ' - Issues: ')) .. errors
	end

	M.presence.largeImageKey = buffer:get_lexer()
	M.presence.largeImageText = 'Working on a ' .. capitalised_type .. (capitalised_type:find('file') and '.' or ' file.')

	-- Send away and get the stats
	M.stats.userdetails, M.stats.disconnectedDetails, M.stats.errorDetails = M.rpc.update(M.presence)

	-- Show the details
	if (M.show_connected) then
		if M.stats.disconnectedDetails ~= '' then
			ui.statusbar_text = M.stats.disconnectedDetails
			M.stats.userdetails = ''
		elseif M.stats.errorDetails ~= '' then
			ui.statusbar_text = M.stats.errorDetails
			M.stats.userdetails = ''
		end

		local spacing = CURSES and '  ' or '    '
		local status = M.stats.userdetails ~= '' and '☺' or '☹'
		if (ui.buffer_statusbar_text:match('DRPC') == nil) then
			ui.buffer_statusbar_text = ui.buffer_statusbar_text .. spacing .. 'DRPC: '.. status
		end
	end
end

-- Convenience to allow user to 'start' RPC in their init.lua, but actually starts RPC once Textadept is fully initialised
function M.init()
	events.connect(events.INITIALIZED, function ()
		M.rpc.init()
		M.update()

		-- Attach close handlers to shutdown Discord RPC cleanly
		events.connect(events.QUIT, function ()
			M.rpc.close()
			return nil
		end, 1)
		events.connect(events.RESET_BEFORE, M.rpc.close)

		-- Attach updater
		events.connect(events.UPDATE_UI, function (updated)
			M.update()
			-- Discord is a little slow to respond with it's connected status,
			-- and without a good way of it emitting a Textadept event in the handler
			-- This is the best idea I have :(
			-- TODO: Put this in a coroutine loop so connected status can show by itself
			if (M.stats.userdetails ~= '' and (is_connected == false)) then
				ui.statusbar_text = M.stats.userdetails
				is_connected = true
			end
		end)
	end)
end

return M
