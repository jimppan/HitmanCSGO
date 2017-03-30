#pragma semicolon 1

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.04"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <dhooks>
#include <emitsoundany>
#include <clientprefs>

#pragma newdecls required

EngineVersion g_Game;
#define HITMAN_PREFIX "[\x04HitmanGO\x01]"
#define HIDE_RADAR 1<<12
#define GRAB_DISTANCE 100.0
#define SLOWMO_AMOUNT 0.4

#define AGENT47_MODEL "models/player/custom_player/voikanaa/hitman/agent47.mdl"
#define AGENT47_HEARTBEAT "hitmancsgo/heartbeat.mp3"
#define AGENT47_LOCATED "hitmancsgo/located.mp3"
#define AGENT47_SPOTTED "hitmancsgo/spotted.mp3"
#define AGENT47_DISGUISE "hitmancsgo/disguise.mp3"
#define AGENT47_SELECTED "hitmancsgo/selected.mp3"
#define MINE_ACTIVE "hitmancsgo/mine_activate.mp3"
#define MINE_EXPLODE "weapons/sensorgrenade/sensor_explode.wav"
#define TIMER_SOUND "buttons/button17.wav"
#define MINE_DEPLOY_VOLUME 0.1
#define MINE_EXPLOSION_VOLUME 1.0
#define MODEL_BEAM	"materials/sprites/purplelaser1.vmt"
#define FOCUS_ACTIVE "ambient/atmosphere/underground.wav"

#define IDENTITY_SCAN_SOUND "buttons/blip2.wav"
#define IDENTITY_SCAN_VOLUME 1.0

//HITMAN VARIABLES
int g_iLastHitman = INVALID_ENT_REFERENCE;
int g_iHitman = INVALID_ENT_REFERENCE;
int g_iHitmanGlow = INVALID_ENT_REFERENCE;
int g_iHitmanTarget = INVALID_ENT_REFERENCE;
int g_iHitmanTargetGlow = INVALID_ENT_REFERENCE;
int g_iHitmanKiller = INVALID_ENT_REFERENCE;
int g_iHitmanTimer = 0;
int g_iHitmanTripmines = 0;
int g_iHitmanMaxTripmines = 0;
int g_iHitmanDecoys = 0;
int g_iHitmanMaxDecoys = 0;
int g_iHitmanTargetKills = 0;
int g_iHitmanNonTargetKills = 0;
bool g_bHasHitmanBeenSpotted = false;
bool g_bIsHitmanSeen = false;
bool g_bHitmanWasSeen = false;
bool g_bHitmanWasInOpen = false;
bool g_bHitmanPressedAttack1 = false;
bool g_bHitmanPressedUse = false;
bool g_bHitmanPressedWalk = false;
bool g_bFocusMode = false;
float g_iHitmanFocusTicksStart = 0.0;
float g_iHitmanTickCounter = 0.0;
float g_iHitmanGlobalTickCounter = 0.0;
float g_iHitmanFocusTime = 5.0;
float g_flTimeScaleGoal = 0.0;
char g_iHitmanDisguise[MAX_NAME_LENGTH];

//OTHER VARIABLES
int g_iDecoys[MAXPLAYERS + 1] =  { false, ... };
int g_iMaxDecoys;
int g_iGrabbed[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };
int g_iPlayersOnStart;
int g_iPathLaserModelIndex;
int g_iPathHaloModelIndex;
bool g_bNotifyHelp[MAXPLAYERS + 1] =  { false, ... };
bool g_bNotifyHitmanInfo[MAXPLAYERS + 1] =  { false, ... };
bool g_bNotifyTargetInfo[MAXPLAYERS + 1] =  { false, ... };
bool g_bPressedAttack2[MAXPLAYERS + 1] =  { false, ... };
bool g_bDidHitHitman[MAXPLAYERS + 1] =  { false, ... };
bool g_bPickingHitman = false;

ArrayList g_iRagdolls;
ArrayList g_iMines;
UserMsg g_BombText;
Handle g_PickHitmanTimer;
Handle g_hInaccuracy = INVALID_HANDLE;
Handle g_hNotifyHelp = INVALID_HANDLE;
Handle g_hNotifyHitmanInfo = INVALID_HANDLE;
Handle g_hNotifyTargetInfo = INVALID_HANDLE;
KeyValues g_Weapons;

//CONVARS
ConVar g_TimeUntilHitmanChosen;
ConVar g_MaxFocusTime;
ConVar g_RoundEndTime;
ConVar g_FocusPerKill;
ConVar g_FocusActivateCost;
ConVar g_DamagePenalty;
ConVar g_PenaltyType;
ConVar g_RagdollLimit;
ConVar g_MineExplosionRadius;
ConVar g_MineExplosionDamage;
ConVar g_IdentityScanRadius;
ConVar g_AllowTargetsGrabRagdoll;
ConVar g_HelpNoticeTime;
ConVar g_InfiniteFocusWhenAlone;
ConVar g_HitmanArmor;
ConVar g_HitmanHasHelmet;
ConVar g_TargetsArmor;
ConVar g_TargetsHaveHelmet;
ConVar g_DisguiseOnStart;
ConVar g_PunishOnFriendlyFire;
ConVar g_PunishOnFriendlyFireDamage;

//FIND CONVARS
ConVar g_cvarTimescale;
ConVar g_cvarCheats;
ConVar g_cvarSpread;

//FORWARDS
Handle g_hOnPickHitman;
Handle g_hOnPickHitmanTarget;

public Plugin myinfo = 
{
	name = "Hitman Mod CS:GO v1.04",
	author = PLUGIN_AUTHOR,
	description = "A hitman mode for CS:GO",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rachnus"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO");	
	}
	//CONVARS
	g_TimeUntilHitmanChosen =	 	CreateConVar("hitmancsgo_time_until_hitman_chosen", "20", "Time in seconds until a hitman is chosen on round start");
	g_MaxFocusTime =			 	CreateConVar("hitmancsgo_max_slowmode_time", "5", "Maximum time in seconds hitman can use slowmode");
	g_RoundEndTime =			 	CreateConVar("hitmancsgo_round_end_timer", "3", "Time in seconds until next round starts after round ends when hitman is killed or targets killed");
	g_FocusPerKill =			 	CreateConVar("hitmancsgo_focus_per_kill", "0.20", "Amount of focus to gain in % (percentage) (0.0 - 1.0)");
	g_FocusActivateCost = 		 	CreateConVar("hitmancsgo_focus_activate_cost", "0.10", "Amount of focus to use when walk buttin is first pressed (To prevent from focus spamming)");
	g_DamagePenalty = 			 	CreateConVar("hitmancsgo_damage_penalty", "25", "Amount of damage to hurt hitman if wrong target was killed");
	g_PenaltyType = 			 	CreateConVar("hitmancsgo_penalty_type", "1", "0 = No punishment, 1 = Punish hitman on wrong target kill using hitmancsgo_damage_penalty, 2 = Reflect the damage onto hitman if wrong target was shot",0,true,0.0,true,2.0);
	g_RagdollLimit = 			 	CreateConVar("hitmancsgo_ragdoll_limit", "10", "Amount of server side ragdolls there can be (Lower this if server starts lagging)");
	g_MineExplosionRadius =		 	CreateConVar("hitmancsgo_explosion_radius", "600", "Tripmine explosion radius");
	g_MineExplosionDamage =		 	CreateConVar("hitmancsgo_explosion_damage", "500", "Tripmine explosion damage (magnitude)");
	g_IdentityScanRadius = 		 	CreateConVar("hitmancsgo_identity_scan_radius", "400", "Identity scan grenade radius");
	g_AllowTargetsGrabRagdoll =  	CreateConVar("hitmancsgo_allow_targets_grab_ragdolls", "0", "Allow non hitmen to grab ragdolls (Might cause lag if many players grab ragdolls)");
	g_HelpNoticeTime = 			 	CreateConVar("hitmancsgo_notice_timer", "20", "Time in seconds to notify players gamemode information");
	g_InfiniteFocusWhenAlone =   	CreateConVar("hitmancsgo_infinite_focus_when_alone", "1", "If theres only 1 player on server, give him infinite focus");
	g_HitmanArmor = 			 	CreateConVar("hitmancsgo_hitman_armor", "100", "Amount of armor hitman should have");
	g_HitmanHasHelmet =			 	CreateConVar("hitmancsgo_hitman_has_helmet", "1", "Should hitman have helmet");
	g_TargetsArmor =			 	CreateConVar("hitmancsgo_targets_armor", "100", "Amount of armor targets should have");
	g_TargetsHaveHelmet = 		 	CreateConVar("hitmancsgo_targets_have_helmet", "0", "Should targets have helmets");
	g_DisguiseOnStart =			 	CreateConVar("hitmancsgo_disguise_hitman_on_round_start", "1", "Should the hitman be disguised on round start");
	g_PunishOnFriendlyFire =	 	CreateConVar("hitmancsgo_punish_on_friendly_fire", "1", "Should targets get damaged if they kill another target?");
	g_PunishOnFriendlyFireDamage =	CreateConVar("hitmancsgo_punish_on_friendly_fire_damage", "50.0", "Amount of damage to deal if 'hitmancsgo_punish_on_friendly_fire' is set to 1");
	
	Handle hConf = LoadGameConfigFile("hitmancsgo.games");
	int InaccuracyOffset = GameConfGetOffset(hConf, "InaccuracyOffset");
	//DHOOK CWeaponCSBase::GetInaccuracy 460
	g_hInaccuracy = DHookCreate(InaccuracyOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, CWeaponCSBase_GetInaccuracy);
	
	g_hNotifyHelp = RegClientCookie("HMGO_Notify_Help", "Notify players gamemode instructions", CookieAccess_Public);
	g_hNotifyHitmanInfo =  RegClientCookie("HMGO_Notify_Hitman_Info", "Notify players hitman information", CookieAccess_Public);
	g_hNotifyTargetInfo =  RegClientCookie("HMGO_Notify_Target_Info", "Notify players target information", CookieAccess_Public);
	
	g_hOnPickHitman = CreateGlobalForward("HitmanGO_OnHitmanPicked", ET_Ignore, Param_Cell);
	g_hOnPickHitmanTarget = CreateGlobalForward("HitmanGO_OnHitmanTargetPicked", ET_Ignore, Param_Cell);

	//RegAdminCmd("sm_test", Command_Test, ADMFLAG_ROOT);
	RegAdminCmd("sm_hmgorefresh", Command_Refresh, ADMFLAG_ROOT, "Refresh weapons config");
	
	RegConsoleCmd("sm_help", Command_Help);
	RegConsoleCmd("sm_hmgohelp", Command_Help);
	RegConsoleCmd("sm_hitmaninfo", Command_HitmanInfo);
	RegConsoleCmd("sm_targetinfo", Command_TargetInfo);
	RegConsoleCmd("sm_hmgonotify", Command_Notify);
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("decoy_started", Event_DecoyStarted);
	HookEvent("decoy_firing", Event_DecoyFiring, EventHookMode_Post);
	HookEvent("round_prestart", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	AddCommandListener(OnCheatCommand, "addcond");
	AddCommandListener(OnCheatCommand, "removecond");
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	g_BombText = GetUserMessageId("TextMsg");
	HookUserMessage(g_BombText, UserMessageHook, true);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/hitmancsgo_weapons.cfg");
	g_Weapons = new KeyValues("weapons");
	
	if(!g_Weapons.ImportFromFile(path))
		SetFailState("Could not open %s", path);
	g_Weapons.SetEscapeSequences(true);
	
	g_cvarTimescale = FindConVar("host_timescale");
	g_cvarCheats = FindConVar("sv_cheats");
	g_cvarSpread = FindConVar("weapon_accuracy_nospread");

	SetConVarFlags(g_cvarCheats, GetConVarFlags(g_cvarCheats) & ~FCVAR_NOTIFY);
	SetConVarFlags(g_cvarTimescale, GetConVarFlags(g_cvarCheats) & ~FCVAR_NOTIFY);
	
	g_iRagdolls = new ArrayList();
	g_iMines = new ArrayList();
	
	char strConCommand[128];
	bool bIsCommand;
	int iFlags;
	Handle hSearch = FindFirstConCommand(strConCommand, sizeof(strConCommand), bIsCommand, iFlags);
	do
	{
		if(bIsCommand && (iFlags & FCVAR_CHEAT))
			AddCommandListener(OnCheatCommand, strConCommand);
			
	}while(FindNextConCommand(hSearch, strConCommand, sizeof(strConCommand), bIsCommand, iFlags));
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
	}
	AutoExecConfig(true, "hitmancsgo");
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	CreateNative("HitmanGO_GetHitman", Native_GetHitman);
	CreateNative("HitmanGO_GetHitmanKiller", Native_GetHitmanKiller);
	CreateNative("HitmanGO_HasHitmanBeenSpotted", Native_HasHitmanBeenSpotted);
	CreateNative("HitmanGO_GetCurrentHitmanTarget", Native_GetCurrentHitmanTarget);
	CreateNative("HitmanGO_GetRoundStartPlayers", Native_GetRoundStartPlayers);
	CreateNative("HitmanGO_GetTargetKills", Native_GetTargetKills);
	CreateNative("HitmanGO_GetNonTargetKills", Native_GetNonTargetKills);
	CreateNative("HitmanGO_IsHitmanSeen", Native_IsHitmanSeen);
	CreateNative("HitmanGO_IsValidHitman", Native_IsValidHitman);

	RegPluginLibrary("hitmancsgo");

	return APLRes_Success;
}

