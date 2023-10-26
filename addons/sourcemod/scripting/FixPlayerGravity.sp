#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "Fix Player Gravity",
	author = "xen, .Rushaway",
	description = "Enable prediction for gravity and fix ladders resetting it",
	version = "1.1",
	url = ""
};

ConVar g_CVar_sv_gravity;

char g_sSvGravity[8];

float g_flSvGravity;
float g_flClientGravity[MAXPLAYERS + 1];
float g_flClientActualGravity[MAXPLAYERS + 1];

bool g_bLadder[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_CVar_sv_gravity = FindConVar("sv_gravity");
	g_CVar_sv_gravity.AddChangeHook(ConVarChange);

	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
}

public void OnPluginEnd()
{
	ResetGravityAll();
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_CVar_sv_gravity.GetString(g_sSvGravity, sizeof(g_sSvGravity));
	g_flSvGravity = g_CVar_sv_gravity.FloatValue;
}

// If a player is on a ladder with modified gravity and the round end,
// their gravity would be restored to what it was last round since they'd be no longer on a ladder
public void OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	ResetGravityAll();
}

public void OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if (client < 1 || client > MaxClients) return;
	
	InitClient(client);
}

public void OnGameFrame()
{
	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
			continue;

		if (GetEntityMoveType(client) == MOVETYPE_LADDER)
		{
			// They're on a ladder, ignore current gravity modifier
			if (!g_bLadder[client])
				g_bLadder[client] = true;

			continue;
		}

		// Now that they're off, restore it
		if (g_bLadder[client])
		{
			RequestFrame(RestoreGravity, client);
			continue;
		}

		float flClientGravity = GetEntityGravity(client);

		// Gamemovement treats 0.0 gravity as 1.0, and 0.0 is only set by ladders so ignore
		if (flClientGravity == 0.0)
			continue;

		g_flClientGravity[client] = flClientGravity;

		// Some maps change sv_gravity while clients already have modified gravity
		// So we store the actual calculated gravity to catch such cases
		float flClientActualGravity = flClientGravity * g_flSvGravity;

		if (flClientActualGravity != g_flClientActualGravity[client])
		{
			char szGravity[8];
			FloatToString(flClientActualGravity, szGravity, sizeof(szGravity));
			g_CVar_sv_gravity.ReplicateToClient(client, szGravity);

			g_flClientActualGravity[client] = flClientActualGravity;
		}
	}
}

public void RestoreGravity(int client)
{
	g_bLadder[client] = false;
	SetEntityGravity(client, g_flClientGravity[client]);
}

public void ResetGravityAll()
{
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
			g_CVar_sv_gravity.ReplicateToClient(client, g_sSvGravity);
	}
}

stock void InitClient(int client)
{
	g_flClientGravity[client] = 1.0;
	g_bLadder[client] = false;
}