#pragma semicolon 1

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <hitmancsgo>

#pragma newdecls required
#define HITMAN_PREFIX "[\x04HitmanGO\x01]"
EngineVersion g_Game;
Database g_Stats;

ConVar g_MinimumPlayersToRecordStats;
ConVar g_RowsToFetch;

public Plugin myinfo = 
{
	name = "Hitmancsgo SQL Stats",
	author = PLUGIN_AUTHOR,
	description = "Records stats in a MySQL database",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rachnus"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");	
	}
	g_MinimumPlayersToRecordStats = CreateConVar("hitmancsgosql_minimum_players_to_record_stats", "4", "Amount of players there need to be on server to record stats");
	g_RowsToFetch = 				CreateConVar("hitmancsgosql_rows_to_fetch", "5", "Amount of players to show on top hitmen menu");
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	
	RegConsoleCmd("sm_tophitmen", Command_TopHitmen);
	
	Database.Connect(SQLConnection_Callback, "hitmancsgo");
}

/*************
 * CALLBACKS *
 *************/
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(g_Stats == null)
		return Plugin_Continue;

	if(GetClientCountWithoutBots() >= g_MinimumPlayersToRecordStats.IntValue)
	{
		Transaction t = SQL_CreateTransaction();
		int hitman = HitmanGO_GetHitman();
		int hitmankiller = HitmanGO_GetHitmanKiller();
		char szQuery[4096], authid[32];
		if(hitman > 0 && hitman <= MaxClients)
		{
			if(IsClientInGame(hitman) && !IsFakeClient(hitman))
			{
				int playersonroundstart = HitmanGO_GetRoundStartPlayers();
				int targetkills = HitmanGO_GetTargetKills();
				int nontargetkills = HitmanGO_GetNonTargetKills();
				bool hitmanspotted = HitmanGO_HasHitmanBeenSpotted();
				GetClientAuthId(hitman, AuthId_Engine, authid, sizeof(authid));
				
				Format(szQuery, sizeof(szQuery), "UPDATE `hitmancsgo_stats` \
												  SET name='%N', targetkills = targetkills + %d, nontargetkills = nontargetkills + %d, \
												  hitmanlosses = hitmanlosses + %d, hitmanwins = hitmanwins + %d, flawlesswins = flawlesswins + %d \
												  WHERE steamid='%s'",
												  hitman, targetkills, nontargetkills, (GetAliveCount() > 1)?1:(IsPlayerAlive(hitman)?0:1),(GetAliveCount() > 1)?0:(IsPlayerAlive(hitman)?1:0),
												  (!hitmanspotted && targetkills >= playersonroundstart)?1:0,authid);
				t.AddQuery(szQuery);
			}
		}
		
		if(hitmankiller > 0 && hitmankiller <= MaxClients && hitmankiller != hitman)
		{
			if(IsClientInGame(hitmankiller) && !IsFakeClient(hitmankiller))
			{
				GetClientAuthId(hitmankiller, AuthId_Engine, authid, sizeof(authid));
				
				Format(szQuery, sizeof(szQuery), "UPDATE `hitmancsgo_stats` \
												  SET name='%N', hitmenkilled = hitmenkilled + %d WHERE steamid='%s'",
												  hitmankiller, 1, authid);
				t.AddQuery(szQuery);
			}
		}
		g_Stats.Execute(t,_,StoringStatsFailure);
	}
	else
		PrintToChatAll("%s There need to be atleast \x04%d\x01 players ingame to record stats", HITMAN_PREFIX, g_MinimumPlayersToRecordStats.IntValue);
	
	
	return Plugin_Continue;
}

public void SQLConnection_Callback(Database db, const char[] error, any data)
{
	if (db == null)
		SetFailState("Could not connect to hitmancsgo database");
	else
	{
		g_Stats = db;
		g_Stats.SetCharset("utf8");
		CreateTables();
	}
}

public void TableCreationFailure(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData) 
{
	LogError("Failed table creation query, error = %s", error);
}

public void StoringStatsFailure(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData) 
{
	LogError("Failed storing stats query, error = %s", error);
}

public void SQLQuery_Void(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogError("Error (%i): %s", data, error);
	}
}

