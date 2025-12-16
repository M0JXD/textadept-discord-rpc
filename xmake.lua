add_rules("mode.release")

-- Please init/update the submodule first!
package("DiscordRPC")
	add_deps("cmake")
	set_sourcedir(path.join(os.scriptdir(), "discord-rpc"))
	-- add_urls('https://github.com/harmonytf/discord-rpc.git')
	on_install(function (package)
		local configs = {}
		table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
		table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
		import("package.tools.cmake").install(package, configs)
	end)
	on_test(function (package)
		assert(package:has_cfuncs("Discord_Initialize", {includes = "discord_rpc.h"}))
	end)
package_end()

add_requires('DiscordRPC', {configs = {shared = false}})
add_requires('lua')  -- TODO: Try and get Lua 5.5

target('discordrpc')
	set_kind('shared')
	add_files('ta_rpc.c')
	add_packages('DiscordRPC', 'lua')
	set_configdir('$(builddir)/$(plat)/$(arch)/$(mode)')
	add_configfiles('init.lua', {onlycopy = true})

	if (is_plat('linux')) then
		-- TODO: Rename for ARM? Check if ARMCord supports RPC?
		set_filename('discordrpc.so')
	elseif (is_plat('macosx')) then
		set_filename('discordrpcosx.so')
	end

	on_install(function (target)
		-- TODO: is this right for Windows
		os.cp(target:targetdir()..'/**', '~/.textadept/modules/discord_rpc')
	end)
