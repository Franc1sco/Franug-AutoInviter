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
#include <autoinviter_core>

#define MAX_SPRAYS 128

new String:g_sCmdLogPath[256];
new String:path_decals[PLATFORM_MAX_PATH];

enum Listado
{
	String:Nombre[64],
	String:groupid64[64]
}

new g_sprays[MAX_SPRAYS][Listado];
new g_sprayCount = 0;

#define PLUGIN_VERSION "3.0.4-dev"

public Plugin:myinfo = 
{
	name = "SM Franug Auto Inviter",
	author = "Franc1sco franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
}

new Handle:cvar_log;

new ismysql;
new Handle:db;
new bool:uselocal = false;

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
	
	
	ComprobarDB(true, "autoinviter");
	
	
	BuildPath(Path_SM, path_decals, sizeof(path_decals), "configs/franug-autoinviter/franug_autoinviter.cfg");
	ReadDecals();
}

AddDB(char [] steam)
{
	if (StrContains(steam, "765", false) == -1)return;
	
	
	//LogToFileEx(g_sCmdLogPath, "invitado a communityid %s", steam);
	CheckSteamID(steam);
}


CheckSteamID(char [] steam)
{
	decl String:query[255];

	Format(query, sizeof(query), "SELECT * FROM autoinviter WHERE steam = '%s'", steam);
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
		//decl String:query[255];
		for (new i=0; i<g_sprayCount; ++i)
		{
			Checkgroup(steam, StringToInt(g_sprays[i][Nombre]));
			
			//Format(query, sizeof(query), "INSERT INTO autoinviter(steam, last_accountuse, groupid) VALUES('%i', '%i', '%i');", steam, GetTime(), g_sprays[i][Nombre]);
			//SQL_TQuery(db, tbasico, query);
		}
	}
}

Checkgroup(char [] steam, int groupid)
{
	
	if (strlen(steam) < 3)return;
	
	int steam32;
	char steam2[20];
	strcopy(steam2, 20, steam);
	if(!GetSteam32FromSteam64(steam2, steam32))
	{
		char buffer[255];
	
		if (ismysql == 1)
			Format(buffer, sizeof(buffer), "DELETE FROM `autoinviter` WHERE `steam`='%s';", steam);
		else
			Format(buffer, sizeof(buffer), "DELETE FROM autoinviter WHERE steam='%s';", steam);
		
		LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
		SQL_TQuery(db, tbasico, buffer);	
		
		return;
	}
	
	//LogToFileEx(g_sCmdLogPath, "va a invitar a steamid32 %d al grupo %d", steam32, groupid);
	
	
	/*
	char steam2[20]; 
	char steam3[17]; 
	char parts[3][10]; 
	int steamid32; 
	

	ExplodeString(steam2, ":", parts, sizeof(parts), sizeof(parts[]));
		
	ReplaceString(parts[0], sizeof(parts[]), "STEAM_", "");
	
	steamid32 = StringToInt(parts[1]) + (StringToInt(parts[2]) << 1);
		
	Format(steam3, sizeof(steam3), "%d", steamid32);
	*/
	
	
	SteamWorks_GetUserGroupStatusAuthID(steam32, groupid);
	
}

public int SteamWorks_OnClientGroupStatus(int steamid32, int groupAccountID, bool isMember, bool isOfficer)
{
	//LogToFileEx(g_sCmdLogPath, "recibido de steamid32 %d con grupo %d", steamid32, groupAccountID);
	if (isMember)return;
	
	//LogToFileEx(g_sCmdLogPath, "recibido de steamid32 %d con grupo %d - INVITADO", steamid32, groupAccountID);
	
	decl String:query[255];
	char steam2[128], cid[64];
	Format(steam2, sizeof(steam2), "STEAM_1:%d:%d", steamid32 & (1 << 0), steamid32 >>> 1);
	
	GetCommunityID(steam2, cid, 64);
	//LogToFileEx(g_sCmdLogPath, "recibido de communityid %s con grupo %d - INVITADO", cid, groupAccountID);
	
	LogToFileEx(g_sCmdLogPath, "Added %s for groupid %i to the DATABASE", cid, groupAccountID);
	
	Format(query, sizeof(query), "INSERT INTO autoinviter(steam, last_accountuse, groupid) VALUES('%s', '%i', '%i');", cid, GetTime(), groupAccountID);
	
	LogToFileEx(g_sCmdLogPath, "Query %s", query);
	SQL_TQuery(db, tbasico, query);
	
}

