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


#include <sourcemod>
#include <steamworks>

#include <ASteambot>

#pragma semicolon 1

#define MAX_GROUPS 128

#define IDAYS 3

new String:path_decals[PLATFORM_MAX_PATH];

enum Listado
{
	String:Nombre[256],
	String:groupid64[64]
}

new g_groups[MAX_GROUPS][Listado];
new g_groupCount = 0;

bool g_invited[MAXPLAYERS + 1];

#define PLUGIN_VERSION "4.2b ASteambot version"

public Plugin:myinfo = 
{
	name = "SM Franug Auto Inviter",
	author = "Franc1sco franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
}

new ismysql;
new Handle:db;
new bool:uselocal = false;

public OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_AutoInviteToGroup");
	
	CreateConVar("sm_franugautoinviter_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);

	ComprobarDB(true, "autoinviter");
	
	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/franug-autoinviter/franug_autoinviter.cfg");
	ReadGroups();
	
	CreateTimer(60.0, DoInvite, _, TIMER_REPEAT);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action DoInvite(Handle timer)
{
	PruneDatabaseInvite();
}

public OnClientPostAdminCheck(client)
{
	if (IsFakeClient(client))return;
	
	g_invited[client] = false;
	
	
	for (new i=0; i<g_groupCount; ++i)
	{
		SteamWorks_GetUserGroupStatus(client, GroupID64to32(g_groups[i][groupid64]));
	}
	
}

stock GroupID64to32(const String:GroupID64[])
{
	if(strlen(GroupID64) < 10) return 0;
	
	decl String:trimmedGroupID64[64];
	strcopy(trimmedGroupID64, sizeof trimmedGroupID64, GroupID64[9]);
	return (StringToInt(trimmedGroupID64) - 429521408);
}

public int SteamWorks_OnClientGroupStatus(int authid, int groupAccountID, bool isMember, bool isOfficer)
{
	int client = UserAuthGrab(authid);
	
	if (client == -1)return;
	
	if (isMember || isOfficer)return;
	
	if (g_invited[client])return;
	
	g_invited[client] = true;
	
	new String:steamID64[64];
	GetClientAuthId(client, AuthId_Steam2, steamID64, sizeof steamID64);
	
	AddDB(steamID64);
}


int UserAuthGrab(int authid)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			char charauth[64], authchar[64];
			GetClientAuthId(i, AuthId_Steam3, charauth, sizeof(charauth));
			IntToString(authid, authchar, sizeof(authchar));
			if(StrContains(charauth, authchar) != -1) return i;
		}
	}
	
	return -1;
}

AddDB(char [] steam)
{
	CheckSteamID(steam);
}

CheckSteamID(char [] steam)
{
	if (db == INVALID_HANDLE)
	{
		return;
	}
	
	decl String:query[255];

	Format(query, sizeof(query), "SELECT * FROM autoinviterv41_2 WHERE steam = '%s'", steam);

	Handle datapack = CreateDataPack();
	WritePackString(datapack, steam);
	
	SQL_TQuery(db, T_CheckSteamID, query, datapack);
}
 
public T_CheckSteamID(Handle:owner, Handle:hndl, const String:error[], any datapack)
{
	ResetPack(datapack);

	char steam[64];
	ReadPackString(datapack, steam, 64);
	
	CloseHandle(datapack);
	
	if (hndl == INVALID_HANDLE)
	{
		ComprobarDB();
		return;
	}

	if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) 
	{
		ASteambot_SendMesssage(AS_FRIEND_INVITE, steam);
		
		char query[3096];

		Format(query, sizeof(query), "INSERT INTO autoinviterv41(steam, last_accountuse) VALUES('%s', '%i');", steam, GetTime());
		SQL_TQuery(db, tbasico, query);
	}
}


