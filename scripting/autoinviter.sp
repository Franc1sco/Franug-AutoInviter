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
#include <steamworks>

#undef REQUIRE_PLUGIN
#include <steamcore>

#define MAX_SPRAYS 128

#define IDAYS 1

new String:g_sCmdLogPath[256];
new String:path_decals[PLATFORM_MAX_PATH];

enum Listado
{
	String:Nombre[64],
	String:groupid64[64]
}

new g_sprays[MAX_SPRAYS][Listado];
new g_sprayCount = 0;

#define PLUGIN_VERSION "4.0.2 beta"

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
ConVar cvar_chat;
new bool:uselocal = false;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("SteamChatIsConnected");
	MarkNativeAsOptional("SteamChatConnect");
	MarkNativeAsOptional("SteamCommunityRemoveFriend");
	MarkNativeAsOptional("SteamCommunityAddFriend");
	MarkNativeAsOptional("SteamCommunityGroupInvite");
	
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
	
	cvar_chat = CreateConVar("sm_franugautoinviter_chatmsg", "Thanks for play in the Cola-Team community servers. Please accept the group invite that I sent you for keep you updated about out servers :)");
	RegAdminCmd("sm_invite", Invitation, ADMFLAG_ROOT);
	
	
	ComprobarDB(true, "autoinviter");
	
	
	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/franug-autoinviter/franug_autoinviter.cfg");
	ReadDecals();
	
	
	CreateTimer(60.0, DoInvite, _, TIMER_REPEAT);
}

public Action DoInvite(Handle timer)
{
	PruneDatabase();
}

public OnClientPostAdminCheck(client)
{
	if (IsFakeClient(client))return;
	
	
	new String:steamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof steamID64);
	
	if (CommandExists("sm_morercon"))
	{
		//PrintToChat(client, "redirect %s", steamID64);
		ServerCommand("sm_morercon sm_invite %s", steamID64);
	}
	else
	{
		AddDB(steamID64);
	}
	//PrintToChat(client, "pasado");
}

AddDB(char [] steam)
{
	if (StrContains(steam, "765", false) == -1)return;
	
	
	//LogToFileEx(g_sCmdLogPath, "invitado a communityid %s", steam);
	CheckSteamID(steam);
}


CheckSteamID(char [] steam)
{
	if (db == INVALID_HANDLE)
	{
		return;
	}
	
	decl String:query[255];

	Format(query, sizeof(query), "SELECT * FROM autoinviterv4 WHERE steam = '%s'", steam);
	LogToFileEx(g_sCmdLogPath, "Query %s", query);
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
		SteamCommunityAddFriend(steam, 0);
	}
}


public OnCommunityAddFriendResult(const String:friend[], errorCode, any:pid)
{
	if (errorCode != 0x00)return;
	char query[3096];

	Format(query, sizeof(query), "INSERT INTO autoinviterv4(steam, last_accountuse) VALUES('%s', '%i');", friend, GetTime());
	
	LogToFileEx(g_sCmdLogPath, "Query %s", query);
	SQL_TQuery(db, tbasico, query);
	
	if(!SteamChatIsConnected()) SteamChatConnect();
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
		LogToFileEx(g_sCmdLogPath, "Database failure: %s", error);
		
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
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS `autoinviterv4` (`steam` varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0')");

			LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);

		}
		else
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS autoinviterv4 (steam varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0')");
		
			LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);
		}
	}
}

public tbasicoC(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
	}
	LogMessage("Database connection successful");
}

public tbasico(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
		ComprobarDB();
	}
}


ReadDecals() {
	
	g_sprayCount = 0;
	

	Handle kv = CreateKeyValues("Autoinviter");
	FileToKeyValues(kv, path_decals);

	if (!KvGotoFirstSubKey(kv)) {

		SetFailState("CFG File not found: %s", path_decals);
		CloseHandle(kv);
	}
	do {

		KvGetSectionName(kv, g_sprays[g_sprayCount][groupid64], 64);
		
		KvGetString(kv, "groupid", g_sprays[g_sprayCount][Nombre], 64);
		
		g_sprayCount++;
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);
}

public Action:Invitation(client, args)
{
	char arg[64];
	GetCmdArg(1, arg, sizeof arg);

	//LogToFileEx(g_sCmdLogPath, "invitado a %s", arg);
	
	if(!CommandExists("sm_morercon")) 
	{
		AddDB(arg);
	}
}

public OnChatRelationshipChange(const String:account[], SteamChatRelationship:relationship)
{
	if (relationship != SteamChatRelationshipFRIENDS) return;
	
	for (new i=0; i<g_sprayCount; ++i)
			SteamCommunityGroupInvite(account, g_sprays[i][Nombre]);
	
	char chatmsg[3096];
	GetConVarString(cvar_chat, chatmsg, 3096);
	
	if(!SteamChatIsConnected()) SteamChatConnect();
	
	SteamChatSendMessage(account, chatmsg);
	
	CreateTimer(20.0, removeTimer, SteamID64to32(account));
}

public Action:removeTimer(Handle:timer, any:SteamID32)
{
	if (db == INVALID_HANDLE)return;
	
	new String:SteamID64[32];
	SteamID32to64(SteamID32, SteamID64, sizeof SteamID64);
	
	SteamCommunityRemoveFriend(SteamID64);
	
	char buffer[255];
	
	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "DELETE FROM `autoinviterv4` WHERE `steam`='%s';", SteamID64);
	else
		Format(buffer, sizeof(buffer), "DELETE FROM autoinviterv4 WHERE steam='%s';", SteamID64);
		
		
	LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasico, buffer);
}

public PruneDatabase()
{
	if (db == INVALID_HANDLE)
	{
		LogToFileEx(g_sCmdLogPath, "Prune Database: No connection");
		ComprobarDB();
		return;
	}

	new maxlastaccuse;
	maxlastaccuse = GetTime() - (IDAYS * 86400);

	decl String:buffer[1024];

	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "SELECT steam FROM `autoinviterv4` WHERE `last_accountuse`<'%d' AND `last_accountuse`>'0';", maxlastaccuse);
	else
		Format(buffer, sizeof(buffer), "SELECT steam FROM autoinviterv4 WHERE last_accountuse<'%d' AND last_accountuse>'0';", maxlastaccuse);

	LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasicoP, buffer);
}

public tbasicoP(Handle:owner, Handle:hndl, const String:error[], any data)
{
	
	if (hndl == INVALID_HANDLE)
	{
		LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
		ComprobarDB();
		return;
	}

	char steamid[64];
	char buffer[255];
	
	if(SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
			
			if (ismysql == 1)
				Format(buffer, sizeof(buffer), "DELETE FROM `autoinviterv4` WHERE `steam`='%s';", steamid);
			else
				Format(buffer, sizeof(buffer), "DELETE FROM autoinviterv4 WHERE steam='%s';", steamid);
		
		
			LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasico, buffer);
			
			SteamCommunityRemoveFriend(steamid);
		}
	}
}