/*  SM Franug Auto Inviter
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <autoinviter_core>

#define MAX_SPRAYS 128

new String:g_sCmdLogPath[256];
new String:path_decals[PLATFORM_MAX_PATH];

enum Listado
{
	String:Nombre[64]
}

new g_sprays[MAX_SPRAYS][Listado];
new g_sprayCount = 0;

new order = 0;

#define PLUGIN_VERSION "2.2.2"

public Plugin:myinfo = 
{
	name = "SM Franug Auto Inviter",
	author = "Franc1sco franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
}

new Handle:cvar_log;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("SteamGroupInvite");
	return APLRes_Success;
}

public OnPluginStart()
{
	for(new i=0;;i++)
	{
		BuildPath(Path_SM, g_sCmdLogPath, sizeof(g_sCmdLogPath), "logs/autoinviter_%d.log", i);
		if ( !FileExists(g_sCmdLogPath) )
			break;
	}
	
	
	CreateConVar("sm_franugautoinviter_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	cvar_log = CreateConVar("sm_autoinviter_logging", "1", "1 = enabled. 0 = disabled.");
	
	
	RegAdminCmd("sm_invite", Invitation, ADMFLAG_ROOT);
}

public OnMapStart()
{
	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/franug-autoinviter/franug_autoinviter.cfg");
	ReadDecals();
}

ReadDecals() {
	
	decl String:buffer[PLATFORM_MAX_PATH];
	g_sprayCount = 0;
	

	Handle kv = CreateKeyValues("Autoinviter");
	FileToKeyValues(kv, path_decals);

	if (!KvGotoFirstSubKey(kv)) {

		SetFailState("CFG File not found: %s", path_decals);
		CloseHandle(kv);
	}
	do {

		KvGetSectionName(kv, buffer, sizeof(buffer));
		Format(g_sprays[g_sprayCount][Nombre], 64, "%s", buffer);
		
		g_sprayCount++;
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);
}

public Action:Invitation(client, args)
{
	decl String:arg[32];
	GetCmdArg(1, arg, sizeof arg);

	
	if(GetFeatureStatus(FeatureType_Native, "SteamGroupInvite") == FeatureStatus_Available) 
	{
		char steamGroup[64];
		strcopy(steamGroup, 64, g_sprays[order][Nombre]);
		order++;
	
		if (order >= g_sprayCount) order = 0;
		
		SteamGroupInvite(0, arg, steamGroup, callback);
	}
}

public OnClientPostAdminCheck(client)
{
	if (IsFakeClient(client))return;
	
	
	new String:steamID64[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof steamID64);
	
	if (CommandExists("sm_morercon"))
	{
		//PrintToChat(client, "redirect %s", steamID64);
		ServerCommand("sm_morercon sm_invite %s", steamID64);
	}
	else if(GetFeatureStatus(FeatureType_Native, "SteamGroupInvite") == FeatureStatus_Available)
	{
		char steamGroup[64];
		strcopy(steamGroup, 64, g_sprays[order][Nombre]);
		order++;
	
		if (order >= g_sprayCount) order = 0;
		SteamGroupInvite(client, steamID64, steamGroup, callback);
	}
	//PrintToChat(client, "pasado");
}

public callback(client, bool:success, errorCode, any:data)
{
	if (!GetConVarBool(cvar_log))return;
	
	if (success)
	{
		LogToFileEx(g_sCmdLogPath, "The group invite has been sent.");
		//PrintToConsoleAll( "The group invite has been sent.");
	}
	else
	{
		//PrintToConsoleAll( "There was an error 0x%02x while sending your invite.", errorCode);
		if (errorCode < 0x10 || errorCode == 0x23)
		{

		}
		switch(errorCode)
		{
			case 0x01:	LogToFileEx(g_sCmdLogPath, "Server is busy with another task at this time, try again in a few seconds.");
			case 0x02:	LogToFileEx(g_sCmdLogPath, "There was a timeout in your request, try again.");
			case 0x03:	LogToFileEx(g_sCmdLogPath, "Login Error: Invalid login information, it means there are errors in the Cvar Strings.");
			case 0x04:	LogToFileEx(g_sCmdLogPath, "Login Error: Failed http RSA Key request.");
			case 0x05:	LogToFileEx(g_sCmdLogPath, "Login Error: RSA Key response failed, unknown reason, probably server side.");
			case 0x06:	LogToFileEx(g_sCmdLogPath, "Login Error: Failed htpps login request.");
			case 0x07:	LogToFileEx(g_sCmdLogPath, "Login Error: Incorrect login data, required captcha or e-mail confirmation (Steam Guard).");
			case 0x08:	LogToFileEx(g_sCmdLogPath, "Login Error: Failed http token request.");
			case 0x09:	LogToFileEx(g_sCmdLogPath, "Login Error: Invalid session token. Incorrect cookie?.");
	
			case 0x10:	LogToFileEx(g_sCmdLogPath, "Announcement Error: Failed http group announcement request.");
			case 0x11:	LogToFileEx(g_sCmdLogPath, "Announcement Error: Invalid steam login token.");
			case 0x12:	LogToFileEx(g_sCmdLogPath, "Announcement Error: Form error on request.");
	
			// Invitee: Who receives the invite.
			case 0x20:	LogToFileEx(g_sCmdLogPath, "Invite Error: Failed http group invite request.");
			case 0x21:	LogToFileEx(g_sCmdLogPath, "Invite Error: Incorrect invitee or another error.");
			case 0x22:	LogToFileEx(g_sCmdLogPath, "Invite Error: Incorrect Group ID or missing data.");
			case 0x23:	LogToFileEx(g_sCmdLogPath, "Invite Error: Logged out. Retry to login.");
			case 0x24:	LogToFileEx(g_sCmdLogPath, "Invite Error: Inviter account is not a member of the group or does not have permissions to invite.");
			case 0x25:	LogToFileEx(g_sCmdLogPath, "Invite Error: Limited account. Only full Steam accounts can send Steam group invites");
			case 0x26:	LogToFileEx(g_sCmdLogPath, "Invite Error: Unknown error.");
			case 0x27:	LogToFileEx(g_sCmdLogPath, "Target has already received an invite or is already on the group.");

			default:	LogToFileEx(g_sCmdLogPath, "There was an error 0x%02x while sending your invite.", errorCode);
		}
	}
}

stock PrintToConsoleAll(const String:format[], any:...) 
{ 
    decl String:text[192]; 
    for (new x = 1; x <= MaxClients; x++) 
    { 
        if (IsClientInGame(x)) 
        { 
            SetGlobalTransTarget(x); 
            VFormat(text, sizeof(text), format, 2); 
            PrintToConsole(x, text); 
        } 
    } 
}  