public int Native_GetHitman(Handle plugin, int numParams)
{
	int hitman = GetClientOfUserId(g_iHitman);
	return hitman;
}

public int Native_GetHitmanKiller(Handle plugin, int numParams)
{
	int hitmankiller = GetClientOfUserId(g_iHitmanKiller);
	return hitmankiller;
}

public int Native_HasHitmanBeenSpotted(Handle plugin, int numParams)
{
	return view_as<int>(g_bHasHitmanBeenSpotted);
}

public int Native_GetCurrentHitmanTarget(Handle plugin, int numParams)
{
	int hitmantarget = GetClientOfUserId(g_iHitmanTarget);
	return hitmantarget;
}

public int Native_GetRoundStartPlayers(Handle plugin, int numParams)
{
	return g_iPlayersOnStart;
}

public int Native_GetTargetKills(Handle plugin, int numParams)
{
	return g_iHitmanTargetKills;
}

public int Native_GetNonTargetKills(Handle plugin, int numParams)
{
	return g_iHitmanNonTargetKills;
}

public int Native_IsHitmanSeen(Handle plugin, int numParams)
{
	return view_as<int>(g_bIsHitmanSeen);
}

public int Native_IsValidHitman(Handle plugin, int numParams)
{
	return view_as<int>(IsValidHitman());
}

/*************
 * CALLBACKS *
 *************/
 
