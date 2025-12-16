# Textadept Discord RPC

Simple Discord Rich Presence for Textadept. Requires Textadept 13+.

Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
*modules/* directory, and then putting the following in your *~/.textadept/init.lua*:

```lua
local discord_rpc = require('discord_rpc')
discord_rpc.init()
```

Your Discord status will show the current language you are editing.
This is untested on macOS and I can't offer any builds for that platform, but I have made some small best guess attempts to support it but I do not own any Apple devices to build nor test on.

## About

RPC is acheived via @harmonytf's fork of Discord's unmaintained RPC libary.

Whilst the now recommend way to implement RPC is to use the [Discord Social SDK](https://discord.com/developers/docs/discord-social-sdk/overview), to even download it requires stating details about your "Company Name, Team Location, Role" etc. that simply don't apply for open source hobby projects. Please petition Discord to provide [a better option](https://github.com/discord/discord-rpc/issues/382#issuecomment-3620635979) for open source applications to integrate with RPC. I am not interested in trying to make a server myself (i.e. "hard mode") the same way as other Rich Presence extensions work for VSCord, Neocord, Emacs-RPC... etc. They previously offered a pleasant, openly licensed C interfaced library for this, there's no reason they can't again. From what I can tell in Discord's RPC visualizer, the code in the Social SDK is reusing this library anyways!

How long the fork will continue to work I do not know, but it fork seems to be relatively well maintained and is about as close to "official" as I can find that fits within project requirements.

I have made a Discord Developer Team for this (and possibly future) Discord projects.
If you would like to be added for direct access to the application_id or adjusting the assets please open an issue with the required Discord details so I can add you. In the spirit of of being open when asking you to share such information, my Discord username is (unsurprisingly) m0jxd.

## Building

The library is built with [Xmake](https://xmake.io/). Before anything, after cloning this repo ensure the DiscordRPC submodule (and it's own rapidjson submodule) are fetched:

`git submodule update --init --recursive`

You can then issue the build with `xmake`. Xmake will automatically build and use the underlying library.
Search through the ./build/platform/arch/mode to the folder that contains the library and Lua file, which can be copied into the module folder.
There is an install rule for `xmake i` that will install into `~/.textadept/modules/discord_rpc`

## Assets

See here: https://stackoverflow.com/questions/64417184/how-does-pypresence-work-where-do-i-get-the-image-key

The discord application_id is attached to the project I created with my own dev account, and hard-coded into the C code. All the image keys are dependent on this key being tied to a Dis with the correct assets.
On this account they have the same names as Textadept's lexers, or in other cases (e.g. Arduino which has it's own icon but is lexed by the CPP lexer) the extensions that Textadept will pick up.
The icons are from the VSCord project.

## Thanks

- The icons are from the VSCord project. Thank you!
- Mitchell for Textadept

## TODO

- Complete POC
- Add LDoc and unit tests to align this module quality wise to Textadept's official ones
- Setup Github Actions build
