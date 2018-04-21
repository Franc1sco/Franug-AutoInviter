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

#define MAX_GROUPS 128

#define IDAYS 7

new String:g_sCmdLogPath[256];
new String:path_decals[PLATFORM_MAX_PATH];

enum Listado
{
	String:Nombre[256],
	String:groupid64[64]
}

new g_groups[MAX_GROUPS][Listado];
new g_groupCount = 0;

bool g_invited[MAXPLAYERS + 1];

#define PLUGIN_VERSION "4.2b"

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
new Handle:cvarRemoveFriends;

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
	
	cvar_chat = CreateConVar("sm_franugautoinviter_chatmsg", "Thanks for play in the Cola-Team.com community servers. Please join to our steam groups for keep you updated about our servers :)");
	RegAdminCmd("sm_invite", Invitation, ADMFLAG_ROOT);
	
	cvarRemoveFriends = CreateConVar("sm_franugautoinviter_removefriends", "1", "Removes friends after inviting them to group.", 0, true, 0.0, true, 1.0);
	
	ComprobarDB(true, "autoinviter");
	
	
	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/franug-autoinviter/franug_autoinviter.cfg");
	ReadGroups();
	
	
	CreateTimer(60.0, DoInvite, _, TIMER_REPEAT);
}

public Action DoInvite(Handle timer)
{
	PruneDatabase();
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

public int SteamWorks_OnClientGroupStatus(int authid, int groupAccountID, bool isMember, bool isOfficer)
{
	int client = UserAuthGrab(authid);
	
	if (client == -1)return;
	
	if (isMember || isOfficer)return;
	
	if (g_invited[client])return;
	
	g_invited[client] = true;
	
	new String:steamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof steamID64);
	
	if (CommandExists("sm_morercon"))
	{
		ServerCommand("sm_morercon sm_invite %s", steamID64);
	}
	else
	{
		AddDB(steamID64);
	}
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

	Format(query, sizeof(query), "SELECT * FROM autoinviterv41 WHERE steam = '%s'", steam);
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
	if (errorCode != 0x00)
	{
		LogToFileEx(g_sCmdLogPath, "Error 0x%02x on add friend", errorCode);
		return;
	}
	char query[3096];

	Format(query, sizeof(query), "INSERT INTO autoinviterv41(steam, last_accountuse) VALUES('%s', '%i');", friend, GetTime());
	
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
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS `autoinviterv41` (`steam` varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0')");

			LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);

		}
		else
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS autoinviterv41 (steam varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0')");
		
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
	
	int count = 5;
	for (new i=0; i<g_groupCount; ++i)
	{
		DataPack pack;
		CreateDataTimer(count*1.0, InvitePlayer, pack);
		pack.WriteCell(i);
		pack.WriteString(account);
			
		count += 5;
	}
	
	char chatmsg[3096];
	GetConVarString(cvar_chat, chatmsg, 3096);
	
	if(!SteamChatIsConnected()) SteamChatConnect();
	
	SteamChatSendMessage(account, chatmsg);
	
	if (GetConVarBool(cvarRemoveFriends)) CreateTimer(60.0, removeTimer, SteamID64to32(account));
}

public Action InvitePlayer(Handle timer, Handle pack)
{
	char account[128];
 
	ResetPack(pack);
	int i = ReadPackCell(pack);
	ReadPackString(pack, account, sizeof(account));
 
	LogToFileEx(g_sCmdLogPath, "Sending invite to %s for the group id %s", account, g_groups[i][groupid64]);
	
	SteamCommunityGroupInvite(account, g_groups[i][groupid64]);
	
	if(!SteamChatIsConnected()) SteamChatConnect();
	
	if(strlen(g_groups[i][Nombre]) > 2) SteamChatSendMessage(account, g_groups[i][Nombre]);
}

public Action:removeTimer(Handle:timer, any:SteamID32)
{
	if (db == INVALID_HANDLE)return;
	
	new String:SteamID64[32];
	SteamID32to64(SteamID32, SteamID64, sizeof SteamID64);
	
	SteamCommunityRemoveFriend(SteamID64);

}

public OnCommunityRemoveFriendResult(const String:friend[], errorCode, any:data)
{
	if (errorCode != 0x00)
	{
		LogToFileEx(g_sCmdLogPath, "Error 0x%02x on remove friend", errorCode);
		return;
	}
	
	char buffer[255];
	
	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "DELETE FROM `autoinviterv41` WHERE `steam`='%s';", friend);
	else
		Format(buffer, sizeof(buffer), "DELETE FROM autoinviterv41 WHERE steam='%s';", friend);
		
		
	LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasico, buffer);
}

public PruneDatabaseInvite()
{
	if (db == INVALID_HANDLE)
	{
		LogToFileEx(g_sCmdLogPath, "Prune Database: No connection");
		ComprobarDB();
		return;
	}

	new maxlastaccuse;
	maxlastaccuse = GetTime() - (1 * 86400);

	decl String:buffer[1024];

	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "SELECT steam FROM `autoinviterv41` WHERE `last_accountuse`<'%d' AND `last_accountuse`>'0' ORDER BY `last_accountuse` ASC LIMIT 1;", maxlastaccuse);
	else
		Format(buffer, sizeof(buffer), "SELECT steam FROM autoinviterv41 WHERE last_accountuse<'%d' AND last_accountuse>'0' ORDER BY last_accountuse ASC LIMIT 1;", maxlastaccuse);

	LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasicoPInviter, buffer);
}

public tbasicoPInviter(Handle:owner, Handle:hndl, const String:error[], any data)
{
	
	if (hndl == INVALID_HANDLE)
	{
		LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
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
	
			char chatmsg[3096];
			GetConVarString(cvar_chat, chatmsg, 3096);
	
			if(!SteamChatIsConnected()) SteamChatConnect();
	
			SteamChatSendMessage(steamid, chatmsg);
	
			if (GetConVarBool(cvarRemoveFriends)) CreateTimer(60.0, removeTimer, SteamID64to32(steamid));
		}
	}
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
		Format(buffer, sizeof(buffer), "SELECT steam FROM `autoinviterv41` WHERE `last_accountuse`<'%d' AND `last_accountuse`>'0';", maxlastaccuse);
	else
		Format(buffer, sizeof(buffer), "SELECT steam FROM autoinviterv41 WHERE last_accountuse<'%d' AND last_accountuse>'0';", maxlastaccuse);

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
				Format(buffer, sizeof(buffer), "DELETE FROM `autoinviterv41` WHERE `steam`='%s';", steamid);
			else
				Format(buffer, sizeof(buffer), "DELETE FROM autoinviterv41 WHERE steam='%s';", steamid);
		
		
			LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasico, buffer);
			
			SteamCommunityRemoveFriend(steamid);
		}
	}
}

public OnCommunityGroupInviteResult(const String:invitee[], const String:group[], errorCode, any:pid)
{
	if (errorCode != 0x00)
	{
		LogToFileEx(g_sCmdLogPath, "Error 0x%02x on invite friend", errorCode);
		return;
	}
	else
		LogToFileEx(g_sCmdLogPath, "Invite sent to %s for %s group", invitee, group);
	
}