//Remove bomb pickup/bomb drop notification
public Action UserMessageHook(UserMsg msg_id, Handle pb, const int[] players, int playersNum, bool reliable, bool init)
{
	if(msg_id == g_BombText)
	{
		int msgindex = PbReadInt(pb, "msg_dst");
		if(msgindex == 4)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}  

//Called when getting weapon inaccuracy
public MRESReturn CWeaponCSBase_GetInaccuracy(int pThis, Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, 0.0);
	return MRES_Supercede;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetVariables();
	TransferPlayersToT();
	g_bPickingHitman = true;
	if(GetClientCountWithoutBots() > 0)
	{
		if(g_PickHitmanTimer != INVALID_HANDLE)
			KillTimer(g_PickHitmanTimer);
		g_PickHitmanTimer = CreateTimer(1.0, Timer_PickHitman, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ExecuteGamemodeCvars()
{
	SetConVarInt(FindConVar("mp_playerid"), 0);
	SetConVarInt(FindConVar("mp_friendlyfire"), 1);
	SetConVarInt(FindConVar("mp_autoteambalance"), 0);
	SetConVarInt(FindConVar("mp_teammates_are_enemies"), 1);
	SetConVarInt(FindConVar("sv_deadtalk"), 0);
	SetConVarInt(FindConVar("sv_alltalk"), 1);
	SetConVarInt(FindConVar("sv_show_team_equipment_prohibit"), 0);
	SetConVarInt(FindConVar("sv_occlude_players"), 0);	
	SetConVarInt(FindConVar("mp_respawn_on_death_t"), 0);
	SetConVarInt(FindConVar("mp_respawn_on_death_ct"), 0);
	SetConVarInt(FindConVar("mp_default_team_winner_no_objective"), 3);
	SetConVarInt(FindConVar("mp_warmuptime"), 20);
	SetConVarInt(FindConVar("mp_buytime"), 0);
	SetConVarInt(FindConVar("mp_buy_anywhere"), 0);
	SetConVarInt(FindConVar("bot_quota"), 0);
	SetConVarInt(FindConVar("mp_solid_teammates"), 1);
	SetConVarInt(FindConVar("sv_talk_enemy_living"), 1);
	SetConVarInt(FindConVar("sv_ignoregrenaderadio"), 1);
	SetConVarInt(FindConVar("mp_randomspawn"), 0);
	SetConVarInt(FindConVar("mp_spawnprotectiontime"), 0);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	DisableSlowmo();
	int hitman = GetClientOfUserId(g_iHitman);
	
	if(IsValidHitman(true))
	{
		if(GetAliveCount() > 1)
		{
			//TARGETS WIN
			PrintToChatAll("Player '\x03%N\x01' \x02failed \x01to assassinate all targets!", hitman);
		}
		else
		{
			if(IsPlayerAlive(hitman))
			{
				if((g_iHitmanTargetKills + g_iHitmanNonTargetKills) >= g_iPlayersOnStart)
					PrintToChatAll("Player '\x03%N\x01' \x04successfully \x01eliminated all targets!", hitman);
				else
					PrintToChatAll("Player '\x03%N\x01' \x04successfully \x01managed to get all targets eliminated!", hitman);
			}
			else
			{
				PrintToChatAll("Player '\x03%N\x01' \x02failed \x01to assassinate all targets!", hitman);
			}
		}
		
		PrintToChatAll(" \x04》\x01Target Kills: \x03%d", g_iHitmanTargetKills);
		PrintToChatAll(" \x04》\x01Non-Target Kills: \x03%d", g_iHitmanNonTargetKills);
	}
	g_iLastHitman = g_iHitman;
	ResetVariables();
}

public Action Timer_PickHitman(Handle timer, any entref)
{
	PrintHintTextToAll("<font size='30' color='#FFA500' face=''>Picking Hitman In: <font color='#00FF00'>%d</font>", --g_iHitmanTimer);
	
	if(g_iHitmanTimer < -1)
	{
		g_PickHitmanTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if(g_iHitmanTimer <= 0)
	{
		g_bPickingHitman = false;
		PickHitman();
		PickHitmanTarget();
		g_PickHitmanTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	EmitSoundToAllAny(TIMER_SOUND, _, SNDCHAN_STATIC,_,_,0.2);
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int hitman = GetClientOfUserId(g_iHitman);
	int hitmantarget = GetClientOfUserId(g_iHitmanTarget);
	g_iGrabbed[client] = INVALID_ENT_REFERENCE;
	if(attacker == hitman && client == hitmantarget)
	{
		g_iHitmanTargetKills++;
		g_iHitmanFocusTime += (g_FocusPerKill.FloatValue * g_MaxFocusTime.FloatValue);
		g_iHitmanGlobalTickCounter -= (g_FocusPerKill.FloatValue * g_MaxFocusTime.FloatValue);
		if(g_iHitmanFocusTime > g_MaxFocusTime.FloatValue)
		{
			g_iHitmanFocusTime = g_MaxFocusTime.FloatValue;
			g_iHitmanGlobalTickCounter = 0.0;
		}
	}
	else if(attacker == hitman && client != hitmantarget && client != hitman)
	{
		g_iHitmanNonTargetKills++;
		if(g_PenaltyType.IntValue == 1 && !g_bDidHitHitman[client])
		{
			SDKHooks_TakeDamage(hitman, 0, 0, g_DamagePenalty.FloatValue, DMG_SHOCK);
			int health = GetEntProp(hitman, Prop_Data, "m_iHealth");
			if(g_DamagePenalty.IntValue >= health)
				PrintHintText(hitman, "<font size='20' color='#FF0000' face=''>Warning: <font>You've died!\nKilling wrong targets backfires.</font>");
			else
				PrintHintText(hitman, "<font size='20' color='#FF0000' face=''>Warning: <font>You've lost %d health!\nKilling wrong targets backfires.</font>", g_DamagePenalty.IntValue);
		}
	}
	
	if(attacker != hitman && client != hitman && g_PunishOnFriendlyFire.BoolValue)
		SDKHooks_TakeDamage(attacker, 0, 0, g_PunishOnFriendlyFireDamage.FloatValue);
	
	if(client == hitman)
	{	
		g_iHitmanKiller = GetClientUserId(attacker);
		StopSoundAny(hitman, SNDCHAN_AUTO, AGENT47_HEARTBEAT);
		int hitmanglow = EntRefToEntIndex(g_iHitmanGlow);
		if(hitmanglow != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(hitmanglow, "Kill");
			g_iHitmanGlow = INVALID_ENT_REFERENCE;
		}	
		if(GetClientCountWithoutBots() > 0)
			CS_TerminateRound(g_RoundEndTime.FloatValue, CSRoundEnd_CTWin, false);
		return Plugin_Continue;
	}
	
	if(client == hitmantarget)
	{
		CleanUpRagdolls();

		int glow = EntRefToEntIndex(g_iHitmanTargetGlow);
		if(glow != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(glow, "Kill");
			g_iHitmanTargetGlow = INVALID_ENT_REFERENCE;
		}
		
		float pos[3], angles[3];
		GetClientAbsAngles(client, angles);
		GetClientAbsOrigin(client, pos);
		char modelName[PLATFORM_MAX_PATH], clientName[MAX_NAME_LENGTH];
		GetClientModel(client, modelName, sizeof(modelName));
		GetClientName(client, clientName, sizeof(clientName));
		int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		int serverdoll = CreateEntityByName("prop_ragdoll");
		g_iRagdolls.Push(EntIndexToEntRef(serverdoll));
		if(ragdoll != INVALID_ENT_REFERENCE)
			AcceptEntityInput(ragdoll, "Kill");
		
		DispatchKeyValue(serverdoll, "targetname", clientName);
		DispatchKeyValue(serverdoll, "model", modelName);
		DispatchKeyValue(serverdoll, "spawnflags", "4");
		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", serverdoll);
		SetEntityModel(serverdoll, modelName);
		DispatchSpawn(serverdoll);
		TeleportEntity(serverdoll, pos, angles, NULL_VECTOR);
	
		//int forcebone = GetEntProp(client, Prop_Send, "m_nForceBone");
		//SetEntProp(ragdoll, Prop_Send, "m_nForceBone", forcebone);

		//SetEntProp(serverdoll, Prop_Send, "m_nSolidType", 0x0010);
		//SetEntProp(serverdoll, Prop_Send, "m_CollisionGroup", 0);

		/*int iFlags = GetEntProp(serverdoll, Prop_Send, "m_fEffects");
		flagstest = iFlags;
		SetEntProp(serverdoll, Prop_Send, "m_fEffects", iFlags | (1 << 0) | (1 << 4) | (1 << 6) | (1 << 9));
		
		SetVariantString("!activator");
		AcceptEntityInput(serverdoll, "SetParent", client);
		SetVariantString("primary");
		AcceptEntityInput(serverdoll, "SetParentAttachment", serverdoll);  

		RequestFrame(UnmergeCallback, serverdoll);
		*/

		if(!PickHitmanTarget())
		{
			if(GetClientCountWithoutBots() > 0)
				CS_TerminateRound(g_RoundEndTime.FloatValue, CSRoundEnd_TerroristWin, false);
		}
	}
	
	event.BroadcastDisabled = true;
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int hitman = GetClientOfUserId(g_iHitman);
	int hitmantarget = GetClientOfUserId(g_iHitmanTarget);
	if(victim == hitman)
		g_bDidHitHitman[attacker] = true;
			
	if(g_PenaltyType.IntValue == 2)
	{
		if(attacker == hitman && victim != hitmantarget && !g_bDidHitHitman[victim])
		{
			int dmgdealt = event.GetInt("dmg_health");
			float dmgfloat = float(dmgdealt); //weird as fuck
			int health = GetEntProp(hitman, Prop_Data, "m_iHealth");
			SDKHooks_TakeDamage(hitman, 0, 0, dmgfloat, DMG_SHOCK);
			if(dmgdealt >= health)
				PrintHintText(hitman, "<font size='20' color='#FF0000' face=''>Warning: <font>You've died!\nHurting wrong targets backfires.</font>");
			else
				PrintHintText(hitman, "<font size='20' color='#FF0000' face=''>Warning: <font>You've lost %d health!\nHurting wrong targets backfires.</font>", dmgdealt);
		}
	}
}

/*
public void UnmergeCallback(any data)
{
	int ent = EntRefToEntIndex(g_iHitmanGlow);
	if(ent != INVALID_ENT_REFERENCE)
	{	
		AcceptEntityInput(ent, "ClearParent");
	}
	//SetEntProp(serverdoll, Prop_Send, "m_fEffects", flagstest);
	//AcceptEntityInput(serverdoll, "ClearParent");
	//DispatchKeyValue(serverdoll, "spawnflags", "0");
}*/
 
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bDidHitHitman[client] = false;
	if(!IsFakeClient(client))
		RequestFrame(HideRadar, client);
	
	StripWeapons(client);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int hitman = GetClientOfUserId(g_iHitman);
	
	if(client == hitman && !g_bIsHitmanSeen)
	{
		char weaponName[64];
		event.GetString("weapon", weaponName, sizeof(weaponName));
		   
		int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		bool silencer = (!!GetEntProp(weapon, Prop_Send, "m_bSilencerOn") || 
						   StrContains(weaponName, "bayonet", false) != -1 || 
						   StrContains(weaponName, "knife", false) != -1 ||
						   StrContains(weaponName, "decoy", false) != -1);
		if(!silencer)
		{
			float pos[3], angles[3];
			GetClientAbsOrigin(client, pos);
			GetClientEyeAngles(client, angles);
			angles[2] = 0.0;
			angles[0] = 0.0;
			TeleportHitmanGlow(pos, angles);
		}
	}
}

public Action Event_DecoyStarted(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int hitman = GetClientOfUserId(g_iHitman);
	if(client == hitman)
	{
		float pos[3], angles[3];
		pos[0] = event.GetFloat("x");
		pos[1] = event.GetFloat("y");
		pos[2] = event.GetFloat("z");
		
		GetClientEyeAngles(hitman, angles);
		angles[2] = 0.0;
		angles[0] = 0.0;
		
		if(!g_bIsHitmanSeen)
			TeleportHitmanGlow(pos, angles);
	}
}

public Action Event_DecoyFiring(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int hitman = GetClientOfUserId(g_iHitman);
	if(client == hitman)
	{
		int ent = event.GetInt("entityid");
		if(ent != INVALID_ENT_REFERENCE)
			AcceptEntityInput(ent, "Kill");
	}
}

public void HideRadar(any client)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR);
}

public Action OnCheatCommand(int client, const char[] command, int argc)
{
	if(client <= 0)
		return Plugin_Continue;
	
	if(g_bFocusMode)
	{
		PrintToConsole(client, "Cheater!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Command_JoinTeam(int client, const char[] command, int args)
{
	char arg[PLATFORM_MAX_PATH];
	GetCmdArg(1, arg, sizeof(arg));
	int team = StringToInt(arg);
	if(team == CS_TEAM_SPECTATOR)
		return Plugin_Continue;
		
	if(IsPlayerAlive(client))
		return Plugin_Handled;
		
	CS_SwitchTeam(client, CS_TEAM_T);
	if(GetClientCountWithoutBots() == 2)
		ServerCommand("mp_restartgame 1");
	
	return Plugin_Handled;
}

public Action Command_Refresh(int client, int args)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/hitmancsgo_weapons.cfg");
	g_Weapons = new KeyValues("weapons");
	
	if(!g_Weapons.ImportFromFile(path))
		PrintToServer("[hitmancsgo.smx] Could not open %s", path);
		
	return Plugin_Handled;
}

public Action Command_Help(int client, int args)
{
	PrintToChat(client, "%s Type !hitmaninfo or !targetinfo for detailed information", HITMAN_PREFIX);
}

public Action Command_HitmanInfo(int client, int args)
{
	PrintHitmanInfo(client);
}

public Action Command_TargetInfo(int client, int args)
{
	PrintTargetInfo(client);
}

public Action Command_Notify(int client, int args)
{
	g_bNotifyHelp[client] = !g_bNotifyHelp[client];
	PrintToChat(client, "%s Notifications are now %s", HITMAN_PREFIX, (g_bNotifyHelp[client]) ? "\x02OFF":"\x04ON");
	SetClientCookie(client, g_hNotifyHelp, (g_bNotifyHelp[client]) ? "1":"0"); 
}

/*
public Action Command_Test(int client, int args)
{
	PrintToChat(client, "%d", GetEntProp(client, Prop_Data, "m_iTeamNum"));
}*/

public bool TraceFilterNotSelfAndParent(int entityhit, int mask, any entity)
{
	int parent = GetEntPropEnt(entity, Prop_Data, "m_hMoveParent");
	if(entityhit > 0 && entityhit != entity && entityhit != parent)
		return true;
	
	return false;
}

public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entityhit >= 0 && entityhit != entity)
		return true;
	
	return false;
}

public void OnThinkPostManager(int entity)
{
	for (int i = 0; i < MAXPLAYERS;i++)
	{
		SetEntProp(entity, Prop_Send, "m_bAlive", 1, _, i);
		SetEntProp(entity, Prop_Send, "m_iTeam", CS_TEAM_T, _, i);
		SetEntProp(entity, Prop_Send, "m_iPendingTeam", CS_TEAM_T, _, i);
	}
}

public Action SetTransmitTarget(int entity, int client)
{
	// Show target if hitman
	if(!IsValidHitman())
		return Plugin_Handled;
	int hitman = GetClientOfUserId(g_iHitman);
	return (client == hitman) ? Plugin_Continue : Plugin_Handled;
}

public Action SetTransmitHitman(int entity, int client)
{
	if(!IsValidHitman())
		return Plugin_Handled;
		
	// Show target if hitman
	int hitman = GetClientOfUserId(g_iHitman);
	return (client != hitman) ? Plugin_Continue : Plugin_Handled;
}

public Action OnPostThinkPost(int client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
	int entity = EntRefToEntIndex(g_iGrabbed[client]);
	if (entity != INVALID_ENT_REFERENCE)
	{
		float vecView[3], vecFwd[3], vecPos[3], vecVel[3];

		GetClientEyeAngles(client, vecView);
		GetAngleVectors(vecView, vecFwd, NULL_VECTOR, NULL_VECTOR);
		GetClientEyePosition(client, vecPos);
	
		vecPos[0] += vecFwd[0] * GRAB_DISTANCE;
		vecPos[1] += vecFwd[1] * GRAB_DISTANCE;
		vecPos[2] += vecFwd[2] * GRAB_DISTANCE;
		
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecFwd);
		SubtractVectors(vecPos, vecFwd, vecVel);
		char classname[PLATFORM_MAX_PATH];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(StrEqual(classname, "prop_ragdoll", false))
			ScaleVector(vecVel, 50.0);
		else
			ScaleVector(vecVel, 10.0);
		
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vecVel);
	}
}

