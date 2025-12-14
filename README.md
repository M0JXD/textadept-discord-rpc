# Textadept Discord RPC

Simple Discord Rich Presence for Textadept. Requires Textadept 13+.

Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
*modules/* directory, and then putting the following in your *~/.textadept/init.lua*:

```lua
local discord_rpc = require('discord_rpc')
```

## About

RPC is acheived via @harmonytf's fork of Discord's unmaintained RPC libary.
Whilst the now recommend way is to use the [Discord Social SDK](https://discord.com/developers/docs/discord-social-sdk/overview) to even download it requires stating details about your "Company Name, Team Location, Role" etc. that simply don't apply for open source hobby projects. Please petition Discord to provide [a better option](https://github.com/discord/discord-rpc/issues/382#issuecomment-3620635979) for open source applications to integrate with their app with Rich Presence. I am not interested in trying to make a the server myself (i.e. "hard mode") the same way as other Rich Presence extensions work for VSCord, Neocord, Emacs-RPC... etc.

How long this libary will continue to work I do not know, as if Discord changes how RPC works in a future API version then eventually the underlying "SET_ACTIVITY" primitive will be deprecated.

I have made a Discord Developer Team for this (and possibly future) Discord projects, if you would like to be added for direct access to the client-id or to adjust other Discord please open an issue with your Discord username so I can add you. My username is m0jxd.

Icons are from the VSCord project.

## Building

CMake