stock bool:GetCommunityID(String:AuthID[], String:FriendID[], size)
{
    if(strlen(AuthID) < 11 || AuthID[0]!='S' || AuthID[6]=='I')
    {
        FriendID[0] = 0;
        return false;
    }
    new iUpper = 765611979;
    new iFriendID = StringToInt(AuthID[10])*2 + 60265728 + AuthID[8]-48;
    new iDiv = iFriendID/100000000;
    new iIdx = 9-(iDiv?iDiv/10+1:0);
    iUpper += iDiv;
    IntToString(iFriendID, FriendID[iIdx], size-iIdx);
    iIdx = FriendID[9];
    IntToString(iUpper, FriendID, size);
    FriendID[9] = iIdx;
    return true;
}

public Action MakeInvite(Handle timer, int groupid)
{
	char query[255];
	Format(query, sizeof(query), "SELECT steam FROM autoinviter WHERE groupid = %d ORDER BY last_accountuse LIMIT 1;", groupid);
	LogToFileEx(g_sCmdLogPath, "Query %s", query);
	SQL_TQuery(db, tbasicoNew, query, groupid);
}

public tbasicoNew(Handle:owner, Handle:hndl, const String:error[], any data)
{
	
	if (hndl == INVALID_HANDLE)
	{
		ComprobarDB();
		return;
	}

	if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) 
	{
		return;
	}
	char steamid[64], groupid[32];
	
	SQL_FetchString(hndl, 0, steamid, 64);
	IntToString(data, groupid, 32);
	
	
	Handle datapack = CreateDataPack();
	WritePackString(datapack, steamid);
	WritePackString(datapack, groupid);
	
	CreateTimer(8.0, CheckSteam, datapack);
	char buffer[255];
	
	if (ismysql == 1)
		Format(buffer, sizeof(buffer), "DELETE FROM `autoinviter` WHERE `steam`='%s' AND `groupid`='%d';", steamid, StringToInt(groupid));
	else
		Format(buffer, sizeof(buffer), "DELETE FROM autoinviter WHERE steam='%s' AND groupid='%d';", steamid, StringToInt(groupid));
		
		
	LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
	SQL_TQuery(db, tbasico, buffer);
	
	LogToFileEx(g_sCmdLogPath, "Sending invitation to %s for groupid %s", steamid, groupid);
	
	for (new i=0; i<g_sprayCount; ++i)
		if(StrEqual(g_sprays[i][Nombre], groupid))
		{
			strcopy(groupid, 32, g_sprays[i][groupid64]);
			break;
		}
	
	SteamGroupInvite(0, steamid, groupid, callback);
	
	/*
	int steam32;
	
	GetSteam32FromSteam64(steamid, steam32);
	
	SteamWorks_GetUserGroupStatusAuthID(steam32, groupid);*/
	
}

public Action CheckSteam(Handle timer, any datapack)
{
	ResetPack(datapack);

	char steamid[20], groupid[32];
	ReadPackString(datapack, steamid, 64);
	ReadPackString(datapack, groupid, 32);
	
	CloseHandle(datapack);
	

	int steam32;
	
	if(GetSteam32FromSteam64(steamid, steam32))
		SteamWorks_GetUserGroupStatusAuthID(steam32, StringToInt(groupid));
	
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
		//LogToFileEx(g_sCmdLogPath, "Database failure: %s", error);
		
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
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS `autoinviter` (`steam` varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0',`groupid` int(24) NOT NULL DEFAULT '0')");

			//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);

		}
		else
		{
			Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS autoinviter (steam varchar(64) NOT NULL, `last_accountuse` int(64) NOT NULL DEFAULT '0',`groupid` int(24) NOT NULL DEFAULT '0')");
		
			//LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
			SQL_TQuery(db, tbasicoC, buffer);
		}
	}
}

public tbasicoC(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
	}
	LogMessage("Database connection successful");
}

public tbasico(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
		ComprobarDB();
	}
}


ReadDecals() {
	
	g_sprayCount = 0;
	int siguiente = 0;
	

	Handle kv = CreateKeyValues("Autoinviter");
	FileToKeyValues(kv, path_decals);

	if (!KvGotoFirstSubKey(kv)) {

		SetFailState("CFG File not found: %s", path_decals);
		CloseHandle(kv);
	}
	do {

		KvGetSectionName(kv, g_sprays[g_sprayCount][groupid64], 64);
		
		KvGetString(kv, "groupid", g_sprays[g_sprayCount][Nombre], 64);
		siguiente += 20;
		CreateTimer(siguiente * 1.0, Pasado, StringToInt(g_sprays[g_sprayCount][Nombre]));
		
		
		
		g_sprayCount++;
	} while (KvGotoNextKey(kv));
	CloseHandle(kv);
}