public void OnClientWeaponSwitchPost(int client, int weaponid)
{
	int hitman = GetClientOfUserId(g_iHitman);
	if(client == hitman)
	{
		char classname[PLATFORM_MAX_PATH];
		GetEntityClassname(weaponid, classname, sizeof(classname));
		if(StrEqual(classname, "weapon_c4", false) ||
		   StrEqual(classname, "weapon_decoy", false))
		{
			PrintActiveHitmanSettings(classname);
		}	
	}
	else
	{
		char classname[PLATFORM_MAX_PATH];
		GetEntityClassname(weaponid, classname, sizeof(classname));
		if(StrEqual(classname, "weapon_decoy", false))
		{
			PrintActiveTargetSettings(client, classname);
		}
		else if(StrEqual(classname, "weapon_c4", false))
		{
			SDKHooks_DropWeapon(client, weaponid);
			AcceptEntityInput(weaponid, "Kill");
		}
	}
}

public Action OnDecoySpawned(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	int hitman = GetClientOfUserId(g_iHitman);
	if(owner > 0 && owner <= MaxClients)
	{
		if(owner == hitman)
		{
			g_iHitmanDecoys--;
			if(g_iHitmanDecoys > 0)
			{
				GivePlayerItem(owner, "weapon_decoy");
			}
			PrintActiveHitmanSettings("weapon_decoy");
		}
		else
		{
			g_iDecoys[owner]--;
			if(g_iDecoys[owner] > 0)
			{
				GivePlayerItem(owner, "weapon_decoy");
			}
			SDKHook(entity, SDKHook_TouchPost, DecoyTouchPost);
			PrintActiveTargetSettings(owner, "weapon_decoy");
		}
	}
	
	return Plugin_Continue;
}

public Action DecoyTouchPost(int entity, int other)
{
	if(other == 0)
	{
		if(IsValidHitman())
		{
			float pos[3];
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
			CreateIdentityScan(pos);
			AcceptEntityInput(entity, "Kill");
		}
		else
			return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void DownloadFilterCallback(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	if(!StrEqual(cvarValue, "all", false))
	{
		KickClient(client, "Change cl_downloadfilter to 'all'");
	}
}

/*************
 * FUNCTIONS *
 *************/
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

stock void CreateTargetGlowEntity(int target)
{
	char red[16] = "255 0 0 255";

	int glow = CreateEntityByName("prop_dynamic_override");
	g_iHitmanTargetGlow = EntIndexToEntRef(glow);
	SDKHook(glow, SDKHook_SetTransmit, SetTransmitTarget);
	
	char model[PLATFORM_MAX_PATH];
	GetClientModel(target, model, sizeof(model));
	DispatchKeyValue(glow, "model", model);
	DispatchKeyValue(glow, "disablereceiveshadows", "1");
	DispatchKeyValue(glow, "disableshadows", "1");
	DispatchKeyValue(glow, "solid", "0");
	DispatchKeyValue(glow, "spawnflags", "256");
	DispatchKeyValue(glow, "targetname", "red");
	DispatchSpawn(glow);
	
	SetEntProp(glow, Prop_Send, "m_bShouldGlow", true);
	SetEntPropFloat(glow, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	SetEntPropEnt(glow, Prop_Data, "m_hOwnerEntity", target);
	int iFlags = GetEntProp(glow, Prop_Send, "m_fEffects");
	SetEntProp(glow, Prop_Send, "m_fEffects", iFlags | (1 << 0) | (1 << 4) | (1 << 6) | (1 << 9));
	SetGlowColor(glow, red);
	SetVariantString("!activator");
	AcceptEntityInput(glow, "SetParent", target);
	SetVariantString("primary");
	AcceptEntityInput(glow, "SetParentAttachment", glow);  
}

stock void CreateHitmanGlowEntity(float pos[3], float angles[3], bool bonemerge = false)
{
	if(!IsValidHitman())
		return;
	int hitman = GetClientOfUserId(g_iHitman);
	
	char yellow[16] = "255 255 0 50";

	int glow = CreateEntityByName("prop_dynamic_override");
	SetEntityRenderMode(glow, RENDER_TRANSALPHA);
	SetEntityRenderColor(glow, 255, 255, 255, 50);
	g_iHitmanGlow = EntIndexToEntRef(glow);
	SDKHook(glow, SDKHook_SetTransmit, SetTransmitHitman);
	
	char model[PLATFORM_MAX_PATH];
	GetClientModel(hitman, model, sizeof(model));
	
	DispatchKeyValue(glow, "model", model);
	DispatchKeyValue(glow, "disablereceiveshadows", "1");
	DispatchKeyValue(glow, "disableshadows", "1");
	DispatchKeyValue(glow, "solid", "0");
	DispatchKeyValue(glow, "spawnflags", "8");
	DispatchKeyValue(glow, "targetname", "yellow");
	
	DispatchSpawn(glow);
	g_bHasHitmanBeenSpotted = true;
	SetEntProp(glow, Prop_Send, "m_bShouldGlow", true);
	SetEntPropFloat(glow, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	SetEntPropEnt(glow, Prop_Data, "m_hOwnerEntity", hitman);
	SetGlowColor(glow, yellow);
	if(bonemerge)
	{
		int iFlags = GetEntProp(glow, Prop_Send, "m_fEffects");
		SetEntProp(glow, Prop_Send, "m_fEffects", iFlags | (1 << 0) | (1 << 4) | (1 << 6) | (1 << 9));
		SetVariantString("!activator");
		AcceptEntityInput(glow, "SetParent", hitman);
		SetVariantString("primary");
		AcceptEntityInput(glow, "SetParentAttachment", glow);
	}
	
	EmitSoundToAllAny(AGENT47_LOCATED);
	EmitSoundToClientAny(hitman, AGENT47_SPOTTED);
	TeleportEntity(glow, pos, angles, NULL_VECTOR);
}

stock void TeleportHitmanGlow(float pos[3], float angles[3], bool bonemerge = false)
{
	if(!IsValidHitman())
		return;
		
	int hitman = GetClientOfUserId(g_iHitman);
	int glow = EntRefToEntIndex(g_iHitmanGlow);
	if(glow == INVALID_ENT_REFERENCE)
	{
		CreateHitmanGlowEntity(pos, angles, bonemerge);
	}
	else
	{
		char model[PLATFORM_MAX_PATH];
		GetClientModel(hitman, model, sizeof(model));
		SetEntityModel(glow, model);
		if(bonemerge)
		{
			int iFlags = GetEntProp(glow, Prop_Send, "m_fEffects");
			SetEntProp(glow, Prop_Send, "m_fEffects", iFlags | (1 << 0) | (1 << 4) | (1 << 6) | (1 << 9));
			SetVariantString("!activator");
			AcceptEntityInput(glow, "SetParent", hitman);
			SetVariantString("primary");
			AcceptEntityInput(glow, "SetParentAttachment", glow);
		}
		else
		{
			AcceptEntityInput(glow, "ClearParent");
		}
		TeleportEntity(glow, pos, angles, NULL_VECTOR);
	}
}

stock void TransferPlayersToT()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				CS_SwitchTeam(i, CS_TEAM_T);
				CS_RespawnPlayer(i);
			}
		}
	}
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

void PickHitman()
{
	ArrayList temp = new ArrayList();
	int lasthitman = GetClientOfUserId(g_iLastHitman);
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) != CS_TEAM_SPECTATOR)
		{
			if(GetClientCountWithoutBots() > 1)
			{
				if(i != lasthitman && !IsFakeClient(i))
					temp.Push(i);
			}
			else
			{
				if(!IsFakeClient(i))
					temp.Push(i);
			}
		}
	}
	
	if(temp.Length > 0)
	{
		int hitman = temp.Get(GetRandomInt(0, temp.Length - 1));
		Call_StartForward(g_hOnPickHitman);
		Call_PushCell(hitman);
		Call_Finish();
		g_iHitman = GetClientUserId(hitman);
		EquipHitmanWeapons();
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(i != hitman)
					EquipTargetWeapons(i);
			}
		}
		EquipRandomWeapons();		
		SendConVarValue(hitman, g_cvarSpread, "1");
		if(g_DisguiseOnStart.BoolValue)
		{
			g_iHitmanDisguise = "Terrorist";
		}
		else
			SetEntityModel(hitman, AGENT47_MODEL);
			
		EmitSoundToAllAny(AGENT47_SELECTED);
		PrintToChatAll("%s Hitman has been selected!", HITMAN_PREFIX);
		PrintToChat(hitman, " \x02 ------- You've been chosen as the Hitman! -------");
		if(!g_bNotifyHitmanInfo[hitman])
			PrintHitmanInfo(hitman, true);
		//Remove hitman on start
		g_iPlayersOnStart = GetAliveCountWithoutBots() - 1;
		SetEntProp(hitman, Prop_Data, "m_ArmorValue", g_HitmanArmor.IntValue);
		SetEntProp(hitman, Prop_Send, "m_bHasHelmet", g_HitmanHasHelmet.BoolValue);
			
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(i != hitman)
				{
					SetEntProp(i, Prop_Data, "m_ArmorValue", g_TargetsArmor.IntValue);
					SetEntProp(i, Prop_Send, "m_bHasHelmet", g_TargetsHaveHelmet.BoolValue);
					if(!g_bNotifyTargetInfo[i])
						PrintTargetInfo(i);
				}
			}
		}
	}
	else
		PrintToChatAll("%s Not enough players to pick hitman", HITMAN_PREFIX);
	delete temp;
}

void PrintTargetInfo(int client)
{
	Panel panel = CreatePanel();
	panel.SetTitle("Target Information");
	panel.DrawText("》 Find the Hitman and kill him before he kills you");
	panel.DrawText("》 Press ATTACK2 to grab props");
	panel.DrawText("》 The Hitman will reveal himself as a yellow glow if he shoots non silenced weapons");
	panel.DrawText("》 He can disguise himself if he kills a target don't trust anyone");
	panel.DrawText("》 Watch out for tripmines the Hitman may spawn with those");	
	panel.DrawItem("Close");
	panel.DrawItem("Close & Disable on spawn as target");
	panel.Send(client, TargetPanelHandler, MENU_TIME_FOREVER);
	delete panel;
}

public int TargetPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		if (param2 == 2)
		{
			SetClientCookie(param1, g_hNotifyTargetInfo, "1"); 
			g_bNotifyTargetInfo[param1] = true;
		}

		//OnClientCookiesCached(param1);
		
		if(menu != null)
			delete menu;
		
		PrintToChat(param1, "%s Type '!targetinfo' in chat to open this menu again", HITMAN_PREFIX);
	}
}

public int HitmanPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select && IsClientInGame(param1))
	{
		if (param2 == 2)
		{
			SetClientCookie(param1, g_hNotifyHitmanInfo, "1"); 
			g_bNotifyHitmanInfo[param1] = true;
			PrintToChat(param1, "%s Type '!hitmaninfo' in chat to open this menu again", HITMAN_PREFIX);
		}
		
		//OnClientCookiesCached(param1);
		
		if(menu != null)
			delete menu;
	}
}

