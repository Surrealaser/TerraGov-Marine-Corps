/// Temporary visual effects
/obj/effect/temp_visual
	icon_state = "nothing"
	anchored = TRUE
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	///When set to true, we manually set the effect's duration via the set_duration proc
	var/manual_duration = FALSE
	var/duration = 1 SECONDS
	var/randomdir = TRUE
	var/timerid


/obj/effect/temp_visual/Initialize()
	. = ..()
	if(randomdir)
		setDir(pick(GLOB.cardinals))

	if(!manual_duration) //If we automatically set the duration
		timerid = QDEL_IN(src, duration)

/obj/effect/temp_visual/Destroy()
	. = ..()
	deltimer(timerid)


/obj/effect/temp_visual/ex_act()
	return

///We manually set the duration for the effect
/obj/effect/temp_visual/proc/set_duration(duration)
	timerid = QDEL_IN(src, duration)

/obj/effect/temp_visual/dir_setting
	randomdir = FALSE


/obj/effect/temp_visual/dir_setting/Initialize(mapload, set_dir)
	if(set_dir)
		setDir(set_dir)
	return ..()


///Image that appears at the Xeno Rally target; only Xenos can see it
/obj/effect/temp_visual/xenomorph/xeno_tracker_target
	name = "xeno tracker target"
	icon_state = "nothing"
	duration = XENO_HEALTH_ALERT_POINTER_DURATION
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	color = COLOR_RED
	hud_possible = list(XENO_TACTICAL_HUD)
	manual_duration = TRUE

/obj/effect/temp_visual/xenomorph/xeno_tracker_target/Initialize(mapload)
	. = ..()
	prepare_huds()
	for(var/datum/atom_hud/xeno_tactical/xeno_tac_hud in GLOB.huds) //Add to the xeno tachud
		xeno_tac_hud.add_to_hud(src)
	hud_set_xeno_tracker_target()

///Icon set up and HUD registration
/obj/effect/temp_visual/xenomorph/xeno_tracker_target/proc/hud_set_xeno_tracker_target()
	var/image/holder = hud_list[XENO_TACTICAL_HUD]
	if(!holder)
		return
	holder.icon = 'icons/Marine/marine-items.dmi'
	holder.icon_state = "detector_blip"
	hud_list[XENO_TACTICAL_HUD] = holder
