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

new String:g_sCmdLogPath[256];

#define PLUGIN_VERSION "2.0.2"

public Plugin:myinfo = 
{
	name = "SM Franug Auto Inviter",
	author = "Franc1sco franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
}

new Handle:cvarGroupID;

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
	cvarGroupID = CreateConVar("sm_autoinviter_steamgroupid", "", "Group id where people is going to be invited.");
	
	cvar_log = CreateConVar("sm_autoinviter_logging", "1", "1 = enabled. 0 = disabled.");
	
	
	RegAdminCmd("sm_invite", Invitation, ADMFLAG_ROOT);
}

public Action:Invitation(client, args)
{
	decl String:arg[32];
	GetCmdArg(1, arg, sizeof arg);
	
	decl String:steamGroup[65];
	GetConVarString(cvarGroupID, steamGroup, sizeof(steamGroup));
	
	if(GetFeatureStatus(FeatureType_Native, "SteamGroupInvite") == FeatureStatus_Available) SteamGroupInvite(0, arg, steamGroup, callback);
}

public OnClientPostAdminCheck(client)
{
	decl String:steamGroup[65];
	GetConVarString(cvarGroupID, steamGroup, sizeof(steamGroup));

	new String:steamID64[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof steamID64);
	
	if (CommandExists("sm_morercon"))
	{
		//PrintToChat(client, "redirect %s", steamID64);
		ServerCommand("sm_morercon sm_invite %s", steamID64);
	}
	else if(GetFeatureStatus(FeatureType_Native, "SteamGroupInvite") == FeatureStatus_Available) SteamGroupInvite(client, steamID64, steamGroup, callback);
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
			case 0x01:LogToFileEx(g_sCmdLogPath, "Server is busy with another task at this time, try again in a few seconds.");
			case 0x02:	LogToFileEx(g_sCmdLogPath, "There was a timeout in your request, try again.");
			case 0x23:	LogToFileEx(g_sCmdLogPath, "Session expired, retry to reconnect.");
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