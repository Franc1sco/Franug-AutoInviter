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
#include <autoinviter_core>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "SM Franug Auto Inviter",
	author = "Franc1sco franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
}

new Handle:cvarGroupID;

public OnPluginStart()
{
	CreateConVar("sm_franugautoinviter_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	cvarGroupID = CreateConVar("sm_autoinviter_steamgroupid", "", "Group id where people is going to be invited.");
}

public OnClientPostAdminCheck(client)
{
	decl String:steamGroup[65];
	GetConVarString(cvarGroupID, steamGroup, sizeof(steamGroup));

	new String:steamID64[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof steamID64);
	
	SteamGroupInvite(client, steamID64, steamGroup, callback);

}

public callback(client, bool:success, errorCode, any:data)
{
	/*
	if (client != 0 && !IsClientInGame(client)) return;
	
	if (success) PrintToChat(client, "The group invite has been sent.");
	else
	{
		if (errorCode < 0x10 || errorCode == 0x23)
		{

		}
		switch(errorCode)
		{
			case 0x01:	PrintToChat(client, "Server is busy with another task at this time, try again in a few seconds.");
			case 0x02:	PrintToChat(client, "There was a timeout in your request, try again.");
			case 0x23:	PrintToChat(client, "Session expired, retry to reconnect.");
			case 0x27:	PrintToChat(client, "Target has already received an invite or is already on the group.");
			default:	PrintToChat(client, "There was an error \x010x%02x \x07FFF047while sending your invite :(", errorCode);
		}
	}*/
}