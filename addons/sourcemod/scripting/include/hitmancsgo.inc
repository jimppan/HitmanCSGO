#if defined hitmancsgo_include
  #endinput
#endif
#define hitmancsgo_include

/**
 * Returns hitmans client index
 *
 * @return  int				hitmans client index
 */
native int HitmanGO_GetHitman();

/**
 * Returns hitmans killer client index (Should only be called on round end forward or EventHookMode_Pre)
 *
 * @return  int				hitmans killer client index
 */
native int HitmanGO_GetHitmanKiller();

/**
 * Returns if the hitman has been spotted in the round (Should only be called on round end forward or EventHookMode_Pre)
 *
 * @return  bool			if hitman has been spotted
 */
native bool HitmanGO_HasHitmanBeenSpotted();

/**
 * Returns the hitmans target client index
 *
 * @return  int				hitmans target client index
 */
native int HitmanGO_GetCurrentHitmanTarget();

/**
 * Returns the amount of players there was on round start
 *
 * @return  int				amount of players on round start
 */
native int HitmanGO_GetRoundStartPlayers();

/**
 * Returns the amount of successfully assassinated targets by the hitman on the current round
 *
 * @return  int				target kills
 */
native int HitmanGO_GetTargetKills();

/**
 * Returns the amount of failed assassinated targets by the hitman on the current round (Non targets)
 *
 * @return  int				non target kills
 */
native int HitmanGO_GetNonTargetKills();

/**
 * Returns if the hitman is seen by 1 or more players
 *
 * @return  bool				gang size
 */
native bool HitmanGO_IsHitmanSeen();

/**
 * Returns true if theres a hitman
 *
 * @return  bool			if there is a hitman
 */
native bool HitmanGO_IsValidHitman();

/**
 * Called when the hitman is picked
 * @param hitmans client index.
 * @noreturn
 */
forward void HitmanGO_OnHitmanPicked(int hitman);

/**
 * Called when the hitmans target is picked
 * @param hitmans target client index.
 * @noreturn
 */
forward void HitmanGO_OnHitmanTargetPicked(int hitmantarget);

public SharedPlugin __pl_hitmancsgo  =
{
	name = "hitmancsgo",
	file = "hitmancsgo.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_hitmancsgo_SetNTVOptional()
{	
	MarkNativeAsOptional("HitmanGO_GetHitman");
	MarkNativeAsOptional("HitmanGO_IsHitmanSeen");
	MarkNativeAsOptional("HitmanGO_IsValidHitman");
}
#endif