void PrintHitmanInfo(int client, bool ishitman = false)
{
	char szFocus[PLATFORM_MAX_PATH];
	Format(szFocus, sizeof(szFocus), "》 Killing targets will give you back %i%% of your focus", RoundToNearest(g_FocusPerKill.FloatValue * 100));

	Panel panel = CreatePanel();
	if(ishitman)
		panel.SetTitle("You've been chosen as the Hitman!");
	else
		panel.SetTitle("Hitman Information");
	panel.DrawText("》 Eliminate your targets without being noticed");
	panel.DrawText("》 No spread is activated");
	panel.DrawText("》 Hold WALK to use your focus (Slow motion)");
	panel.DrawText("》 Press USE on targets ragdoll to disguise");
	panel.DrawText("》 Hold ATTACK2 to grab any prop/body (Bodies of targets you've killed)");
	panel.DrawText("》 Shooting any loud weapons will reveal yourself");
	panel.DrawText(szFocus);
	if(g_PenaltyType.IntValue != 0)
			panel.DrawText("》 Killing wrong targets will backfire");
	panel.DrawItem("Close");
	panel.DrawItem("Close & Disable on spawn as hitman");
	panel.Send(client, HitmanPanelHandler, MENU_TIME_FOREVER);
	delete panel;
}

void EquipHitmanWeapons()
{
	if(!IsValidHitman())
		return;
		
	int hitman = GetClientOfUserId(g_iHitman);
	g_Weapons.Rewind();
	if(!g_Weapons.JumpToKey("hitman"))
	{
		
		GivePlayerItem(hitman, "weapon_usp_silencer");
		return;
	}
		
	if(g_Weapons.GotoFirstSubKey())
	{
		do
		{
			char weaponName[32];
			g_Weapons.GetSectionName(weaponName, sizeof(weaponName));
			int clip = g_Weapons.GetNum("clip", 1);
			int ammo = g_Weapons.GetNum("ammo", 1);
			
			int weapon;
			if((weapon = GivePlayerItem(hitman, weaponName)) != -1)
			{
				DHookEntity(g_hInaccuracy, false, weapon);
				
				SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
				SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
				
				if(StrEqual(weaponName, "weapon_c4", false))
				{
					g_iHitmanTripmines = ammo;
					g_iHitmanMaxTripmines = ammo;
					SetEntProp(weapon, Prop_Send, "m_iClip1", 1);
				}
				else if(StrEqual(weaponName, "weapon_decoy", false))
				{
					g_iHitmanDecoys = ammo;
					g_iHitmanMaxDecoys = ammo;
					SetEntProp(weapon, Prop_Send, "m_iClip1", 1);
				}
			}
			
		} while (g_Weapons.GotoNextKey());
	}
	g_Weapons.Rewind();
}

void EquipTargetWeapons(int client)
{
	if(client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			g_Weapons.Rewind();
			if(!g_Weapons.JumpToKey("targets"))
				return;
				
			if(g_Weapons.GotoFirstSubKey())
			{
				do
				{
					char weaponName[32];
					g_Weapons.GetSectionName(weaponName, sizeof(weaponName));
					if(StrEqual(weaponName, "random", false))
						continue;
						
					int clip = g_Weapons.GetNum("clip");
					int ammo = g_Weapons.GetNum("ammo");
					
					int weapon;
					if((weapon = GivePlayerItem(client, weaponName)) != -1)
					{
						SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
						//SetEntProp(weapon, Prop_Data, "m_iClip2", ammo);
						SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
					}
					
				} while (g_Weapons.GotoNextKey());
			}
			g_Weapons.Rewind();
		}
	}
}

void EquipRandomWeapons()
{
	int hitman = GetClientOfUserId(g_iHitman);
	ArrayList players = new ArrayList();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T && i != hitman)
			players.Push(i);
	}
	
	//EQUIP RANDOM TARGET WEAPONS
	g_Weapons.Rewind();
	if(g_Weapons.JumpToKey("targets"))
	{
		if(g_Weapons.JumpToKey("random"))
		{
			if(g_Weapons.GotoFirstSubKey())
			{
				do
				{
					char weaponName[32];
					g_Weapons.GetSectionName(weaponName, sizeof(weaponName));
					int ratio = g_Weapons.GetNum("ratio");
					int clip = g_Weapons.GetNum("clip", 1);
					int ammo = g_Weapons.GetNum("ammo", 1);
					
					if(ratio <= 0)
					{
						PrintToServer("[hitmancsgo.smx] Please fill in ratio field if you're using random section'");
						return;
					}
						
					int amount = RoundToFloor(float(players.Length) / float(ratio));
					
					for (int i = 0; i < amount; i++)
					{
						int weapon;
						int random;
						if ((weapon = GivePlayerItem(players.Get(random = GetRandomInt(0, players.Length - 1)) , weaponName)) != -1)
						{
							SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
							SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
							
							if(StrEqual(weaponName, "weapon_decoy", false))
							{
								g_iDecoys[players.Get(random)] = ammo;
								g_iMaxDecoys = ammo;
								SetEntProp(weapon, Prop_Send, "m_iClip1", 1);
							}
							players.Erase(random);
						}
					}

				} while (g_Weapons.GotoNextKey());
			}
		}
	}
	g_Weapons.Rewind();
	delete players;
}

stock void StripWeapons(int client)
{
	int weapon; 
	for(int i = 0; i < 5; i++) 
	{ 
	    if((weapon = GetPlayerWeaponSlot(client, i)) != -1) 
	    { 
	    	char classname[PLATFORM_MAX_PATH];
	    	GetEntityClassname(weapon, classname, sizeof(classname));
	    	if(StrContains(classname, "knife", false) != -1 || StrContains(classname, "bayonet", false) != -1)
	    		continue;
	        SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR); 
	        AcceptEntityInput(weapon, "Kill"); 
	    } 
	}  
}

bool PickHitmanTarget()
{
	if(!IsValidHitman())
		return false;
		
	int hitman = GetClientOfUserId(g_iHitman);
	ArrayList temp = new ArrayList();
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) != CS_TEAM_SPECTATOR)
		{
			if(IsPlayerAlive(i) && i != hitman)
				temp.Push(i);
		}
	}
	
	if(temp.Length > 0)
	{
		int hitmantarget = temp.Get(GetRandomInt(0, temp.Length - 1));
		Call_StartForward(g_hOnPickHitmanTarget);
		Call_PushCell(hitmantarget);
		Call_Finish();
		g_iHitmanTarget = GetClientUserId(hitmantarget);
		if(hitmantarget > 0 && hitmantarget <= MaxClients)
		{
			if(!IsClientInGame(hitmantarget) || !IsPlayerAlive(hitmantarget))
				return false;
				
			char name[MAX_NAME_LENGTH];
			GetClientName(hitmantarget, name, sizeof(name));
			PrintActiveHitmanSettings();
			PrintToChat(hitman, "%s Your objective is to assassinate '\x02%s\x01'", HITMAN_PREFIX, name);
			CreateTargetGlowEntity(hitmantarget);
			delete temp;
			return true;
		}
	}
	delete temp;
	return false;
}

stock void SetGlowColor(int entity, const char[] color)
{
    char colorbuffers[3][4];
    ExplodeString(color, " ", colorbuffers, sizeof(colorbuffers), sizeof(colorbuffers[]));
    int colors[4];
    for (int i = 0; i < 3; i++)
        colors[i] = StringToInt(colorbuffers[i]);
    colors[3] = 255; // Set alpha
    SetVariantColor(colors);
    AcceptEntityInput(entity, "SetGlowColor");
}

stock void ResetVariables()
{
	int hitman = GetClientOfUserId(g_iHitman);
	StopSoundAny(hitman, SNDCHAN_STATIC, AGENT47_HEARTBEAT);
	
	int targetglow = EntRefToEntIndex(g_iHitmanTargetGlow);
	if(targetglow != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(targetglow, "Kill");
		g_iHitmanTargetGlow = INVALID_ENT_REFERENCE;
	}
	
	int hitmanglow = EntRefToEntIndex(g_iHitmanGlow);
	if(hitmanglow != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(hitmanglow, "Kill");
		g_iHitmanGlow = INVALID_ENT_REFERENCE;
	}	
	//HITMAN VARIABLES
	g_iHitman = INVALID_ENT_REFERENCE;
	g_iHitmanKiller = INVALID_ENT_REFERENCE;
	g_iHitmanTimer = g_TimeUntilHitmanChosen.IntValue;
	g_iHitmanFocusTicksStart = 0.0;
	g_iHitmanFocusTime = g_MaxFocusTime.FloatValue;
	g_iHitmanTickCounter = 0.0;
	g_iHitmanGlobalTickCounter = 0.0;
	g_iHitmanTripmines = 0;
	g_iHitmanMaxTripmines = 0;
	g_iHitmanDecoys = 0;
	g_iHitmanMaxDecoys = 0;
	g_iHitmanTargetKills = 0;
	g_iHitmanNonTargetKills = 0;
	g_bIsHitmanSeen = false;
	g_bHitmanWasSeen = false;
	g_bHitmanWasInOpen = false;
	g_bHasHitmanBeenSpotted = false;
	g_bHitmanPressedAttack1 = false;
	g_bHitmanPressedUse = false;
	g_bHitmanPressedWalk = false;
	g_iHitmanDisguise = "";
	
	//OTHER VARIABLES
	g_iMaxDecoys = 0;
	g_iPlayersOnStart = 0;
	g_bPickingHitman = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SendConVarValue(i, g_cvarSpread, "0");
			StopSoundAny(i, SNDCHAN_AUTO, FOCUS_ACTIVE);
		}

		g_bPressedAttack2[i] = false;
		g_bDidHitHitman[i] = false;
		g_iDecoys[i] = 0;
		g_iGrabbed[i] = INVALID_ENT_REFERENCE;
	}
}

stock bool IsValidHitman(bool dead = false)
{
	int hitman = GetClientOfUserId(g_iHitman);
	if(hitman > 0 && hitman <= MaxClients)
	{
		if(dead && IsClientInGame(hitman))
			return true;
			
		if(IsClientInGame(hitman) && IsPlayerAlive(hitman))
			return true;
	}
	return false;
}



stock void EnableSlowmo(int activator)
{
	if(!g_bFocusMode)
		EmitSoundToAllAny(FOCUS_ACTIVE);
	int hitman = GetClientOfUserId(g_iHitman);
	SetConVarInt(g_cvarCheats, 1);
	if(IsValidHitman())
		SendConVarValue(hitman, g_cvarSpread, "1");
	g_flTimeScaleGoal = SLOWMO_AMOUNT;
	g_bFocusMode = true;
}

stock void DisableSlowmo()
{
	g_flTimeScaleGoal = 1.0;
	g_bFocusMode = false;
}

