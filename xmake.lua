add_rules("mode.release")

-- Please init/update the submodule first!
package("DiscordRPC")
	add_deps("cmake")
	set_sourcedir(path.join(os.scriptdir(), "discord-rpc"))
	-- add_urls('https://github.com/harmonytf/discord-rpc.git')
	-- Add the required system library for Windows Registry functions
    if (is_plat('windows')) then
        add_syslinks("Advapi32")
    end
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

target('discordrpc')
	set_kind('shared')
	add_files('ta_rpc.c')
	add_packages('DiscordRPC')
	set_configdir('$(builddir)/$(plat)/$(arch)/$(mode)')
	add_configfiles('init.lua', {onlycopy = true})
	add_includedirs('$(scriptdir)/extern/lua-5.5.0/src')

	if (is_plat('windows')) then
		-- We need to embed the minimal copy of Lua
		add_defines('LUA_BUILD_AS_DLL', 'LUA_LIB')
		local base = 'extern/lua-5.5.0/src/'
		add_files(base..'*.c')
		remove_files(
			base..'lua.c',
			base..'luac.c',
			base..'linit.c',
			base..'lib.c',
			base..'lutf8lib.c',
			base..'ltablib.c',
			base..'lstrlib.c',
			base..'loslib.c',
			base..'loadlib.c',
			base..'lmathlib.c',
			base..'liolib.c',
			base..'ldblib.c',
			base..'lcorolib.c',
			base..'lbaselib.c'
		)
	elseif (is_plat('linux')) then
		-- TODO: Rename for ARM? Check if ARMCord supports RPC?
		set_filename('discordrpc.so')
	elseif (is_plat('macosx')) then
		set_filename('discordrpcosx.so')
	end

	on_install(function (target)
		-- TODO: Fix for Windows? Windows has annoying permissions and copy behaviour
		os.cp(target:targetdir()..'/**', '~/.textadept/modules/discord_rpc')
	end)
