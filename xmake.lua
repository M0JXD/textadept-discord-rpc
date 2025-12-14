add_rules("mode.debug", "mode.release")

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
add_requires('lua')

target('ta_drpc')
	set_kind('shared')
	add_files('ta_rpc.c')
	add_packages('DiscordRPC', 'lua')