stock void AddMaterialsFromFolder(char path[PLATFORM_MAX_PATH])
{
	DirectoryListing dir = OpenDirectory(path, true);
	if(dir != INVALID_HANDLE)
	{
		char buffer[PLATFORM_MAX_PATH];
		FileType type;
		
		while(dir.GetNext(buffer, PLATFORM_MAX_PATH, type))
		{
			if(type == FileType_File && ((StrContains(buffer, ".vmt", false) != -1) || (StrContains(buffer, ".vtf", false) != -1) && !(StrContains(buffer, ".ztmp", false) != -1)))
			{
				char fullPath[PLATFORM_MAX_PATH];
				Format(fullPath, sizeof(fullPath), "%s%s", path, buffer);
				AddFileToDownloadsTable(fullPath);
				
				if(!IsModelPrecached(fullPath))
					PrecacheModel(fullPath);
			}
		}
	}
}
 
stock void PrintActiveHitmanSettings(const char[] field = "none")
{
	if(!IsValidHitman())
		return;
	int hitman = GetClientOfUserId(g_iHitman);
	int hitmantarget = GetClientOfUserId(g_iHitmanTarget);
	char targetName[MAX_NAME_LENGTH];
	if(hitmantarget > 0 && hitmantarget <= MaxClients)
		GetClientName(hitmantarget, targetName, sizeof(targetName));
	else
		Format(targetName, sizeof(targetName), "");
		
	if(StrEqual(field, "none", false))
	{
		char modelName[PLATFORM_MAX_PATH];
	
		if(StrEqual(g_iHitmanDisguise, "", false))
		{
			Format(modelName, sizeof(modelName), "None (Agent 47)");
			PrintHintText(hitman, "<font size='16' face=''>Target: <font color='#FF0000'>%s</font>\n<font size='16' face=''>Disguise: <font color='#FF0000'>%s</font>\n<font size='16' face=''>Focus: <font color='%s'>%d%%</font>", targetName , modelName, (g_iHitmanFocusTime <= 0.0) ? "#FF0000":"#00FF00",RoundToNearest(g_iHitmanFocusTime / g_MaxFocusTime.FloatValue * 100));
		}
		else
		{
			Format(modelName, sizeof(modelName), "%s", g_iHitmanDisguise);
			PrintHintText(hitman, "<font size='16' face=''>Target: <font color='#FF0000'>%s</font>\n<font size='16' face=''>Disguise: <font color='#00FF00'>%s</font>\n<font size='16' face=''>Focus: <font color='%s'>%d%%</font>", targetName, modelName, (g_iHitmanFocusTime <= 0.0) ? "#FF0000":"#00FF00",RoundToNearest(g_iHitmanFocusTime / g_MaxFocusTime.FloatValue * 100));
		}
	}
	else if(StrEqual(field, "weapon_c4", false))
			PrintHintText(hitman, "<font size='16' face=''>Tripmines: <font color='%s'>%d/%d</font>\n<font size='16' face=''>Info: <font color='#FFA500'>Press primary attack to deploy a trip mine. You can trigger the explosion by force (Damage). Mine will not get triggered by yourself</font>", (g_iHitmanTripmines > 0) ? "#00FF00" : "#FF0000", g_iHitmanTripmines, g_iHitmanMaxTripmines);	
	else if(StrEqual(field, "weapon_decoy", false))
		PrintHintText(hitman, "<font size='16' face=''>Decoys: <font color='%s'>%d/%d</font>\n<font size='16' face=''>Info: <font color='#FFA500'>Reveals yourself where this grenade is thrown, decoy angle is inherited from yourself</font>", (g_iHitmanDecoys > 0) ? "#00FF00" : "#FF0000", g_iHitmanDecoys, g_iHitmanMaxDecoys);
}

stock void PrintActiveTargetSettings(int client, const char[] field = "none")
{
	if(StrEqual(field, "weapon_decoy", false))
		PrintHintText(client, "<font size='16' face=''>Identity-Scan Grenade: <font color='%s'>%d/%d</font>\n<font size='16' face=''>Info: <font color='#FFA500'>Reveals any hitmen around the area where this grenade is thrown</font>", (g_iDecoys[client] > 0) ? "#00FF00" : "#FF0000", g_iDecoys[client], g_iMaxDecoys);
}

stock void GrabEntity(int client, int entity)
{
	g_iGrabbed[client] = EntIndexToEntRef(entity);
}

stock void ReleaseEntity(int client)
{
	g_iGrabbed[client] = INVALID_ENT_REFERENCE;
}

stock void CleanUpRagdolls()
{
	if(g_iRagdolls.Length > g_RagdollLimit.IntValue)
	{
		int validRagdolls = 0;
		for (int i = 0; i < g_iRagdolls.Length; i++)
		{
			int ragdoll = EntRefToEntIndex(g_iRagdolls.Get(i));
			if(ragdoll != INVALID_ENT_REFERENCE)
				validRagdolls++;
			else
				g_iRagdolls.Erase(i);
		}
		if(validRagdolls > g_RagdollLimit.IntValue)
		{
			int ent = EntRefToEntIndex(g_iRagdolls.Get(0));
			AcceptEntityInput(ent, "Kill");
			g_iRagdolls.Erase(0);
		}
	}
}

public bool SpawnTripmine()
{
	if(!IsValidHitman())
		return false;
	int hitman = GetClientOfUserId(g_iHitman);
	float slopeAngle[3], eyeAngles[3], direction[3], traceendPos[3], eyePos[3];
	GetClientEyeAngles(hitman, eyeAngles);
	GetClientEyePosition(hitman, eyePos);
	GetAngleVectors(eyeAngles, direction, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(direction, direction);
	
	for( int i = 0; i < 3; i++ )
		eyePos[i] += direction[i] * 1.0;
	
	for( int i = 0; i < 3; i++ )
		direction[i] = eyePos[i] + direction[i] * 80.0;
	
	
	Handle trace = TR_TraceRayFilterEx(eyePos, direction, MASK_ALL, RayType_EndPoint, TraceFilterNotSelfAndParent, hitman);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(traceendPos, trace);
		TR_GetPlaneNormal(trace, slopeAngle);
		float angles[3];
		GetVectorAngles(slopeAngle, angles);
		angles[0] += 90.0;
		
		//CREATEMINE
		int mine = CreateEntityByName("prop_physics_override");
		int mineref = EntIndexToEntRef(mine);
		g_iMines.Push(mineref);
		
		DispatchKeyValue(mine, "targetname", "tripmine"); 
		DispatchKeyValue(mine, "spawnflags", "4"); 
		DispatchKeyValue(mine, "Solid", "6");
		DispatchKeyValue(mine, "model", "models/weapons/w_ied_dropped.mdl");
		DispatchKeyValue(mine, "physdamagescale", "1.0");
		DispatchKeyValue(mine, "health", "1");
		DispatchSpawn(mine);
		
		SetEntProp(mine, Prop_Data, "m_takedamage", 2);
		SetEntityMoveType(mine, MOVETYPE_NONE);
		TeleportEntity(mine, traceendPos, angles, NULL_VECTOR);
		
		int entityhit = TR_GetEntityIndex(trace);
		
		if (entityhit > MaxClients)
		{
			SetVariantString("!activator");
			AcceptEntityInput(mine, "SetParent", entityhit);
			SetEntPropEnt(mine, Prop_Send, "m_hOwnerEntity", entityhit);
			SDKHook(entityhit, SDKHook_OnTakeDamage, OnTakeDamage);
			
		}
		SDKHook(mine, SDKHook_OnTakeDamage, OnBombTakeDamage);
		EmitAmbientSoundAny(MINE_ACTIVE, traceendPos, mine,_,_, MINE_DEPLOY_VOLUME);
		
		//CREATEBEAM
		int beam = CreateEntityByName("env_beam");
		char color[16] = "255 0 0 255";
		SetEntityModel(beam, MODEL_BEAM); // This is where you would put the texture, ie "sprites/laser.vmt" or whatever.
		DispatchKeyValue(beam, "rendercolor", color );
		DispatchKeyValue(beam, "renderamt", "80");
		DispatchKeyValue(beam, "decalname", "Bigshot"); 
		DispatchKeyValue(beam, "life", "0"); 
		DispatchKeyValue(beam, "TouchType", "0");
		
		float end[3];
		angles[0] -= 90.0;
		Handle tracebeam = TR_TraceRayFilterEx(traceendPos, angles, MASK_ALL, RayType_Infinite, TraceFilterNotSelfAndParent, mine);
		if(TR_DidHit(tracebeam))
			TR_GetEndPosition(end, tracebeam);
			
		DispatchSpawn(beam);
		TeleportEntity(beam, end, NULL_VECTOR, NULL_VECTOR);
		
		SetEntPropEnt(beam, Prop_Send, "m_hAttachEntity", beam);
		SetEntPropEnt(beam, Prop_Send, "m_hAttachEntity", mine, 1);
		SetEntProp(beam, Prop_Send, "m_nNumBeamEnts", 2);
		SetEntProp(beam, Prop_Send, "m_nBeamType", 2);
		
		SetVariantString("!activator");
		AcceptEntityInput(beam, "SetParent", mine);
		
		SetEntPropFloat(beam, Prop_Data, "m_fWidth", 0.5); 
		SetEntPropFloat(beam, Prop_Data, "m_fEndWidth", 0.5); 
		ActivateEntity(beam);
		AcceptEntityInput(beam, "TurnOn");
		CloseHandle(trace);
		return true;
	}
	CloseHandle(trace);
	return false;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int health = GetEntProp(victim, Prop_Data, "m_iHealth");
	float fHealth = float(health);
	if(damage >= fHealth)
	{
		float pos[3];
		GetEntPropVector(victim, Prop_Data, "m_vecOrigin", pos);
		CreateExplosion(pos);
	}
}

public Action OnBombTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int health = GetEntProp(victim, Prop_Data, "m_iHealth");
	float fHealth = float(health);
	if(damage >= fHealth)
	{
		AcceptEntityInput(victim, "ClearParent");
		float pos[3];
		GetEntPropVector(victim, Prop_Data, "m_vecOrigin", pos);
		CreateExplosion(pos);
	}
}

public Action OnClientTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(g_bPickingHitman)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void TriggerExplosion(int ent)
{
	if(!IsValidEntity(ent))
		return;
	
	float pos[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
	EmitAmbientSoundAny(MINE_EXPLODE, pos, ent,_,_, MINE_EXPLOSION_VOLUME);	
	
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "Kill");
}

stock void CreateExplosion(float pos[3])
{
	int ent = CreateEntityByName("env_explosion");	
	DispatchKeyValue(ent, "spawnflags", "552");
	DispatchKeyValue(ent, "rendermode", "5");
	DispatchSpawn(ent);
	if(IsValidHitman())
	{
		int hitman = GetClientOfUserId(g_iHitman);
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", hitman);
	}

	SetEntProp(ent, Prop_Data, "m_iMagnitude", g_MineExplosionDamage.IntValue);
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride", g_MineExplosionRadius.IntValue);
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	
	RequestFrame(TriggerExplosion, ent);
}

