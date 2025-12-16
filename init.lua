-- Copyright 2025 Jamie Drinkell. See LICENSE.
-- Textadept Discord Rich Presence

M = {}
M.show_connected = true  -- Update the statusbar

local lib = 'discord_rpc.discordrpc'
if OSX then
	lib = lib .. 'osx'
elseif LINUX and io.popen('uname -m'):read() == 'aarch64' then
	lib = lib .. 'arm'  -- TODO: Can discord even support this?
end
M.rpc = require(lib)

M.stats = {
	userdetails = nil,
	disconnectedDetails = nil,
	errorDetails = nil
}

M.presence = {
	send_presence = true,
	private = false,
	version = QT and 'Q' or GTK and 'G' or CURSES and 'C',
	idle = false,
	modified = false,
	runner = 'N',
	filename = 'filename', -- buffer.filename:match('[^/\\]+$'),
	lexer = 'lua', -- buffer:get_lexer(),
	project_name = 'project',
	errors = 0
}

-- Convenience to allow user to 'start' RPC in their init.lua, but actually start RPC once Textadept is fully initialised
function M.init()
	events.connect(events.INITIALIZED, function ()
		M.rpc.init()
		M.rpc.update()
	end)

	-- Attach close handlers to shutdown Discord RPC cleanly
	events.connect(events.QUIT, function ()
		M.rpc.close()
		return nil
	end, 1)

	events.connect(events.RESET_BEFORE, function ()
		M.rpc.close()
	end)
end

-- Convenience wrapper that will get current details before calling rpc.update() and update UI
function M.update()

	--buffer:get_lexer()

	--	rpc.update()

	if M.stats.disconnectedDetails then
		ui.statusbar_text = M.stats.disconnectedDetails
	elseif M.stats.errorDetails then
		ui.statusbar_text = M.stats.errorDetails
	end

	if (M.show_connected) then
		local spacing = CURSES and '  ' or '    '
		status = M.stats.userdetails and '☺' or '☹'
		ui.buffer_statusbar_text = ui.buffer_statusbar_text .. spacing .. 'DRPC: '..status
	end
end

-- Connect update to the right events
events.connect(events.BUFFER_AFTER_SWITCH, M.update)
events.connect(events.UPDATE_UI, function (updated)
	if ((updated == buffer.UPDATE_CONTENT) or (updated == buffer.UPDATE_SELECTION)) then
		M.update()
	end
end)

return M
