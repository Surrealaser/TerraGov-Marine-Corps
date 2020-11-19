/// Temporary visual effects
/obj/effect/temp_visual
	icon_state = "nothing"
	anchored = TRUE
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/duration = 1 SECONDS
	var/randomdir = TRUE
	var/timerid


/obj/effect/temp_visual/Initialize()
	. = ..()
	if(randomdir)
		setDir(pick(GLOB.cardinals))

	timerid = QDEL_IN(src, duration)


/obj/effect/temp_visual/Destroy()
	. = ..()
	deltimer(timerid)


/obj/effect/temp_visual/ex_act()
	return


/obj/effect/temp_visual/dir_setting
	randomdir = FALSE


/obj/effect/temp_visual/dir_setting/Initialize(mapload, set_dir)
	if(set_dir)
		setDir(set_dir)
	return ..()

/obj/effect/temp_visual/xenomorph/runner_afterimage
	name = "runner afterimage"
	desc = "It has become speed.."
	icon = 'icons/Xeno/2x2_Xenos.dmi' //They are now like, 2x1 or something
	icon_state = "Runner Walking"
	layer = MOB_LAYER
	alpha = 64 //Translucent
	duration = 0.3 SECONDS
	density = FALSE
	opacity = FALSE
	anchored = FALSE
	animate_movement = SLIDE_STEPS