stock void CreateIdentityScan(float pos[3])
{
	if(IsValidHitman())
	{
		int color[4] =  { 0, 0, 255, 255 };
		TE_SetupBeamRingPoint(pos, 0.1, g_IdentityScanRadius.FloatValue + 100.0, g_iPathLaserModelIndex, g_iPathHaloModelIndex, 0, 15, 0.4, 5.0, 0.0, color, 50, 0);
		TE_SendToAll();
		EmitAmbientSoundAny(IDENTITY_SCAN_SOUND, pos, _,_,_, IDENTITY_SCAN_VOLUME);
		int hitman = GetClientOfUserId(g_iHitman);
	
		float hitmanPos[3];
		GetClientAbsOrigin(hitman, hitmanPos);
		if(GetVectorDistance(hitmanPos, pos) < g_IdentityScanRadius.FloatValue)
		{
			g_iHitmanDisguise = "";
			SetEntityModel(hitman, AGENT47_MODEL);
		}
	}
}

 /*************
 *  FORWARDS  *
 *************/

public void OnGameFrame()
{
	//UPDATE MINES
	int hitman = GetClientOfUserId(g_iHitman);

	if(IsValidHitman())
	{
		bool didhit = false;
		bool didsee = false;
		if(StrEqual(g_iHitmanDisguise, "", false))
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T && i != hitman)
				{
					float hitmanEyePos[3], clientEyePos[3];
					GetClientEyePosition(hitman, hitmanEyePos);
					GetClientEyePosition(i, clientEyePos);
	
					Handle trace = TR_TraceRayFilterEx(clientEyePos, hitmanEyePos, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterNotSelf, i);
					if(TR_DidHit(trace))
					{
						if(TR_GetEntityIndex(trace) == hitman)
						{
							//Now a player view is open to the hitman
							float dirToHitman[3], playerDir[3];
							SubtractVectors(hitmanEyePos, clientEyePos, dirToHitman);
							NormalizeVector(dirToHitman, dirToHitman);
							
							GetClientEyeAngles(i, playerDir);
							GetAngleVectors(playerDir, playerDir, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(playerDir, playerDir);
							
							float angle = GetVectorDotProduct(dirToHitman, playerDir);
								
							//Testing only
							/*SubtractVectors(clientEyePos, hitmanEyePos, dirToHitman);
							NormalizeVector(dirToHitman, dirToHitman);
							
							GetClientEyeAngles(hitman, playerDir);
							GetAngleVectors(playerDir, playerDir, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(playerDir, playerDir);
							
							float angle = GetVectorDotProduct(playerDir, dirToHitman);
							//PrintToChatAll("%f", angle);*/
							
							if(angle > 0.58)
								didsee = true;
								
							CloseHandle(trace);
							didhit = true;
							break;
						}
					}
					CloseHandle(trace);
				}
			}
		}
		
		
		if(didsee)
		{
			g_bIsHitmanSeen = true;
			if(!g_bHitmanWasSeen)
			{
				float pos[3], angles[3];
				GetEntPropVector(hitman, Prop_Data, "m_vecOrigin", pos);
				GetEntPropVector(hitman, Prop_Data, "m_angRotation", angles);
				TeleportHitmanGlow(pos, angles, true);
				g_bHitmanWasSeen = true;
			}
		}
		else
		{
			g_bIsHitmanSeen = false;
			if(g_bHitmanWasSeen)
			{
				float pos[3], angles[3];
				GetEntPropVector(hitman, Prop_Data, "m_vecOrigin", pos);
				GetEntPropVector(hitman, Prop_Data, "m_angRotation", angles);
				TeleportHitmanGlow(pos, angles, false);
				g_bHitmanWasSeen = false;
			}
		}
		if(didhit)
		{
			if(!g_bHitmanWasInOpen)
			{
				EmitSoundToClientAny(hitman, AGENT47_HEARTBEAT,_,SNDCHAN_STATIC);
				g_bHitmanWasInOpen = true;
			}
		}
		else
		{
			if(g_bHitmanWasInOpen)
			{
				StopSoundAny(hitman, SNDCHAN_STATIC, AGENT47_HEARTBEAT);
				g_bHitmanWasInOpen = false;
			}
		}
	}
	
	for (int i = 0; i < g_iMines.Length; i++)
	{
		int mine = EntRefToEntIndex(g_iMines.Get(i));
		if(mine != INVALID_ENT_REFERENCE)
		{
			int parent = GetEntPropEnt(mine, Prop_Data, "m_hMoveParent");
			float angles[3], minePos[3];

			if(IsValidEntity(parent))
				AcceptEntityInput(mine, "ClearParent");
			
			GetEntPropVector(mine, Prop_Send, "m_angRotation", angles);
			GetEntPropVector(mine, Prop_Send, "m_vecOrigin", minePos);
			angles[0] -= 90.0;
			
			if(IsValidEntity(parent))
			{
				SetVariantString("!activator");
				AcceptEntityInput(mine, "SetParent", parent);
			}
			
			Handle trace = TR_TraceRayFilterEx(minePos, angles, MASK_ALL, RayType_Infinite, TraceFilterNotSelfAndParent, mine);
			if(TR_DidHit(trace))
			{
				int ent = TR_GetEntityIndex(trace);
				if(ent > 0 && ent <= MaxClients && ent != hitman)
				{
					int index;
					if((index = g_iMines.FindValue(EntIndexToEntRef(mine))) != -1)
						g_iMines.Erase(index);
						
					AcceptEntityInput(mine, "Kill");
					CreateExplosion(minePos);
				}
			}
			CloseHandle(trace);
		}
		else
		{
			g_iMines.Erase(i);
		}
	}
	
	//UPDATE FOCUS
	if(g_flTimeScaleGoal != 0.0)
	{
		float flTimeScale = g_cvarTimescale.FloatValue;
		
		if(flTimeScale > g_flTimeScaleGoal)
		{			
			SetConVarFloat(g_cvarTimescale, flTimeScale - 0.025);
			if(g_cvarTimescale.FloatValue <= g_flTimeScaleGoal)
			{
				SetConVarFloat(g_cvarTimescale, SLOWMO_AMOUNT);
			}
		}
		else if(flTimeScale < g_flTimeScaleGoal)
		{
			SetConVarFloat(g_cvarTimescale, flTimeScale + 0.025);

			if(g_cvarTimescale.FloatValue >= g_flTimeScaleGoal)
			{
				SetConVarFloat(g_cvarTimescale, 1.0);
				SetConVarInt(g_cvarCheats, 0);
				if(IsValidHitman())
					SendConVarValue(hitman, g_cvarSpread, "1");
				g_flTimeScaleGoal = 0.0;
				for (int i = 1; i <= MaxClients; i++)
					if(IsClientInGame(i))
						StopSoundAny(i, SNDCHAN_AUTO, FOCUS_ACTIVE);
			}
		}
	}
	
	if(g_iHitmanFocusTime <= 0.0 && g_bFocusMode)
	{
		DisableSlowmo();
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int hitman = GetClientOfUserId(g_iHitman);
	
	if(buttons & IN_ATTACK2 )
	{
		if(!g_bPressedAttack2[client])
		{
			//Attack 2 pressed
			g_bPressedAttack2[client] = true;
			int entity = GetClientAimTarget(client, false);
			char classname[PLATFORM_MAX_PATH];
			if(IsValidEntity(entity))
			{
				GetEntityClassname(entity, classname, sizeof(classname));
				if(StrEqual(classname, "prop_ragdoll", false) || StrContains(classname, "prop_physics", false) != -1)
				{
					if(!g_AllowTargetsGrabRagdoll.BoolValue && StrEqual(classname, "prop_ragdoll", false))
					{
						if(client == hitman)
						{
							float entityPos[3], clientPos[3], distance;
							GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPos);
							GetClientAbsOrigin(client, clientPos);
							
							distance = GetVectorDistance(clientPos, entityPos);
							
							if(distance < GRAB_DISTANCE)
							{
								SetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker", client);
								AcceptEntityInput(entity, "EnableMotion");
								SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
								GrabEntity(client, entity);
							}
						}
					}
					else 
					{
						float entityPos[3], clientPos[3], distance;
						GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPos);
						GetClientAbsOrigin(client, clientPos);
						
						distance = GetVectorDistance(clientPos, entityPos);
						
						if(distance < GRAB_DISTANCE)
						{
							SetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker", client);
							AcceptEntityInput(entity, "EnableMotion");
							SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
							GrabEntity(client, entity);
						}
					}
				}
			}
		}
	}
	else
	{
		if(g_bPressedAttack2[client])
		{
			//Attack 2 released
			ReleaseEntity(client);
		}
		g_bPressedAttack2[client] = false;
	}
	
	
	if(client == hitman && IsPlayerAlive(client))
	{
		if(buttons & IN_USE)
		{
			if(!g_bHitmanPressedUse)
			{
				//Use pressed
				g_bHitmanPressedUse = true;
				int entity = GetClientAimTarget(client, false);
				char classname[PLATFORM_MAX_PATH];
				if(IsValidEntity(entity))
				{
					
					GetEntityClassname(entity, classname, sizeof(classname));
					if(StrEqual(classname, "prop_ragdoll", false))
					{
						float ragdollPos[3], clientPos[3], distance;
						GetEntPropVector(entity, Prop_Data, "m_vecOrigin", ragdollPos);
						GetClientAbsOrigin(client, clientPos);
						
						distance = GetVectorDistance(clientPos, ragdollPos);
						
						if(distance < 50.0)
						{
							char ragdollName[MAX_NAME_LENGTH];
							GetEntPropString(entity, Prop_Data, "m_iName", ragdollName, sizeof(ragdollName)); 
							if(!StrEqual(ragdollName, g_iHitmanDisguise, false))
							{
								char ragdollmodelName[PLATFORM_MAX_PATH];
								GetEntPropString(entity, Prop_Data, "m_ModelName", ragdollmodelName, sizeof(ragdollmodelName)); 
								SetEntityModel(client, ragdollmodelName);
								EmitSoundToClientAny(hitman, AGENT47_DISGUISE,_,SNDCHAN_STATIC);
								Format(g_iHitmanDisguise, sizeof(g_iHitmanDisguise), "%s", ragdollName);
								float hitmanangles[3];
								GetEntPropVector(hitman, Prop_Data, "m_angRotation", angles);
								if(g_bIsHitmanSeen)
									TeleportHitmanGlow(clientPos, hitmanangles, false);
								PrintToChat(client, "%s You've disguised yourself", HITMAN_PREFIX);
								PrintActiveHitmanSettings();
							}
						}
					}
					else if(StrEqual(classname, "prop_physics", false))
					{
						char name[PLATFORM_MAX_PATH];
						GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
						if(StrEqual(name, "tripmine", false))
						{
							float minePos[3], eyePos[3], distance;
							
							GetClientEyePosition(client, eyePos);
							
							//Clear the parent to get its world position and not relative
							int parent = GetEntPropEnt(entity, Prop_Data, "m_hMoveParent");
							if(IsValidEntity(parent))
								AcceptEntityInput(entity, "ClearParent");
								
							GetEntPropVector(entity, Prop_Data, "m_vecOrigin", minePos);
							
							if(IsValidEntity(parent))
							{
								SetVariantString("!activator");
								AcceptEntityInput(entity, "SetParent", parent);
							}
							
							distance = GetVectorDistance(eyePos, minePos);
							if(distance < 80.0)
							{
								SDKUnhook(parent, SDKHook_OnTakeDamage, OnTakeDamage);
								
								int index;
								if((index = g_iMines.FindValue(EntIndexToEntRef(entity))) != -1)
									g_iMines.Erase(index);
								
								AcceptEntityInput(entity, "ClearParent");
								AcceptEntityInput(entity, "Kill");
								
								g_iHitmanTripmines++;
								PrintActiveHitmanSettings("weapon_c4");
								
								int c4; 
								if((c4 = GetPlayerWeaponSlot(client, 4)) != -1) 
								{ 
									SDKHooks_DropWeapon(client, c4, NULL_VECTOR, NULL_VECTOR); 
									AcceptEntityInput(c4, "Kill"); 
								} 
								
								GivePlayerItem(client, "weapon_c4");
							}
						}
					}
				}
				else
					PrintActiveHitmanSettings();
			}
		}
		else
			g_bHitmanPressedUse = false;
			
		if(buttons & IN_ATTACK)
		{
			if(!g_bHitmanPressedAttack1)
			{
				//Attack 1 pressed
				int weaponEnt = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
				char classname[PLATFORM_MAX_PATH];
				GetEntityClassname(weaponEnt, classname, sizeof(classname));
				if(StrEqual(classname, "weapon_c4", false))
				{
					if(SpawnTripmine())
					{
						g_iHitmanTripmines--;
						PrintActiveHitmanSettings(classname);
						SDKHooks_DropWeapon(client, weaponEnt, NULL_VECTOR, NULL_VECTOR);
						AcceptEntityInput(weaponEnt, "Kill");
						if(g_iHitmanTripmines > 0)
							GivePlayerItem(client, "weapon_c4");
					}
				}
			}
		}
		else
			g_bHitmanPressedAttack1 = false;
				
		if(buttons & IN_SPEED)
		{
			if(g_iHitmanFocusTime > 0.0)
			{
				if(!g_bHitmanPressedWalk)
				{
					//Walk pressed
					g_iHitmanFocusTicksStart = GetGameTime();
					g_bHitmanPressedWalk = true;
					g_iHitmanFocusTicksStart -= (g_FocusActivateCost.FloatValue * g_MaxFocusTime.FloatValue);
					EnableSlowmo(client);
				}
				if(g_InfiniteFocusWhenAlone.BoolValue)
				{
					if(GetClientCountWithoutBots() != 1)
					{
						g_iHitmanTickCounter = (GetGameTime() - g_iHitmanFocusTicksStart);
						g_iHitmanFocusTime = (g_MaxFocusTime.FloatValue - (g_iHitmanTickCounter + g_iHitmanGlobalTickCounter));
					}
				}
				else
				{
					g_iHitmanTickCounter = (GetGameTime() - g_iHitmanFocusTicksStart);
					g_iHitmanFocusTime = (g_MaxFocusTime.FloatValue - (g_iHitmanTickCounter + g_iHitmanGlobalTickCounter));
				}
				
				PrintActiveHitmanSettings();
			}
			else
			{
				g_iHitmanFocusTime = 0.0;
				PrintActiveHitmanSettings();
			}
		}
		else
		{
			if(g_bHitmanPressedWalk)
			{
				//Walk released
				DisableSlowmo();
				g_iHitmanGlobalTickCounter += g_iHitmanTickCounter;
			}
			
			g_bHitmanPressedWalk = false;
		}
	}
	
	if(!impulse || !g_bFocusMode) //We just want to prevent impulse commands during focus
		return Plugin_Continue;

	if(impulse == 201) //Allow sprays
		return Plugin_Continue;

	PrintToConsole(client, "Cheater! %i", impulse);
	
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "decoy_projectile", false))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnDecoySpawned);
	}
}

