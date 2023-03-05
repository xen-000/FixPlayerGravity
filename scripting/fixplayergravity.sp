#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "Fix Player Gravity",
	author = "xen",
	description = "Enable prediction for gravity and fix ladders resetting it",
	version = "1.0",
	url = ""
};

ConVar g_CVar_sv_gravity;

float g_flClientGravity[MAXPLAYERS + 1];
float g_flClientActualGravity[MAXPLAYERS + 1];

bool g_bLadder[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_CVar_sv_gravity = FindConVar("sv_gravity");

	HookEvent("round_start", OnRoundStart);
}

public void OnPluginEnd()
{
	ResetGravityAll();
}

// If a player is on a ladder with modified gravity and the round restarts,
// their gravity would be restored to what it was last round since they'd be no longer on a ladder
public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	ResetGravityAll();
}

public void OnGameFrame()
{
	float flSVGravity = GetConVarFloat(g_CVar_sv_gravity);

	for (int client = 1; client < MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
		{
			g_flClientGravity[client] = 1.0;
			g_bLadder[client] = false;
			continue;
		}

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
		float flClientActualGravity = flClientGravity * flSVGravity;

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
	char szGravity[8];
	g_CVar_sv_gravity.GetString(szGravity, sizeof(szGravity));

	for (int client = 1; client < MaxClients; client++)
	{
		g_flClientGravity[client] = 1.0;
		g_bLadder[client] = false;

		if (IsClientInGame(client) && !IsFakeClient(client))
			g_CVar_sv_gravity.ReplicateToClient(client, szGravity);
	}
}