public Action:Pasado(Handle:timer, int id)
{
	CreateTimer(150.0, MakeInvite, id, TIMER_REPEAT);
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

// 64 bit max is 19 numbers + 1 (for teminator)
#define MAX_STEAM64_LENGTH 20

// 11 numbers is the total numbers that the 32 bit can hold, lets make sure its less than that by 1.
// 10 + terminator
#define MAX_INTEGERS 11

stock bool GetSteam32FromSteam64(const char szSteam64Original[MAX_STEAM64_LENGTH], int &iSteam32)
{
    char szSteam32[MAX_STEAM64_LENGTH];
    char szSteam64[MAX_STEAM64_LENGTH];
    
    // We don't want to actually edit the original string.
    // We make a new string for the editing.
    strcopy(szSteam64, sizeof szSteam64, szSteam64Original);
    
    
    // Remove the first three numbers
    int done = ReplaceStringEx(szSteam64, sizeof(szSteam64), "765", "");
    if (done == -1)return false;
    
    // Because pawn does not support numbers bigger than 2147483647, we will need to subtract using a combination of numbers.
    // The combination can be
    // 1 number to MAX_INTEGERS
    char szSubtractionString[] = "61197960265728";
    
    // First integer is the integer from szSteam64
    // Second is from the subtraction string szSubtractionString
    char szFirstInteger[MAX_INTEGERS], szSecondInteger[MAX_INTEGERS];
    int iFirstInteger, iSecondInteger;
    
    char szResultInt[MAX_INTEGERS];
    
    // Ugly hack
    // Make the strings 00000000000 so when we use StringToInt the zeroes won't affect the result
    // sizeof - 1 because we need the last End of string (0) byte;
    SetStringZeros(szFirstInteger, sizeof(szFirstInteger), sizeof(szFirstInteger) - 1);
    SetStringZeros(szSecondInteger, sizeof(szSecondInteger), sizeof(szSecondInteger) - 1);

    // Start from the end of the string, because subtraction should always start from the first number in the right.
    int iResultInt;
    
    int iSteam64Position = strlen(szSteam64);
    int iIntegerPosition = strlen(szFirstInteger);
    
    int iNumCount;
    int iResultLen;
    char szStringZeroes[MAX_INTEGERS];
    
    while(--iSteam64Position > -1)
    {
        iIntegerPosition -= 1;
        
        ++iNumCount;
        szFirstInteger[iIntegerPosition] = szSteam64[iSteam64Position];
        szSecondInteger[iIntegerPosition] = szSubtractionString[iSteam64Position];
        
        iFirstInteger = StringToInt(szFirstInteger);
        iSecondInteger = StringToInt(szSecondInteger);
            
        // Can we subtract without getting a negative number?
        if(iFirstInteger >= iSecondInteger)
        {
            iResultInt = iFirstInteger - iSecondInteger;
            // 69056897
            PrintToServer("Subtract %s from %s = %d", szFirstInteger, szSecondInteger, iResultInt);
            if(iResultInt)
            {
                IntToString(iResultInt, szResultInt, sizeof(szResultInt));
                
                if( iNumCount != (iResultLen  = strlen(szResultInt) ) )
                {
                    SetStringZeros(szStringZeroes, sizeof(szStringZeroes), iNumCount - iResultLen);
                }
                
                else
                {
                    szStringZeroes = "";
                }
            }
            
            else
            {
                szResultInt = "";
                
                SetStringZeros(szStringZeroes, sizeof(szStringZeroes), iNumCount);
                PrintToServer("String Zeroes: %s", szResultInt);
            }
            
            Format(szSteam32, sizeof(szSteam32), "%s%s%s", szStringZeroes, szResultInt, szSteam32);
            PrintToServer("Current Progress: %s", szSteam32);
            
            // Reset our stuff.
            SetStringZeros(szFirstInteger, sizeof(szFirstInteger), sizeof(szFirstInteger) - 1);
            SetStringZeros(szSecondInteger, sizeof(szSecondInteger), sizeof(szSecondInteger) - 1);
            
            iIntegerPosition = strlen(szFirstInteger);
            iNumCount = 0;
        }
        
        if(iIntegerPosition - 1 < 0)
        {
            // We failed, and this calculation can not be done in pawn.
            return false;
        }
        
        // if not, lets add more numbers.
    }
    
    iSteam32 = StringToInt(szSteam32);
    return true;
}

void SetStringZeros(char[] szString, int iSize, int iNumZeros)
{
    int i;
    for(i = 0; i < iNumZeros && i < iSize; i++)
    {
        szString[i] = '0';
    }
    
    szString[i] = 0;
}  