public void OnEntityDestroyed(int entity)
{	
	if(!IsValidEntity(entity))
		return;
	char name[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	if(StrEqual(name, "tripmineparent", false))
	{
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
		CreateExplosion(pos);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost);
	SDKHook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);
	//If client doesnt allow downloading custom content
	QueryClientConVar(client, "cl_downloadfilter", DownloadFilterCallback);
	OnClientCookiesCached(client);
}

public void OnClientCookiesCached(int client)
{
	char value[8];
	GetClientCookie(client, g_hNotifyHelp, value, sizeof(value));
	g_bNotifyHelp[client] = (value[0] != '\0' && StringToInt(value));
	
	GetClientCookie(client, g_hNotifyHitmanInfo, value, sizeof(value));
	g_bNotifyHitmanInfo[client] =  (value[0] != '\0' && StringToInt(value));
	
	GetClientCookie(client, g_hNotifyTargetInfo, value, sizeof(value));
	g_bNotifyTargetInfo[client] =  (value[0] != '\0' && StringToInt(value));
}

public void OnClientDisconnect(int client)
{
	int hitman = GetClientOfUserId(g_iHitman);
	int hitmantarget = GetClientOfUserId(g_iHitmanTarget);
	
	if(client == hitmantarget)
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		if(IsValidHitman())
			PrintToChat(hitman, "%s Your target '\x02%s\x01' has left the game!", HITMAN_PREFIX, name);
		
		int glow = EntRefToEntIndex(g_iHitmanTargetGlow);
		if(glow != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(glow, "Kill");
			g_iHitmanTargetGlow = INVALID_ENT_REFERENCE;
		}

		if(!PickHitmanTarget())
		{
			if(GetClientCountWithoutBots() > 0)
				CS_TerminateRound(g_RoundEndTime.FloatValue, CSRoundEnd_TerroristWin, false);
		}
	}

	if (client == hitman && !IsFakeClient(client))
	{
		int glow = EntRefToEntIndex(g_iHitmanTargetGlow);
		if(glow != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(glow, "Kill");
			g_iHitmanTargetGlow = INVALID_ENT_REFERENCE;
		}
		int hitmanglow = EntRefToEntIndex(g_iHitmanGlow);
		if(hitmanglow != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(hitmanglow, "Kill");
			g_iHitmanGlow = INVALID_ENT_REFERENCE;
		}
		g_iHitman = INVALID_ENT_REFERENCE;
		if(GetClientCountWithoutBots() > 0)
			CS_TerminateRound(g_RoundEndTime.FloatValue, CSRoundEnd_CTWin, false);
	}
	g_iGrabbed[client] = INVALID_ENT_REFERENCE;
	g_iDecoys[client] = 0;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnClientTakeDamage);
	SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnClientWeaponSwitchPost);
}

public void OnMapStart()
{
	ExecuteGamemodeCvars();
	
	AddMaterialsFromFolder("materials/models/player/voikanaa/hitman/agent47/");
	AddFileToDownloadsTable("models/player/custom_player/voikanaa/hitman/agent47.dx90.vtx");
	AddFileToDownloadsTable("models/player/custom_player/voikanaa/hitman/agent47.mdl");
	AddFileToDownloadsTable("models/player/custom_player/voikanaa/hitman/agent47.phy");
	AddFileToDownloadsTable("models/player/custom_player/voikanaa/hitman/agent47.vvd");
	AddFileToDownloadsTable("sound/hitmancsgo/mine_activate.mp3");
	AddFileToDownloadsTable("sound/hitmancsgo/heartbeat.mp3");
	AddFileToDownloadsTable("sound/hitmancsgo/located.mp3");
	AddFileToDownloadsTable("sound/hitmancsgo/spotted.mp3");
	AddFileToDownloadsTable("sound/hitmancsgo/selected.mp3");
	AddFileToDownloadsTable("sound/hitmancsgo/disguise.mp3");

	PrecacheSoundAny(MINE_EXPLODE, true);
	PrecacheSoundAny(MINE_ACTIVE, true);
	PrecacheSoundAny(FOCUS_ACTIVE, true);
	PrecacheSoundAny(IDENTITY_SCAN_SOUND, true);
	PrecacheSoundAny(AGENT47_HEARTBEAT, true);
	PrecacheSoundAny(AGENT47_SPOTTED, true);
	PrecacheSoundAny(AGENT47_LOCATED, true);
	PrecacheSoundAny(AGENT47_DISGUISE, true);
	PrecacheSoundAny(AGENT47_SELECTED, true);
	PrecacheSoundAny(TIMER_SOUND, true);
	
	PrecacheModel(AGENT47_MODEL);
	g_iPathHaloModelIndex = PrecacheModel(MODEL_BEAM);
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	
	int iEnt = INVALID_ENT_REFERENCE;
	iEnt = FindEntityByClassname(iEnt, "cs_player_manager");
	if (iEnt != INVALID_ENT_REFERENCE) {
		SDKHook(iEnt, SDKHook_ThinkPost, OnThinkPostManager);
	}
	
	int ent = INVALID_ENT_REFERENCE;
	while((ent = FindEntityByClassname(ent, "func_bomb_target")) != -1)
		AcceptEntityInput(ent, "Kill");
	
	g_flTimeScaleGoal = 0.0;
	g_bFocusMode = false;
	g_iHitman = INVALID_ENT_REFERENCE;
	g_iLastHitman = INVALID_ENT_REFERENCE;
	g_iRagdolls.Clear();
	g_iMines.Clear();
	CreateTimer(g_HelpNoticeTime.FloatValue, Timer_Notice, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Notice(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(!g_bNotifyHelp[i])
			{
				Command_Help(i, 0);
				PrintToChat(i, "%s Type !hmgonotify to remove this notice", HITMAN_PREFIX);
			}
		}
	}
}

public void OnMapEnd()
{
	int iEnt = INVALID_ENT_REFERENCE;
	iEnt = FindEntityByClassname(iEnt, "cs_player_manager");
	if (iEnt != INVALID_ENT_REFERENCE) {
		SDKUnhook(iEnt, SDKHook_ThinkPost, OnThinkPostManager);
	}
	ResetVariables();
	if(g_PickHitmanTimer != INVALID_HANDLE)
	{
		KillTimer(g_PickHitmanTimer);
		g_PickHitmanTimer = INVALID_HANDLE;
	}
}