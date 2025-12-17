/* Copyright 2025 Jamie Drinkell. See LICENSE. */
/* Simple Discord RPC wrapper suitable for Textadept */
/* Based on the send_presence example */

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "discord_rpc.h"

/* This client_id is tied to a Discord app made on my (M0JXD's) dev account for this project.
 * If you'd rather have your own ID change it here.
 * I have put this in the C code to force end users to recompile, as a different ID will not have the assets.
 */
static const char* APPLICATION_ID = "1446884816174841971";
static int64_t startTime;

static struct TAPresenceData {
    char userdetails[256];
    char disconnectedDetails[256];
    char errorDetails[256];
} taPresenceData = {"", "", ""};

/* ============================== DISCORD HANDLERS ============================== */

/* TODO: Inform Textadept on the status of these */
static void handleDiscordReady(const DiscordUser* connectedUser) {
    if (!connectedUser->discriminator[0] || strcmp(connectedUser->discriminator, "0") == 0) {
        sprintf(taPresenceData.userdetails ,"Connected to user @%s (%s) - %s",
               connectedUser->username,
               connectedUser->globalName,
               connectedUser->userId);
    } else {
        sprintf(taPresenceData.userdetails, "Connected to user %s#%s (%s) - %s",
               connectedUser->username,
               connectedUser->discriminator,
               connectedUser->globalName,
               connectedUser->userId);
    }
    //puts(taPresenceData.userdetails);
}

static void handleDiscordDisconnected(int errcode, const char* message) {
    sprintf(taPresenceData.disconnectedDetails, "Disconnected (%d: %s)", errcode, message);
    //puts(taPresenceData.disconnectedDetails);
}

static void handleDiscordError(int errcode, const char* message) {
    sprintf(taPresenceData.errorDetails, "Error (%d: %s)", errcode, message);
    //puts(taPresenceData.errorDetails);
}

static void populateHandlers(DiscordEventHandlers* handlers) {
    memset(handlers, 0, sizeof(handlers));
    handlers->ready = handleDiscordReady;
    handlers->disconnected = handleDiscordDisconnected;
    handlers->errored = handleDiscordError;

    /* We have no use for any of these */
    handlers->debug = NULL;
    handlers->joinGame = NULL;
    handlers->spectateGame = NULL;
    handlers->joinRequest = NULL;
    handlers->invited = NULL;
}

/* ============================== LUA API ============================== */

static int initDiscord(lua_State *L) {
    DiscordEventHandlers handlers;
    startTime = time(0);
    populateHandlers(&handlers);
    Discord_Initialize(APPLICATION_ID, &handlers, 1, NULL);
    Discord_ClearPresence();
#ifdef DISCORD_DISABLE_IO_THREAD
    Discord_UpdateConnection();
#endif
    Discord_RunCallbacks();
    return 0;
}

static int updateDiscordPresence(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    DiscordRichPresence discordPresence;
    memset(&discordPresence, 0, sizeof(discordPresence));

    lua_getfield(L, -1, "send_presence");
    bool send_presence = lua_toboolean(L, -1);

    lua_getfield(L, -2, "state");
    discordPresence.state = lua_tostring(L, -1);

    lua_getfield(L, -3, "details");
    discordPresence.details = lua_tostring(L, -1);

    lua_getfield(L, -4, "startTimestamp");
    discordPresence.startTimestamp = lua_tonumber(L, -1);

    lua_getfield(L, -5, "endTimestamp");
    discordPresence.endTimestamp = lua_tonumber(L, -1);

    lua_getfield(L, -6, "largeImageKey");
    discordPresence.largeImageKey = lua_tostring(L, -1);

    lua_getfield(L, -7, "largeImageText");
    discordPresence.largeImageText = lua_tostring(L, -1);

    lua_getfield(L, -8, "smallImageKey");
    discordPresence.smallImageKey = lua_tostring(L, -1);

    lua_getfield(L, -9, "smallImageText");
    discordPresence.smallImageText = lua_tostring(L, -1);

    /* TODO: Do we want to support setting party/buttons etc.? */

    if (send_presence) {
        Discord_UpdatePresence(&discordPresence);
    } else {
        Discord_ClearPresence();
    }

#ifdef DISCORD_DISABLE_IO_THREAD
    Discord_UpdateConnection();
#endif
    Discord_RunCallbacks();

    /* TODO: Ideally set a Lua table directly with the details */
    lua_pushstring(L, taPresenceData.userdetails);
    lua_pushstring(L, taPresenceData.disconnectedDetails);
    lua_pushstring(L, taPresenceData.errorDetails);
    /* Now the data is passed forward, clear them? */
    //taPresenceData.userdetails[0] = '\0';
    //taPresenceData.disconnectedDetails[0] = '\0';
    //taPresenceData.errorDetails[0] = '\0';
    return 3;
}

static int closeDiscord(lua_State *L) {
    Discord_Shutdown();
    return 0;
}

/* Entry point */
static int luaopen_discordrpc(lua_State *L) {
    static const struct luaL_Reg lib[] = {
        {"init", initDiscord},
        {"update", updateDiscordPresence},
        {"close", closeDiscord},
        {NULL, NULL} /* Sentinel */
    };
    luaL_newlib(L, lib);
    return 1;
}

/* Platform entry points with names as required by Textadept modules */
LUALIB_API int luaopen_discord_rpc_discordrpc(lua_State *L) { return luaopen_discordrpc(L); }
LUALIB_API int luaopen_discord_rpc_discordrpcosx(lua_State *L) { return luaopen_discordrpc(L); }
LUALIB_API int luaopen_discord_rpc_discordrpcarm(lua_State *L) { return luaopen_discordrpc(L); }