ComprobarDB(bool:reconnect = false,String:basedatos[64] = "autoinviter")
{
	if(uselocal) basedatos = "clientprefs";
	if(reconnect)
	{
		if (db != INVALID_HANDLE)
		{
			//LogMessage("Reconnecting DB connection");
			CloseHandle(db);
			db = INVALID_HANDLE;
		}
	}
	else if (db != INVALID_HANDLE)
	{
		return;
	}

	if (!SQL_CheckConfig( basedatos ))
	{
		if(StrEqual(basedatos, "clientprefs")) SetFailState("Databases not found");
		else 
		{
			//base = "clientprefs";
			ComprobarDB(true,"clientprefs");
			uselocal = true;
		}
		
		return;
	}
	SQL_TConnect(OnSqlConnect, basedatos);
}


public OnSqlConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		
		SetFailState("Databases dont work");
	}
	else
	{
		db = hndl;
		decl String:buffer[3096];
		
		SQL_GetDriverIdent(SQL_ReadDriver(db), buffer, sizeof(buffer));
		ismysql = StrEqual(buffer,"mysql", false) ? 1 : 0;
	
		if (ismysql == 1)
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS `autoinviterv41` (`steam` varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0')");

			
			SQL_TQuery(db, tbasicoC, buffer);

		}
		else
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS autoinviterv41 (steam varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0')");
		

			SQL_TQuery(db, tbasicoC, buffer);
		}
	}
}

public tbasicoC(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Query failure: %s", error);
	}
	LogMessage("Database connection successful");
}

public tbasico(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Query failure: %s", error);
		ComprobarDB();
	}
}


ReadGroups() {
	
	g_groupCount = 0;
	

	Handle kv = CreateKeyValues("Autoinviter");
	FileToKeyValues(kv, path_decals);

	if (!KvGotoFirstSubKey(kv)) {

		SetFailState("CFG File not found: %s", path_decals);
		CloseHandle(kv);
	}
	do {

		KvGetSectionName(kv, g_groups[g_groupCount][groupid64], 64);
		
		KvGetString(kv, "groupurl", g_groups[g_groupCount][Nombre], 256);
		
		g_groupCount++;
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);
}

public PruneDatabaseInvite()
{
	if (db == INVALID_HANDLE)
	{
		LogError( "Prune Database: No connection");
		ComprobarDB();
		return;
	}

	new maxlastaccuse;
	maxlastaccuse = GetTime() - (IDAYS * 86400);

	decl String:buffer[1024];

	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "SELECT steam FROM `autoinviterv41` WHERE `last_accountuse`<'%d' AND `last_accountuse`>'0' ORDER BY `last_accountuse` ASC LIMIT 1;", maxlastaccuse);
	else
		Format(buffer, sizeof(buffer), "SELECT steam FROM autoinviterv41 WHERE last_accountuse<'%d' AND last_accountuse>'0' ORDER BY last_accountuse ASC LIMIT 1;", maxlastaccuse);

	SQL_TQuery(db, tbasicoPInviter, buffer);
}

public tbasicoPInviter(Handle:owner, Handle:hndl, const String:error[], any data)
{
	
	if (hndl == INVALID_HANDLE)
	{
		ComprobarDB();
		return;
	}

	char steamid[64];
	//char buffer[255];
	
	if(SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
			
			int count = 5;
			for (new i=0; i<g_groupCount; ++i)
			{
				DataPack pack;
				CreateDataTimer(count*1.0, InvitePlayer, pack);
				pack.WriteCell(i);
				pack.WriteString(steamid);
			
				count += 5;
			}
		}
		
		char buffer[255];
	
		if (ismysql == 1)
			Format(buffer, sizeof(buffer), "DELETE FROM `autoinviterv41` WHERE `steam`='%s';", steamid);
		else
			Format(buffer, sizeof(buffer), "DELETE FROM autoinviterv41 WHERE steam='%s';", steamid);

		SQL_TQuery(db, tbasico, buffer);
	}
}

public Action InvitePlayer(Handle timer, Handle pack)
{
	char account[128];
	
	ResetPack(pack);
	int i = ReadPackCell(pack);
	ReadPackString(pack, account, sizeof(account));
	
	char msg[100];
	Format(msg, sizeof(msg),  "%s/%s", account, g_groups[i][groupid64]);
	ASteambot_SendMesssage(AS_INVITE_GROUP, msg);
}