public void SQLQuery_TopHitmen(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogError("Error (%i): %s", data, error);
	}
	
	if (results == null)
	{
		LogError(error);
		return;
	}
	
	int client = GetClientOfUserId(data);
	if(client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			if (results.RowCount == 0)
			{
				PrintToChat(client, "%s There are no worthy hitmen!", HITMAN_PREFIX);
				return;
			}
			int rows = g_RowsToFetch.IntValue;
			int rank = 0;
			Menu menu = new Menu(TopHitmenMenuHandler);
			menu.SetTitle("Top Hitmen");
			
			char authid[32];
			char name[MAX_NAME_LENGTH];
			char temp[40 + MAX_NAME_LENGTH];
			int wins = 0;
			while (results.FetchRow() && rows > 0)
			{
				rows--;
				rank++;
				results.FetchString(0, authid, sizeof(authid));
				results.FetchString(1, name, sizeof(name));
				wins = results.FetchInt(5);
				Format(temp, sizeof(temp), "%d - %s - %d Wins - (%s)", rank, name, wins, authid);

				menu.AddItem(authid, temp);
			}
			
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public void SQLQuery_HitmanStats(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogError("Error (%i): %s", data, error);
	}
	
	if (results == null)
	{
		LogError(error);
		return;
	}
	int client = GetClientOfUserId(data);
	if(client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			if (results.RowCount == 0)
			{
				PrintToChat(client, "%s There are no worthy hitmen!", HITMAN_PREFIX);
				return;
			}
			char authid[32];
			char name[MAX_NAME_LENGTH];
			char temp[64];
			int targetskilled = 0;
			int nontargetskilled = 0;
			int hitmenkilled = 0;
			int hitmanwins = 0;
			int hitmanlosses = 0;
			int flawlesswins = 0;
			int lastseen = 0;
			results.FetchRow();
			results.FetchString(0, authid, sizeof(authid));
			results.FetchString(1, name, sizeof(name));
			targetskilled = results.FetchInt(2);
			nontargetskilled = results.FetchInt(3);
			hitmenkilled = results.FetchInt(4);
			hitmanwins = results.FetchInt(5);
			hitmanlosses = results.FetchInt(6);
			flawlesswins = results.FetchInt(7);
			lastseen = results.FetchInt(8);
			
			Menu menu = new Menu(HitmanStatsMenuHandler);
			menu.SetTitle(name);
			
			Format(temp, sizeof(temp), "SteamID: %s", authid);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Target Kills: %d", targetskilled);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Non-Target Kills: %d", nontargetskilled);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Hitmen Kills: %d", hitmenkilled);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Hitman Wins: %d", hitmanwins);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Hitman Losses: %d", hitmanlosses);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);

			Format(temp, sizeof(temp), "Flawless Hitman Wins: %d", flawlesswins);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			FormatTime(temp, sizeof(temp), "Last Seen: %x", lastseen);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			menu.ExitButton = true;
			menu.ExitBackButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
			//delete menu;
		}
	}
}

public void SQLQuery_HitmanCommandStats(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogError("Error (%i): %s", data, error);
	}
	
	if (results == null)
	{
		LogError(error);
		return;
	}
	int client = GetClientOfUserId(data);
	if(client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			if (results.RowCount == 0)
			{
				PrintToChat(client, "%s There is no hitman with that SteamID!", HITMAN_PREFIX);
				PrintToChat(client, "%s Usage sm_tophitmen <steamid|name|#userid>", HITMAN_PREFIX);
				return;
			}
			char authid[32];
			char name[MAX_NAME_LENGTH];
			char temp[64];
			int targetskilled = 0;
			int nontargetskilled = 0;
			int hitmenkilled = 0;
			int hitmanwins = 0;
			int hitmanlosses = 0;
			int flawlesswins = 0;
			int lastseen = 0;
			results.FetchRow();
			results.FetchString(0, authid, sizeof(authid));
			results.FetchString(1, name, sizeof(name));
			targetskilled = results.FetchInt(2);
			nontargetskilled = results.FetchInt(3);
			hitmenkilled = results.FetchInt(4);
			hitmanwins = results.FetchInt(5);
			hitmanlosses = results.FetchInt(6);
			flawlesswins = results.FetchInt(7);
			lastseen = results.FetchInt(8);
			
			Menu menu = new Menu(HitmanStatsMenuHandler);
			menu.SetTitle(name);
			
			Format(temp, sizeof(temp), "SteamID: %s", authid);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Target Kills: %d", targetskilled);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Non-Target Kills: %d", nontargetskilled);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Hitmen Kills: %d", hitmenkilled);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Hitman Wins: %d", hitmanwins);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			Format(temp, sizeof(temp), "Hitman Losses: %d", hitmanlosses);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);

			Format(temp, sizeof(temp), "Flawless Hitman Wins: %d", flawlesswins);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			FormatTime(temp, sizeof(temp), "Last Seen: %x", lastseen);
			menu.AddItem("", temp, ITEMDRAW_DISABLED);
			
			menu.ExitButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
			//delete menu;
		}
	}
}

public int HitmanStatsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	switch(param2)
	{
		case MenuCancel_ExitBack:
		{
			Command_TopHitmen(param1, 0);
		}
	}
}

public int TopHitmenMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szInfo[300];
			char szQuery[300];
			GetMenuItem(menu, param2, szInfo, sizeof(szInfo));
			Format(szQuery, sizeof(szQuery), "SELECT * FROM hitmancsgo_stats WHERE steamid='%s'", szInfo);
			g_Stats.Query(SQLQuery_HitmanStats, szQuery, GetClientUserId(param1));
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action Command_TopHitmen(int client, int args)
{
	if(g_Stats == null)
	{
		PrintToChat(client, "%s Plugin not loaded yet, wait a second", HITMAN_PREFIX);
		return Plugin_Handled;
	}
		
	if(args == 0)
	{
		g_Stats.Query(SQLQuery_TopHitmen, "SELECT * FROM hitmancsgo_stats ORDER BY hitmanwins DESC", GetClientUserId(client));
	}
	else if(args > 0)
	{
		char arg[32], szQuery[512];
		GetCmdArgString(arg, sizeof(arg));
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS + 1];
		int target_count;
		
		bool tn_is_ml;
	
		target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS + 1,
				COMMAND_FILTER_CONNECTED,
				target_name,
				sizeof(target_name),
				tn_is_ml);
				
		if(target_count > 1)
		{
			ReplyToCommand(client, "%s Command can only be used on 1 client!", HITMAN_PREFIX);
		}
		if(target_count == 1)
		{
			char authid[32];
			GetClientAuthId(target_list[0], AuthId_Engine, authid, sizeof(authid));
			Format(szQuery, sizeof(szQuery), "SELECT * FROM hitmancsgo_stats WHERE steamid='%s'", authid);
			g_Stats.Query(SQLQuery_HitmanCommandStats, szQuery, GetClientUserId(client));
		}
		else
		{
			Format(szQuery, sizeof(szQuery), "SELECT * FROM hitmancsgo_stats WHERE steamid='%s'", arg);
			g_Stats.Query(SQLQuery_HitmanCommandStats, szQuery, GetClientUserId(client));
		}
	}

	return Plugin_Handled;
}

/*************
 * FUNCTIONS *
 *************/
stock void CreateTables()
{
	char szQuery[4096];
	Transaction t = SQL_CreateTransaction();
	//Stats per round
	Format(szQuery, sizeof(szQuery), "CREATE TABLE IF NOT EXISTS `hitmancsgo_stats` ( \	
									  `steamid` varchar(32) NOT NULL, \
									  `name` varchar(32) NOT NULL, \
									  `targetkills` int(10) unsigned NOT NULL, \
									  `nontargetkills` int(10) unsigned NOT NULL, \
									  `hitmenkilled` int(10) unsigned NOT NULL, \
									  `hitmanwins` int(10) unsigned NOT NULL, \
									  `hitmanlosses` int(10) unsigned NOT NULL, \
									  `flawlesswins` int(10) unsigned NOT NULL, \
									  `lastseen` int(32) NOT NULL, \
									  PRIMARY KEY (`steamid`) \
									) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;");  
	t.AddQuery(szQuery);
	g_Stats.Execute(t,_,TableCreationFailure);
}

stock int GetClientCountWithoutBots()
{
	int count = 0;
	for (int i = 1; i <= MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			if((GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) && !IsFakeClient(i))
				count++;
		}
	}
	return count;
}

stock int GetAliveCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT))
			count++;
	}
	return count;
}

stock int GetAliveCountWithoutBots()
{
	int count = 0;
	for (int i = 1; i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT))
			count++;
	}
	return count;
}

/*************
 * FORWARDS  *
 *************/
 
public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
	{
		char szQuery[4096], authid[32];
		GetClientAuthId(client, AuthId_Engine, authid, sizeof(authid));
		Format(szQuery, sizeof(szQuery), "INSERT IGNORE INTO `hitmancsgo_stats` \
															 (steamid, name, lastseen) VALUES \
															 ('%s', '%N', %d)",
															 authid, client, GetTime());
		g_Stats.Query(SQLQuery_Void, szQuery);
	}
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		char szQuery[4096], authid[32];
		GetClientAuthId(client, AuthId_Engine, authid, sizeof(authid));
		Format(szQuery, sizeof(szQuery), "UPDATE `hitmancsgo_stats` \
										  SET name='%N', lastseen=%d WHERE steamid='%s'",
											 client, GetTime(), authid);
		g_Stats.Query(SQLQuery_Void, szQuery);
	}
}