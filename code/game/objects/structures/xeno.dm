
/*
* effect/alien
*/
/obj/effect/alien
	name = "alien thing"
	desc = "theres something alien about this"
	icon = 'icons/Xeno/Effects.dmi'
	hit_sound = "alien_resin_break"
	anchored = TRUE
	max_integrity = 1
	resistance_flags = UNACIDABLE
	obj_flags = CAN_BE_HIT
	var/on_fire = FALSE
	var/ignore_weed_destruction = FALSE //Set this to true if this object isn't destroyed when the weeds under it is.


/obj/effect/alien/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(user.a_intent == INTENT_HARM) //Already handled at the parent level.
		return

	if(obj_flags & CAN_BE_HIT)
		return I.attack_obj(src, user)


/obj/effect/alien/Crossed(atom/movable/O)
	. = ..()
	if(!QDELETED(src) && istype(O, /obj/vehicle/multitile/hitbox/cm_armored))
		tank_collision(O)

/obj/effect/alien/flamer_fire_act()
	take_damage(50, BURN, "fire")

/obj/effect/alien/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(500)
		if(EXPLODE_HEAVY)
			take_damage((rand(140, 300)))
		if(EXPLODE_LIGHT)
			take_damage((rand(50, 100)))

/obj/effect/alien/effect_smoke(obj/effect/particle_effect/smoke/S)
	. = ..()
	if(!.)
		return
	if(CHECK_BITFIELD(S.smoke_traits, SMOKE_BLISTERING))
		take_damage(rand(2, 20) * 0.1)

/*
* Resin
*/
/obj/effect/alien/resin
	name = "resin"
	desc = "Looks like some kind of slimy growth."
	icon_state = "Resin1"
	max_integrity = 200
	resistance_flags = XENO_DAMAGEABLE


/obj/effect/alien/resin/attack_hand(mob/living/user)
	to_chat(usr, "<span class='warning'>You scrape ineffectively at \the [src].</span>")
	return TRUE


/obj/effect/alien/resin/sticky
	name = "sticky resin"
	desc = "A layer of disgusting sticky slime."
	icon_state = "sticky"
	density = FALSE
	opacity = FALSE
	max_integrity = 36
	layer = RESIN_STRUCTURE_LAYER
	hit_sound = "alien_resin_move"
	var/slow_amt = 8

	ignore_weed_destruction = TRUE

/obj/effect/alien/resin/sticky/attack_alien(mob/living/carbon/xenomorph/X, damage_amount = X.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)

	if(X.a_intent == INTENT_HARM) //Clear it out on hit; no need to double tap.
		X.do_attack_animation(src, ATTACK_EFFECT_CLAW) //SFX
		playsound(src, "alien_resin_break", 25) //SFX
		deconstruct(TRUE)
		return

	return ..()


/obj/effect/alien/resin/sticky/Crossed(atom/movable/AM)
	. = ..()
	if(!ishuman(AM))
		return

	var/mob/living/carbon/human/H = AM

	if(H.lying_angle)
		return

	H.next_move_slowdown += slow_amt


// Praetorian Sticky Resin spit uses this.
/obj/effect/alien/resin/sticky/thin
	name = "thin sticky resin"
	desc = "A thin layer of disgusting sticky slime."
	max_integrity = 6
	slow_amt = 4

	ignore_weed_destruction = FALSE


//Resin Doors
/obj/structure/mineral_door/resin
	name = "resin door"
	mineralType = "resin"
	icon = 'icons/Xeno/Effects.dmi'
	hardness = 1.5
	layer = RESIN_STRUCTURE_LAYER
	max_integrity = 80
	var/close_delay = 60 SECONDS

	tiles_with = list(/turf/closed, /obj/structure/mineral_door/resin)

/obj/structure/mineral_door/resin/Initialize()
	. = ..()

	relativewall()
	relativewall_neighbours()
	if(!locate(/obj/effect/alien/weeds) in loc)
		new /obj/effect/alien/weeds(loc)

/obj/structure/mineral_door/resin/proc/thicken()
	var/oldloc = loc
	qdel(src)
	new /obj/structure/mineral_door/resin/thick(oldloc)
	return TRUE

/obj/structure/mineral_door/resin/attack_paw(mob/living/carbon/monkey/user)
	if(user.a_intent == INTENT_HARM)
		user.visible_message("<span class='xenowarning'>\The [user] claws at \the [src].</span>", \
		"<span class='xenowarning'>You claw at \the [src].</span>")
		playsound(loc, "alien_resin_break", 25)
		take_damage(rand(40, 60))
	else
		return TryToSwitchState(user)

/obj/structure/mineral_door/resin/attack_larva(mob/living/carbon/xenomorph/larva/M)
	var/turf/cur_loc = M.loc
	if(!istype(cur_loc))
		return FALSE
	TryToSwitchState(M)
	return TRUE

//clicking on resin doors attacks them, or opens them without harm intent
/obj/structure/mineral_door/resin/attack_alien(mob/living/carbon/xenomorph/X, damage_amount = X.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)
	var/turf/cur_loc = X.loc
	if(!istype(cur_loc))
		return FALSE //Some basic logic here
	if(X.a_intent != INTENT_HARM)
		TryToSwitchState(X)
		return TRUE

	M.visible_message("<span class='xenonotice'>\The [M] starts tearing down \the [src]!</span>", \
	"<span class='xenonotice'>We start to tear down \the [src].</span>")
	if(!do_after(M, XENO_DISMANTLE_TIME, TRUE, M, BUSY_ICON_GENERIC))
		return
	M.do_attack_animation(src, ATTACK_EFFECT_CLAW)
	M.visible_message("<span class='xenonotice'>\The [M] tears down \the [src]!</span>", \
	"<span class='xenonotice'>We tear down \the [src].</span>")
	playsound(src, "alien_resin_break", 25)
	deconstruct(TRUE)

/obj/structure/mineral_door/resin/flamer_fire_act()
	take_damage(50, BURN, "fire")

/turf/closed/wall/resin/fire_act()
	take_damage(50, BURN, "fire")

/obj/structure/mineral_door/resin/TryToSwitchState(atom/user)
	if(isxeno(user))
		return ..()

/obj/structure/mineral_door/resin/Open()
	if(state || !loc)
		return //already open
	isSwitchingStates = TRUE
	playsound(loc, "alien_resin_move", 25)
	flick("[mineralType]opening",src)
	sleep(0.7 SECONDS)
	density = FALSE
	opacity = FALSE
	state = 1
	update_icon()
	isSwitchingStates = 0

	spawn(close_delay)
		if(!isSwitchingStates && state == 1)
			Close()

/obj/structure/mineral_door/resin/Close()
	if(!state || !loc)
		return //already closed
	//Can't close if someone is blocking it
	for(var/turf/turf in locs)
		if(locate(/mob/living) in turf)
			spawn (close_delay)
				Close()
			return
	isSwitchingStates = TRUE
	playsound(loc, "alien_resin_move", 25)
	flick("[mineralType]closing",src)
	sleep(10)
	density = TRUE
	opacity = TRUE
	state = 0
	update_icon()
	isSwitchingStates = 0
	for(var/turf/turf in locs)
		if(locate(/mob/living) in turf)
			Open()
			return

/obj/structure/mineral_door/resin/Dismantle(devastated = 0)
	qdel(src)

/obj/structure/mineral_door/resin/CheckHardness()
	playsound(loc, "alien_resin_move", 25)
	..()

/obj/structure/mineral_door/resin/Destroy()
	relativewall_neighbours()
	var/turf/T
	for(var/i in GLOB.cardinals)
		T = get_step(loc, i)
		if(!istype(T))
			continue
		for(var/obj/structure/mineral_door/resin/R in T)
			INVOKE_NEXT_TICK(R, .proc/check_resin_support)
	return ..()


//do we still have something next to us to support us?
/obj/structure/mineral_door/resin/proc/check_resin_support()
	var/turf/T
	for(var/i in GLOB.cardinals)
		T = get_step(src, i)
		if(T.density)
			. = TRUE
			break
		if(locate(/obj/structure/mineral_door/resin) in T)
			. = TRUE
			break
	if(!.)
		visible_message("<span class = 'notice'>[src] collapses from the lack of support.</span>")
		qdel(src)



/obj/structure/mineral_door/resin/thick
	name = "thick resin door"
	max_integrity = 160
	hardness = 2.0

/obj/structure/mineral_door/resin/thick/thicken()
	return FALSE

/*
* Egg
*/

/obj/effect/alien/egg
	desc = "It looks like a weird egg"
	name = "egg"
	icon_state = "Egg Growing"
	density = FALSE
	flags_atom = CRITICAL_ATOM
	max_integrity = 80
	var/obj/item/clothing/mask/facehugger/hugger = null
	var/hugger_type = /obj/item/clothing/mask/facehugger/stasis
	var/trigger_size = 1
	var/list/egg_triggers = list()
	var/status = EGG_GROWING
	var/hivenumber = XENO_HIVE_NORMAL

/obj/effect/alien/egg/prop //just useful as a map prop
	icon_state = "Egg Opened"
	status = EGG_BURST
	trigger_size = 0

/obj/effect/alien/egg/Initialize()
	. = ..()
	if(hugger_type)
		hugger = new hugger_type(src)
		hugger.hivenumber = hivenumber
		if(!hugger.stasis)
			hugger.go_idle(TRUE)
	addtimer(CALLBACK(src, .proc/Grow), rand(EGG_MIN_GROWTH_TIME, EGG_MAX_GROWTH_TIME))

/obj/effect/alien/egg/Destroy()
	QDEL_LIST(egg_triggers)
	return ..()

/obj/effect/alien/egg/proc/transfer_to_hive(new_hivenumber)
	if(hivenumber == new_hivenumber)
		return
	hivenumber = new_hivenumber
	if(hugger)
		hugger.hivenumber = new_hivenumber

/obj/effect/alien/egg/proc/Grow()
	if(status == EGG_GROWING)
		update_status(EGG_GROWN)
		deploy_egg_triggers()

/obj/effect/alien/egg/proc/deploy_egg_triggers()
	QDEL_LIST(egg_triggers)
	var/list/turf/target_locations = filled_turfs(src, trigger_size, "circle", FALSE)
	for(var/turf/trigger_location in target_locations)
		egg_triggers += new /obj/effect/egg_trigger(trigger_location, src)

/obj/effect/alien/egg/ex_act(severity)
	Burst(TRUE)//any explosion destroys the egg.

/obj/effect/alien/egg/attack_alien(mob/living/carbon/xenomorph/M, damage_amount = M.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)

	if(!istype(M))
		return attack_hand(M)

	if(!issamexenohive(M))
		M.do_attack_animation(src, ATTACK_EFFECT_SMASH)
		M.visible_message("<span class='xenowarning'>[M] crushes \the [src]","<span class='xenowarning'>We crush \the [src]")
		Burst(TRUE)
		return

	switch(status)
		if(EGG_BURST, EGG_DESTROYED)
			if(M.xeno_caste.can_hold_eggs)
				M.visible_message("<span class='xenonotice'>\The [M] clears the hatched egg.</span>", \
				"<span class='xenonotice'>We clear the hatched egg.</span>")
				playsound(src.loc, "alien_resin_break", 25)
				M.plasma_stored++
				qdel(src)
		if(EGG_GROWING)
			to_chat(M, "<span class='xenowarning'>The child is not developed yet.</span>")
		if(EGG_GROWN)
			to_chat(M, "<span class='xenonotice'>We retrieve the child.</span>")
			Burst(FALSE)

/obj/effect/alien/egg/proc/Burst(kill = TRUE) //drops and kills the hugger if any is remaining
	if(kill)
		if(status != EGG_DESTROYED)
			QDEL_NULL(hugger)
			QDEL_LIST(egg_triggers)
			update_status(EGG_DESTROYED)
			flick("Egg Exploding", src)
			playsound(src.loc, "sound/effects/alien_egg_burst.ogg", 25)
	else
		if(status in list(EGG_GROWN, EGG_GROWING))
			update_status(EGG_BURSTING)
			QDEL_LIST(egg_triggers)
			flick("Egg Opening", src)
			playsound(src.loc, "sound/effects/alien_egg_move.ogg", 25)
			addtimer(CALLBACK(src, .proc/unleash_hugger), 1 SECONDS)

/obj/effect/alien/egg/proc/unleash_hugger()
	if(status != EGG_DESTROYED && hugger)
		status = EGG_BURST
		hugger.forceMove(loc)
		hugger.go_active(TRUE)
		hugger = null

/obj/effect/alien/egg/proc/update_status(new_stat)
	if(new_stat)
		status = new_stat
		update_icon()

/obj/effect/alien/egg/update_icon()
	overlays.Cut()
	if(hivenumber != XENO_HIVE_NORMAL && GLOB.hive_datums[hivenumber])
		var/datum/hive_status/hive = GLOB.hive_datums[hivenumber]
		color = hive.color
	else
		color = null
	switch(status)
		if(EGG_DESTROYED)
			icon_state = "Egg Exploded"
			return
		if(EGG_BURSTING || EGG_BURST)
			icon_state = "Egg Opened"
		if(EGG_GROWING)
			icon_state = "Egg Growing"
		if(EGG_GROWN)
			icon_state = "Egg"
	if(on_fire)
		overlays += "alienegg_fire"

/obj/effect/alien/egg/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(hugger_type == null)
		return // This egg doesn't take huggers

	if(istype(I, /obj/item/clothing/mask/facehugger))
		var/obj/item/clothing/mask/facehugger/F = I
		if(F.stat == DEAD)
			to_chat(user, "<span class='xenowarning'>This child is dead.</span>")
			return

		if(status == EGG_DESTROYED)
			to_chat(user, "<span class='xenowarning'>This egg is no longer usable.</span>")
			return

		if(hugger)
			to_chat(user, "<span class='xenowarning'>This one is occupied with a child.</span>")
			return

		visible_message("<span class='xenowarning'>[user] slides [F] back into [src].</span>","<span class='xenonotice'>You place the child back in to [src].</span>")
		user.transferItemToLoc(F, src)
		F.go_idle(TRUE)
		hugger = F
		update_status(EGG_GROWN)
		deploy_egg_triggers()


/obj/effect/alien/egg/deconstruct(disassembled = TRUE)
	Burst(TRUE)
	return ..()

/obj/effect/alien/egg/flamer_fire_act() // gotta kill the egg + hugger
	Burst(TRUE)

/obj/effect/alien/egg/fire_act()
	Burst(TRUE)

/obj/effect/alien/egg/HasProximity(atom/movable/AM)
	if((status != EGG_GROWN) || QDELETED(hugger) || !iscarbon(AM))
		return FALSE
	var/mob/living/carbon/C = AM
	if(!C.can_be_facehugged(hugger))
		return FALSE
	Burst(FALSE)
	return TRUE

//The invisible traps around the egg to tell it there's a mob right next to it.
/obj/effect/egg_trigger
	name = "egg trigger"
	icon = 'icons/effects/effects.dmi'
	anchored = TRUE
	mouse_opacity = 0
	invisibility = INVISIBILITY_MAXIMUM
	var/obj/effect/alien/egg/linked_egg

/obj/effect/egg_trigger/Initialize(mapload, obj/effect/alien/egg/source_egg)
	. = ..()
	linked_egg = source_egg


/obj/effect/egg_trigger/Crossed(atom/A)
	. = ..()
	if(!linked_egg) //something went very wrong
		qdel(src)
	else if(get_dist(src, linked_egg) != 1 || !isturf(linked_egg.loc)) //something went wrong
		loc = linked_egg
	else if(iscarbon(A))
		var/mob/living/carbon/C = A
		linked_egg.HasProximity(C)



/obj/effect/alien/egg/gas
	hugger_type = null
	trigger_size = 2

/obj/effect/alien/egg/gas/Burst(kill)
	var/spread = EGG_GAS_DEFAULT_SPREAD
	if(kill) // Kill is more violent
		spread = EGG_GAS_KILL_SPREAD

	QDEL_LIST(egg_triggers)
	update_status(EGG_DESTROYED)
	flick("Egg Exploding", src)
	playsound(loc, "sound/effects/alien_egg_burst.ogg", 30)

	var/datum/effect_system/smoke_spread/xeno/neuro/NS = new(src)
	NS.set_up(spread, get_turf(src))
	NS.start()

/obj/effect/alien/egg/gas/HasProximity(atom/movable/AM)
	if(issamexenohive(AM))
		return FALSE
	Burst(FALSE)
	return TRUE

/obj/structure/xeno
	///Our hive ID; self-explanatory; we default to the standard hive; modified when built
	var/hivenumber = XENO_HIVE_NORMAL
	///Whether the structure alerts the hive when destroyed; we default to true
	var/destruction_alert = TRUE
	///Whether we override the normal hivewide cooldown on alerts for hive structures being destroyed; TRUE for tunnels and other VIP buildings, otherwise FALSE
	var/override_cooldown = FALSE

/obj/structure/xeno/Initialize(mapload, mob/living/carbon/xenomorph/X)
	. = ..()
	if(!X) //Make sure X exists
		return
	if(X.hivenumber)
		hivenumber = X.hivenumber

/obj/structure/xeno/flamer_fire_act()
	take_damage(50, BURN, "fire")

/obj/structure/xeno/fire_act()
	take_damage(10, BURN, "fire")

/obj/structure/xeno/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(max_integrity, BRUTE, "bomb") //Will instantly destroy any xeno structure that lacks bomb resistance (i.e. resin silo)
		if(EXPLODE_HEAVY)
			take_damage(200, BRUTE, "bomb")
		if(EXPLODE_LIGHT)
			take_damage(100, BRUTE, "bomb")

/obj/structure/xeno/obj_destruction(damage_amount, damage_type, damage_flag)

	if(!destruction_alert)  //Whether or not we alert the hive on destruction; true by default. We are a hivemind after all.
		return ..()

	var/datum/hive_status/HS = GLOB.hive_datums[hivenumber]
	if(!COOLDOWN_CHECK(HS, xeno_structure_destruction_alert_cooldown) && !override_cooldown) //We're on cooldown and we have no override
		return ..()

	HS.xeno_message("<span class='xenoannounce'>Our [name] at [AREACOORD_NO_Z(src)] has been destroyed!</span>", 2) //Alert the hive!

	if(!override_cooldown) //Overriding structures don't begin our cooldown
		COOLDOWN_START(HS, xeno_structure_destruction_alert_cooldown, XENO_STRUCTURE_DESTRUCTION_ALERT_COOLDOWN) //set the cooldown for the hive

	return ..()

///Proc called for repairable xeno structures
/obj/structure/xeno/proc/repair_xeno_structure(mob/living/carbon/xenomorph/M)

	if(M.a_intent != INTENT_HELP) //We must be on help intent to repair
		return FALSE

	if(obj_integrity >= max_integrity) //If the structure is at max health (or higher somehow), no need to continue
		return FALSE

	if(!CHECK_BITFIELD(M.xeno_caste.caste_flags, CASTE_IS_BUILDER)) //Check to see if we can actually repair
		return FALSE

	if(M.plasma_stored < 1) //You need to have at least 1 plasma to repair the structure
		to_chat(M, "<span class='xenodanger'>We need plasma to repair [src]!</span>")
		return FALSE

	var/repair_cost = min(M.plasma_stored,max_integrity - obj_integrity) //Calculate repair cost, taking the lower of its damage or our current plasma. We heal damage with plasma on a 1 : 1 ratio.

	new /obj/effect/temp_visual/healing(get_turf(src)) //SFX
	to_chat(M, "<span class='xenodanger'>We begin to repair [src] with our plasma. We expect to repair [repair_cost] damage at an equal cost to our plasma...</span>")
	if(!do_after(M, XENO_ACID_WELL_FILL_TIME, FALSE, src, BUSY_ICON_BUILD))
		to_chat(M, "<span class='xenodanger'>We abort repairing [src]!</span>")
		return FALSE

	repair_cost = min(M.plasma_stored,max_integrity - obj_integrity) //We heal damage with plasma on a 1 : 1 ratio. Double check our repair cost after the fact in case it somehow changed (e.g. plasma gas)

	M.plasma_stored -= repair_cost //Deduct plasma cost
	obj_integrity = min(max_integrity, obj_integrity + repair_cost) //Set the new health with overflow protection
	to_chat(M, "<span class='xenonotice'>We repair [src], restoring <b>[repair_cost]</b> health. It is now at <b>[obj_integrity]/[max_integrity]</b> Health.</span>") //Feedback
	new /obj/effect/temp_visual/healing(get_turf(src)) //SFX

	return TRUE

//Carrier trap
/obj/structure/xeno/trap
	desc = "It looks like a hiding hole."
	name = "resin hole"
	icon_state = "trap0"
	density = FALSE
	opacity = FALSE
	anchored = TRUE
	max_integrity = 50
	layer = RESIN_STRUCTURE_LAYER
	var/obj/item/clothing/mask/facehugger/hugger = null

/obj/structure/xeno/trap/Initialize(mapload, mob/living/carbon/xenomorph/X)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_SHUTTLE_CRUSH, .proc/shuttle_crush)

/obj/structure/xeno/trap/obj_destruction(damage_amount, damage_type, damage_flag)
	if(damage_amount && hugger && loc)
		drop_hugger()

	return ..()

///Ensures that no huggies will be released when the trap is crushed by a shuttle; no more trapping shuttles with huggies
/obj/structure/xeno/trap/proc/shuttle_crush()
	SIGNAL_HANDLER
	qdel(src)


/obj/structure/xeno/trap/examine(mob/user)
	. = ..()
	if(isxeno(user))
		to_chat(user, "A hole for a little one to hide in ambush.")
		if(hugger)
			to_chat(user, "There's a little one inside.")
		else
			to_chat(user, "It's empty.")


/obj/structure/xeno/trap/flamer_fire_act()
	if(hugger)
		hugger.forceMove(loc)
		hugger.kill_hugger()
		hugger = null
		icon_state = "trap0"
	..()

/obj/structure/xeno/trap/fire_act()
	if(hugger)
		hugger.forceMove(loc)
		hugger.kill_hugger()
		hugger = null
		icon_state = "trap0"
	..()

/obj/structure/xeno/trap/HasProximity(atom/movable/AM)
	if(!iscarbon(AM) || !hugger)
		return
	var/mob/living/carbon/C = AM
	if(C.can_be_facehugged(hugger))
		playsound(src, "alien_resin_break", 25)
		C.visible_message("<span class='warning'>[C] trips on [src]!</span>",\
						"<span class='danger'>You trip on [src]!</span>")
		C.Paralyze(40)
		var/datum/hive_status/HS = GLOB.hive_datums[hivenumber]
		HS.xeno_message("<span class='xenoannounce'>Our [name] at [AREACOORD_NO_Z(src)] has been triggered!</span>", 2, FALSE, src, 'sound/voice/alien_growl1.ogg') //Alert the hive
		notify_ghosts("\ [C] triggered a [src] at [AREACOORD_NO_Z(C)]!", source = C, action = NOTIFY_ORBIT)
		drop_hugger()

///Drops the hugger within when the trap is tripped or destroyed
/obj/structure/xeno/trap/proc/drop_hugger()
	hugger.forceMove(loc)
	hugger.stasis = FALSE
	addtimer(CALLBACK(hugger, /obj/item/clothing/mask/facehugger.proc/fast_activate), 1.5 SECONDS)
	icon_state = "trap0"
	visible_message("<span class='warning'>[hugger] gets out of [src]!</span>")
	hugger = null

/obj/structure/xeno/trap/attack_alien(mob/living/carbon/xenomorph/M)
	if(M.a_intent != INTENT_HARM)
		if(M.xeno_caste.caste_flags & CASTE_CAN_HOLD_FACEHUGGERS)
			if(!hugger)
				to_chat(M, "<span class='warning'>[src] is empty.</span>")
			else
				icon_state = "trap0"
				M.put_in_active_hand(hugger)
				hugger.go_active(TRUE)
				hugger = null
				to_chat(M, "<span class='xenonotice'>We remove the [hugger] from [src].</span>")
		return
	..()

/obj/structure/xeno/trap/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/clothing/mask/facehugger) && isxeno(user))
		var/obj/item/clothing/mask/facehugger/FH = I
		if(hugger)
			to_chat(user, "<span class='warning'>There is already a facehugger in [src].</span>")
			return

		if(FH.stat == DEAD)
			to_chat(user, "<span class='warning'>You can't put a dead facehugger in [src].</span>")
			return

		user.transferItemToLoc(FH, src)
		FH.go_idle(TRUE)
		hugger = FH
		icon_state = "trap1"
		to_chat(user, "<span class='xenonotice'>You place a facehugger in [src].</span>")


/obj/structure/xeno/trap/Crossed(atom/A)
	. = ..()
	if(iscarbon(A))
		HasProximity(A)



/*
TUNNEL
*/


/obj/structure/xeno/tunnel
	name = "tunnel"
	desc = "A tunnel entrance. Looks like it was dug by some kind of clawed beast."
	icon = 'icons/Xeno/effects.dmi'
	icon_state = "hole"

	density = FALSE
	opacity = FALSE
	anchored = TRUE
	resistance_flags = UNACIDABLE
	layer = RESIN_STRUCTURE_LAYER

	var/tunnel_desc = "" //description added by the hivelord.

	max_integrity = 140
	var/mob/living/carbon/xenomorph/hivelord/creator = null

	hud_possible = list(XENO_TACTICAL_HUD)

/obj/structure/xeno/tunnel/flamer_fire_act()
	return

/obj/structure/xeno/tunnel/fire_act()
	return

/obj/structure/xeno/tunnel/Initialize(mapload, mob/living/carbon/xenomorph/X)
	. = ..()
	GLOB.xeno_tunnels += src
	prepare_huds()
	for(var/datum/atom_hud/xeno_tactical/xeno_tac_hud in GLOB.huds) //Add to the xeno tachud
		xeno_tac_hud.add_to_hud(src)
	hud_set_xeno_tunnel()

//Makes sure the tunnel is visible to other xenos even through obscuration.
/obj/structure/xeno/tunnel/proc/hud_set_xeno_tunnel()
	var/image/holder = hud_list[XENO_TACTICAL_HUD]
	if(!holder)
		return
	holder.icon = 'icons/mob/hud.dmi'
	holder.icon_state = "hudtraitor"
	hud_list[XENO_TACTICAL_HUD] = holder


/obj/structure/xeno/tunnel/Destroy()
	var/drop_loc = get_turf(src)
	for(var/atom/movable/thing as() in contents) //Empty the tunnel of contents
		thing.forceMove(drop_loc)

	GLOB.xeno_tunnels -= src
	if(creator)
		creator.tunnels -= src

	return ..()

/obj/structure/xeno/tunnel/examine(mob/user)
	. = ..()
	if(!isxeno(user) && !isobserver(user))
		return
	if(tunnel_desc)
		to_chat(user, "<span class='info'>The Hivelord scent reads: \'[tunnel_desc]\'</span>")

/obj/structure/xeno/tunnel/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(210)
		if(EXPLODE_HEAVY)
			take_damage(140)
		if(EXPLODE_LIGHT)
			take_damage(70)

/obj/structure/xeno/tunnel/attackby(obj/item/I, mob/user, params)
	if(!isxeno(user))
		return ..()
	attack_alien(user)

/obj/structure/tunnel/attack_alien(mob/living/carbon/xenomorph/X, damage_amount = X.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)
	if(!istype(X) || X.stat || X.lying_angle)
		return

	if(M.a_intent == INTENT_HARM && M == creator)
		deconstruct(TRUE, M, HIVELORD_TUNNEL_DISMANTLE_TIME, "<span class='xenoannounce'>We begin filling in our tunnel...</span>", "<span class='xenoannounce'>We fill in our tunnel.</span>")
		return

	//Check for repairs
	repair_xeno_structure(M)

	//Prevents using tunnels by the queen to bypass the fog.
	if(SSticker?.mode && SSticker.mode.flags_round_type & MODE_FOG_ACTIVATED)
		if(!X.hive.living_xeno_ruler)
			to_chat(X, "<span class='xenowarning'>There is no ruler. We must choose one first.</span>")
			return FALSE
		else if(isxenoqueen(X))
			to_chat(X, "<span class='xenowarning'>There is no reason to leave the safety of the caves yet.</span>")
			return FALSE

	if(X.anchored)
		to_chat(X, "<span class='xenowarning'>We can't climb through a tunnel while immobile.</span>")
		return FALSE

	if(length(GLOB.xeno_tunnels) < 2)
		to_chat(X, "<span class='warning'>There are no other tunnels in the network!</span>")
		return FALSE

	pick_a_tunnel(X)

///Here we pick a tunnel to go to, then travel to that tunnel and peep out, confirming whether or not we want to emerge or go to another tunnel.
/obj/structure/xeno/tunnel/proc/pick_a_tunnel(mob/living/carbon/xenomorph/M)
	var/obj/structure/xeno/tunnel/targettunnel = input(M, "Choose a tunnel to crawl to", "Tunnel") as null|anything in GLOB.xeno_tunnels
	if(QDELETED(src)) //Make sure we still exist in the event the player keeps the interface open
		return
	if(!M.Adjacent(src) && M.loc != src) //Make sure we're close enough to our tunnel; either adjacent to or in one
		return
	if(QDELETED(targettunnel)) //Make sure our target destination still exists in the event the player keeps the interface open
		to_chat(M, "<span class='warning'>That tunnel no longer exists!</span>")
		if(M.loc == src) //If we're in the tunnel and cancelling out, spit us out.
			M.forceMove(loc)
		return
	if(targettunnel == src)
		to_chat(M, "<span class='warning'>We're already here!</span>")
		if(M.loc == src) //If we're in the tunnel and cancelling out, spit us out.
			M.forceMove(loc)
		return
	if(targettunnel.z != z)
		to_chat(M, "<span class='warning'>That tunnel isn't connected to this one!</span>")
		if(M.loc == src) //If we're in the tunnel and cancelling out, spit us out.
			M.forceMove(loc)
		return
	var/distance = get_dist(get_turf(src), get_turf(targettunnel))
	var/tunnel_time = clamp(distance, HIVELORD_TUNNEL_MIN_TRAVEL_TIME, HIVELORD_TUNNEL_SMALL_MAX_TRAVEL_TIME)

	if(M.mob_size == MOB_SIZE_BIG) //Big xenos take longer
		tunnel_time = clamp(distance * 1.5, HIVELORD_TUNNEL_MIN_TRAVEL_TIME, HIVELORD_TUNNEL_LARGE_MAX_TRAVEL_TIME)
		M.visible_message("<span class='xenonotice'>[M] begins heaving their huge bulk down into \the [src].</span>", \
		"<span class='xenonotice'>We begin heaving our monstrous bulk into \the [src] to <b>[targettunnel.tunnel_desc]</b>.</span>")
	else
		M.visible_message("<span class='xenonotice'>\The [M] begins crawling down into \the [src].</span>", \
		"<span class='xenonotice'>We begin crawling down into \the [src] to <b>[targettunnel.tunnel_desc]</b>.</span>")

	if(isxenolarva(M)) //Larva can zip through near-instantly, they are wormlike after all
		tunnel_time = 5

	if(do_after(M, tunnel_time, FALSE, src, BUSY_ICON_GENERIC))
		if(targettunnel && isturf(targettunnel.loc)) //Make sure the end tunnel is still there
			M.forceMove(targettunnel)
			var/double_check = input(M, "Emerge here?", "Tunnel: [targettunnel]") as null|anything in list("Yes","Pick another tunnel")
			if(M.loc != targettunnel) //double check that we're still in the tunnel in the event it gets destroyed while we still have the interface open
				return
			if(double_check == "Pick another tunnel")
				return targettunnel.pick_a_tunnel(M)
			else //Whether we say yes or cancel out of it
				M.forceMove(targettunnel.loc)
				M.visible_message("<span class='xenonotice'>\The [M] pops out of \the [src].</span>", \
				"<span class='xenonotice'>We pop out through the other side!</span>")
		else
			to_chat(M, "<span class='warning'>\The [src] ended unexpectedly, so we return back up.</span>")
	else
		to_chat(M, "<span class='warning'>Our crawling was interrupted!</span>")

//Resin Water Well
/obj/structure/xeno/acidwell
	name = "acid well"
	desc = "An acid well. It stores acid to put out fires."
	icon = 'icons/Xeno/acid_pool.dmi'
	icon_state = "fullwell"
	density = FALSE
	opacity = FALSE
	anchored = TRUE
	max_integrity = 120
	layer = RESIN_STRUCTURE_LAYER

	hit_sound = "alien_resin_move"
	destroy_sound = "alien_resin_move"

	var/charges = 1
	var/ccharging = FALSE

/obj/structure/xeno/acidwell/Initialize(mapload, mob/living/carbon/xenomorph/X)
	. = ..()
	update_icon()

///Ensures that no acid gas will be released when the well is crushed by a shuttle
/obj/effect/alien/resin/acidwell/proc/shuttle_crush()
	SIGNAL_HANDLER
	qdel(src)

/obj/structure/xeno/acidwell/obj_destruction(damage_amount, damage_type, damage_flag)
	if(damage_amount) //Spawn the gas only if we actually get destroyed by damage
		var/datum/effect_system/smoke_spread/xeno/acid/A = new(get_turf(src))
		A.set_up(clamp(charges,0,2),src)
		A.start()
	return ..()

/obj/structure/xeno/acidwell/examine(mob/user)
	..()
	if(!isxeno(user) && !isobserver(user))
		return
	to_chat(user, "<span class='xenonotice'>[src] has <b>[obj_integrity]/[max_integrity]</b> Health and currently has <b>[charges]/[XENO_ACID_WELL_MAX_CHARGES]<b> charges.</span>")

/obj/structure/xeno/acidwell/update_icon()
	..()
	icon_state = "well[charges]"
	set_light(charges , charges / 2, LIGHT_COLOR_GREEN)

/obj/structure/xeno/acidwell/attack_alien(mob/living/carbon/xenomorph/M)
	if(M.a_intent == INTENT_HARM && CHECK_BITFIELD(M.xeno_caste.caste_flags, CASTE_IS_BUILDER) ) //If we're a builder caste and we're on harm intent, deconstruct it.
		deconstruct(TRUE, M)
		return

	repair_xeno_structure(M) //Repair if possible

	if(charges >= 5)
		to_chat(M, "<span class='xenodanger'>[src] is already full!</span>")
		return
	if(ccharging)
		to_chat(M, "<span class='xenodanger'>[src] is already being filled!</span>")
		return

	if(M.plasma_stored < XENO_ACID_WELL_FILL_COST) //You need to have enough plasma to attempt to fill the well
		to_chat(M, "<span class='xenodanger'>We don't have enough plasma to fill [src]! We need [XENO_ACID_WELL_FILL_COST - M.plasma_stored] more plasma!</span>")
		return

	ccharging = TRUE
	to_chat(M, "<span class='xenodanger'>We begin refilling [src]...</span>")
	if(!do_after(M, XENO_ACID_WELL_FILL_TIME, FALSE, src, BUSY_ICON_BUILD))
		ccharging = FALSE
		to_chat(M, "<span class='xenodanger'>We abort refilling [src]!</span>")
		return

	if(M.plasma_stored < XENO_ACID_WELL_FILL_COST)
		ccharging = FALSE
		to_chat(M, "<span class='xenodanger'>We don't have enough plasma to fill [src]! We need [XENO_ACID_WELL_FILL_COST - M.plasma_stored] more plasma!</span>")
		return

	M.plasma_stored -= XENO_ACID_WELL_FILL_COST
	charges++
	ccharging = FALSE
	update_icon()
	to_chat(M,"<span class='xenonotice'>We add acid to [src]. It is currently has [charges] / [XENO_ACID_WELL_MAX_CHARGES] charges.</span>")


/obj/structure/xeno/acidwell/Crossed(atom/A)
	. = ..()
	if(iscarbon(A))
		HasProximity(A)

/obj/structure/xeno/acidwell/HasProximity(atom/movable/AM)
	if(!isliving(AM))
		return
	var/mob/living/stepper = AM
	if(stepper.stat == DEAD)
		return
	if(!charges)
		return
	if(isxeno(stepper))
		if(!(stepper.on_fire))
			return
		stepper.ExtinguishMob()
		charges--
		update_icon()
		return

	stepper.next_move_slowdown += charges * 2 //Acid spray has slow down so this should too; scales with charges, Min 2 slowdown, Max 10
	stepper.apply_damage(charges * 10, BURN, BODY_ZONE_PRECISE_L_FOOT, stepper.run_armor_check(BODY_ZONE_PRECISE_L_FOOT, "acid") * 0.66) //33% armor pen
	stepper.apply_damage(charges * 10, BURN, BODY_ZONE_PRECISE_R_FOOT, stepper.run_armor_check(BODY_ZONE_PRECISE_R_FOOT, "acid") * 0.66) //33% armor pen
	stepper.visible_message("<span class='danger'>[stepper] is immersed in [src]'s acid!</span>", \
	"<span class='danger'>We are immersed in [src]'s acid!</span>", null, 5)
	playsound(stepper, "sound/bullets/acid_impact1.ogg", 10 * charges)
	new /obj/effect/temp_visual/acid_bath(get_turf(stepper))
	var/datum/effect_system/smoke_spread/xeno/acid/A = new(get_turf(stepper))
	A.set_up(1,src)
	A.start()
	charges = 0
	update_icon()

/obj/structure/xeno/resin_jelly_pod
	name = "Resin jelly pod"
	desc = "A large resin pod. Inside is a thick, viscous fluid that looks like it doesnt burn easily."
	icon = 'icons/Xeno/resinpod.dmi'
	icon_state = "resinpod"
	density = FALSE
	opacity = FALSE
	anchored = TRUE
	max_integrity = 250
	layer = RESIN_STRUCTURE_LAYER
	pixel_x = -16
	pixel_y = -16

	hit_sound = "alien_resin_move"
	destroy_sound = "alien_resin_move"

	soft_armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 50, "acid" = 0) //The thing that dispenses fire retarding jelly is obviously fire retardant
	///How many actual jellies the pod has stored
	var/chargesleft = 0
	///Max amount of jellies the pod can hold
	var/maxcharges = 10
	///Every 5 times this number seconds we will create a jelly
	var/recharge_rate = 10
	///Countdown to the next time we generate a jelly
	var/nextjelly = 0

/obj/structure/xeno/resin_jelly_pod/Initialize(mapload, mob/living/carbon/xenomorph/X)
	. = ..()
	add_overlay(image(icon, "resinpod_inside", layer + 0.01, dir))
	START_PROCESSING(SSslowprocess, src)

/obj/structure/xeno/resin_jelly_pod/Destroy()
	STOP_PROCESSING(SSslowprocess, src)
	return ..()

/obj/structure/xeno/resin_jelly_pod/examine(mob/user, distance, infix, suffix)
	. = ..()
	if(!isxeno(user) && !isobserver(user))
		return
	to_chat(user, "<span class='xenonotice'>This [src] has <b>[chargesleft]</b> jelly globules remaining[datum_flags & DF_ISPROCESSING ? ", and will create a new jelly in [(recharge_rate-nextjelly)*5] seconds": " and seems latent"]. \
			It has <b>[obj_integrity]/[max_integrity]</b> Health.")

/obj/structure/xeno/resin_jelly_pod/process()
	if(nextjelly <= recharge_rate)
		nextjelly++
		return
	nextjelly = 0
	chargesleft++
	if(chargesleft >= maxcharges)
		return PROCESS_KILL

/obj/structure/resin_jelly_pod/attack_alien(mob/living/carbon/xenomorph/X, damage_amount = X.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)
	if(X.a_intent == INTENT_HARM && isxenohivelord(X))
		deconstruct(TRUE, X)
		return

	repair_xeno_structure(X) //Repair if possible

	if(!chargesleft)
		to_chat(X, "<span class='xenonotice'>We reach into \the [src], but only find dregs of resin. We should wait some more.</span>")
		return
	to_chat(X, "<span class='xenonotice'>We retrieve a resin jelly from \the [src].</span>")
	new /obj/item/resin_jelly(loc)
	chargesleft--
	if(!(datum_flags & DF_ISPROCESSING) && (chargesleft < maxcharges))
		START_PROCESSING(SSslowprocess, src)

/obj/item/resin_jelly
	name = "resin jelly"
	desc = "A foul, viscous resin jelly that doesnt seem to burn easily."
	icon = 'icons/unused/Marine_Research.dmi'
	icon_state = "biomass"
	soft_armor = list("fire" = 200)
	var/immune_time = 15 SECONDS

/obj/item/resin_jelly/attack_alien(mob/living/carbon/xenomorph/X, damage_amount = X.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)
	if(X.xeno_caste.caste_flags & CASTE_CAN_HOLD_JELLY)
		return attack_hand(X)
	if(X.action_busy)
		return
	X.visible_message("<span class='notice'>[X] starts to cover themselves in a foul substance...</span>", "<span class='xenonotice'>We begin to cover ourselves in a foul substance...</span>")
	if(!do_after(X, 2 SECONDS, TRUE, X, BUSY_ICON_MEDICAL))
		return
	if(X.fire_resist_modifier <= -20)
		return
	activate_jelly(X)

/obj/item/resin_jelly/attack_self(mob/living/carbon/xenomorph/user)
	if(!isxeno(user))
		return
	if(user.action_busy)
		return
	user.visible_message("<span class='notice'>[user] starts to cover themselves in a foul substance...</span>", "<span class='xenonotice'>We begin to cover ourselves in a foul substance...</span>")
	if(!do_after(user, 2 SECONDS, TRUE, user, BUSY_ICON_MEDICAL))
		return
	if(user.fire_resist_modifier <= -20)
		return
	activate_jelly(user)

/obj/item/resin_jelly/attack(mob/living/carbon/xenomorph/M, mob/living/user)
	if(!isxeno(user))
		return TRUE
	if(!isxeno(M))
		to_chat(user, "<span class='xenonotice'>We cannot apply the [src] to this creature.</span>")
		return FALSE
	if(user.action_busy)
		return FALSE
	if(!do_after(user, 1 SECONDS, TRUE, M, BUSY_ICON_MEDICAL))
		return FALSE
	if(M.fire_resist_modifier <= -20)
		return FALSE
	user.visible_message("<span class='notice'>[user] smears a viscous substance on [M].</span>","<span class='xenonotice'>We carefully smear [src] onto [user].</span>")
	activate_jelly(M)
	user.temporarilyRemoveItemFromInventory(src)
	return FALSE

/obj/item/resin_jelly/proc/activate_jelly(mob/living/carbon/xenomorph/user)
	user.visible_message("<span class='notice'>[user]'s chitin begins to gleam with an unseemly glow...</span>", "<span class='xenonotice'>We feel powerful as we are covered in [src]!</span>")
	user.emote("roar")
	user.add_filter("resin_jelly_outline", 2, list("type" = "outline", "size" = 1, "color" = COLOR_RED))
	user.fire_resist_modifier -= 20
	forceMove(user)//keep it here till the timer finishes
	user.temporarilyRemoveItemFromInventory(src)
	addtimer(CALLBACK(src, .proc/deactivate_jelly, user), immune_time)

/obj/item/resin_jelly/proc/deactivate_jelly(mob/living/carbon/xenomorph/user)
	user.remove_filter("resin_jelly_outline")
	user.fire_resist_modifier += 20
	to_chat(user, "<span class='xenonotice'>We feel more vulnerable again.</span>")
	qdel(src)

///Standardized proc for dismantling xeno structures; usually called when a xeno uses harm intent on xeno structure
/obj/structure/xeno/deconstruct(disassembled = TRUE, mob/living/carbon/xenomorph/M, dismantle_time = XENO_DISMANTLE_TIME, custom_message_a, custom_message_b)

	if(flags_atom & NODECONSTRUCT)
		return

	if(!disassembled || !M) //If we have a xeno defined and are actually disassembling the structure
		return ..()

	if(!custom_message_a)
		M.visible_message("<span class='warning'>\The [M] digs into \the [src] and begins ripping it down.</span>", \
		"<span class='xenoannounce'>We dig into \the [src] and begin ripping it down.</span>", null, 5)
	else
		to_chat(M, "[custom_message_a]")

	if(!do_after(M, XENO_DISMANTLE_TIME, FALSE, src, BUSY_ICON_HOSTILE))
		return

	M.do_attack_animation(src, ATTACK_EFFECT_CLAW) //SFX
	playsound(src, "alien_resin_break", 25) //SFX

	if(!custom_message_b)
		M.visible_message("<span class='danger'>[M] rips down \the [src]!</span>", \
		"<span class='xenoannounce'>We rip down \the [src]!</span>", null, 5)
	else
		to_chat(M, "[custom_message_b]")

	return ..()

//*******************
//Resin Silo
//*******************

/obj/structure/xeno/silo
	icon = 'icons/Xeno/resin_silo.dmi'
	icon_state = "brown_silo"
	name = "resin silo"
	desc = "A slimy, oozy resin bed filled with foul-looking egg-like ...things."
	bound_width = 96
	bound_height = 96
	max_integrity = 400
	hit_sound = "alien_resin_break"
	layer = RESIN_STRUCTURE_LAYER
	resistance_flags = UNACIDABLE

	hit_sound = "alien_resin_move"
	destroy_sound = "alien_resin_move"

	soft_armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 50, "bio" = 0, "rad" = 0, "fire" = 80, "acid" = 0) //Explosion resistant and highly fire resistant; so we don't have to snowflake ex and fire_act

	var/turf/center_turf
	var/datum/hive_status/associated_hive
	var/silo_area
	COOLDOWN_DECLARE(silo_damage_alert_cooldown)
	COOLDOWN_DECLARE(silo_proxy_alert_cooldown)

/obj/structure/xeno/silo/attack_hand(mob/living/user)
	to_chat(user, "<span class='warning'>You scrape ineffectively at \the [src].</span>")
	return TRUE

/obj/structure/xeno/silo/Initialize(mapload, mob/living/carbon/xenomorph/X)
	. = ..()

	var/static/number = 1
	name = "[name] [number]"
	number++

	GLOB.xeno_resin_silos += src
	center_turf = get_step(src, NORTHEAST)
	if(!istype(center_turf))
		center_turf = loc

	for(var/i in RANGE_TURFS(2, src))
		RegisterSignal(i, COMSIG_ATOM_ENTERED, .proc/resin_silo_proxy_alert)

	return INITIALIZE_HINT_LATELOAD


/obj/structure/xeno/silo/LateInitialize()
	. = ..()
	if(!locate(/obj/effect/alien/weeds) in center_turf)
		new /obj/effect/alien/weeds/node(center_turf)
	if(hivenumber) //Set our hivenumber; default to xeno_hive_normal if none
		associated_hive = GLOB.hive_datums[hivenumber]
	else
		associated_hive = GLOB.hive_datums[XENO_HIVE_NORMAL]
	if(associated_hive)
		RegisterSignal(associated_hive, list(COMSIG_HIVE_XENO_MOTHER_PRE_CHECK, COMSIG_HIVE_XENO_MOTHER_CHECK), .proc/is_burrowed_larva_host)
	silo_area = get_area(src)

/obj/structure/xeno/silo/Destroy()
	GLOB.xeno_resin_silos -= src
	if(associated_hive)
		UnregisterSignal(associated_hive, list(COMSIG_HIVE_XENO_MOTHER_PRE_CHECK, COMSIG_HIVE_XENO_MOTHER_CHECK))
		//Since resin silos are more important now, we need a better notification.
		associated_hive.xeno_message("<span class='xenoannounce'>A resin silo has been destroyed at [AREACOORD_NO_Z(src)]!</span>", 2, FALSE, src, 'sound/voice/alien_help2.ogg')
		associated_hive = null
		notify_ghosts("\ A resin silo has been destroyed at [AREACOORD_NO_Z(src)]!", source = get_turf(src), action = NOTIFY_ORBIT)

	for(var/i in contents)
		var/atom/movable/AM = i
		AM.forceMove(get_step(center_turf, pick(CARDINAL_ALL_DIRS)))
	playsound(loc,'sound/effects/alien_egg_burst.ogg', 75)

	silo_area = null
	center_turf = null
	STOP_PROCESSING(SSslowprocess, src)
	return ..()


/obj/structure/xeno/silo/examine(mob/user)
	. = ..()
	var/current_integrity = (obj_integrity / max_integrity) * 100
	switch(current_integrity)
		if(0 to 20)
			to_chat(user, "<span class='warning'>It's barely holding, there's leaking oozes all around, and most eggs are broken. Yet it is not inert.</span>")
		if(20 to 40)
			to_chat(user, "<span class='warning'>It looks severely damaged, its movements slow.</span>")
		if(40 to 60)
			to_chat(user, "<span class='warning'>It's quite beat up, but it seems alive.</span>")
		if(60 to 80)
			to_chat(user, "<span class='warning'>It's slightly damaged, but still seems healthy.</span>")
		if(80 to 100)
			to_chat(user, "<span class='info'>It appears in good shape, pulsating healthily.</span>")


/obj/structure/xeno/silo/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()

	//We took damage, so it's time to start regenerating if we're not already processing
	if(!CHECK_BITFIELD(datum_flags, DF_ISPROCESSING))
		START_PROCESSING(SSslowprocess, src)

	resin_silo_damage_alert()

/obj/structure/xeno/silo/proc/resin_silo_damage_alert()
	if(!COOLDOWN_CHECK(src, silo_damage_alert_cooldown))
		return

	associated_hive.xeno_message("<span class='xenoannounce'>Our [name] at [AREACOORD_NO_Z(src)] is under attack! It has [obj_integrity]/[max_integrity] Health remaining.</span>", 2, FALSE, src, 'sound/voice/alien_help1.ogg')
	COOLDOWN_START(src, silo_damage_alert_cooldown, XENO_HEALTH_ALERT_COOLDOWN) //set the cooldown.

///Alerts the Hive when hostiles get too close to their resin silo
/obj/structure/xeno/silo/proc/resin_silo_proxy_alert(datum/source, atom/hostile)
	SIGNAL_HANDLER

	if(!COOLDOWN_CHECK(src, silo_proxy_alert_cooldown)) //Proxy alert triggered too recently; abort
		return

	if(!isliving(hostile))
		return

	var/mob/living/living_triggerer = hostile
	if(living_triggerer.stat == DEAD) //We don't care about the dead
		return

	if(isxeno(hostile))
		var/mob/living/carbon/xenomorph/X = hostile
		if(X.hive == associated_hive) //Trigger proxy alert only for hostile xenos
			return

	if(get_dist(loc, hostile) > 2) //Can only send alerts for those within 2 of us; so we don't have all silos sending alerts when one is proxy tripped
		return

	associated_hive.xeno_message("<span class='xenoannounce'>Our [name] has detected a nearby hostile [hostile] at [AREACOORD_NO_Z(hostile)]. [name] has [obj_integrity]/[max_integrity] Health remaining.</span>", 2, FALSE, hostile, 'sound/voice/alien_help1.ogg')
	COOLDOWN_START(src, silo_proxy_alert_cooldown, XENO_HEALTH_ALERT_COOLDOWN) //set the cooldown.


/obj/structure/xeno/silo/process()
	//Regenerate if we're at less than max integrity
	if(obj_integrity < max_integrity)
		obj_integrity = min(obj_integrity + 25, max_integrity) //Regen 5 HP per sec
		return

	//If we're at max integrity, stop regenerating and processing.
	return PROCESS_KILL

/obj/structure/xeno/silo/proc/is_burrowed_larva_host(datum/source, list/mothers, list/silos)
	SIGNAL_HANDLER
	if(associated_hive)
		silos += src


//*******************
//Corpse recyclinging
//*******************
/obj/structure/xeno/silo/attackby(obj/item/I, mob/user, params)
	. = ..()
	if(!isxeno(user)) //only xenos can deposit corpses
		return

	if(!istype(I, /obj/item/grab))
		return

	var/obj/item/grab/G = I
	if(!iscarbon(G.grabbed_thing))
		return
	var/mob/living/carbon/victim = G.grabbed_thing
	if(!(ishuman(victim) || ismonkey(victim))) //humans and monkeys only for now
		to_chat(user, "<span class='notice'>[src] can only process humanoid anatomies!</span>")
		return

	if(victim.chestburst)
		to_chat(user, "<span class='notice'>[victim] has already been exhausted to incubate a sister!</span>")
		return

	if(issynth(victim))
		to_chat(user, "<span class='notice'>[victim] has no useful biomass for us.</span>")
		return

	if(ishuman(victim))
		var/mob/living/carbon/human/H = victim
		if(check_tod(H))
			to_chat(user, "<span class='notice'>[H] still has some signs of life. We should headbite it to finish it off.</span>")
			return

	visible_message("[user] starts putting [victim] into [src].", 3)

	if(!do_after(user, 20, FALSE, victim, BUSY_ICON_DANGER) || QDELETED(src))
		return

	victim.chestburst = 2 //So you can't reuse corpses if the silo is destroyed
	victim.update_burst()
	victim.forceMove(src)

	if(prob(5)) //5% chance to play
		shake(4 SECONDS)
	else
		playsound(loc, 'sound/effects/blobattack.ogg', 25)

	var/datum/job/xeno_job = SSjob.GetJobType(/datum/job/xenomorph)
	xeno_job.add_job_points(1.75) //4 corpses per burrowed; 7 points per larva

	log_combat(victim, user, "was consumed by a resin silo")
	log_game("[key_name(victim)] was consumed by a resin silo at [AREACOORD(victim.loc)].")

	GLOB.round_statistics.xeno_silo_corpses++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "xeno_silo_corpses")

/obj/structure/xeno/silo/proc/shake(duration)
	var/offset = prob(50) ? -2 : 2
	var/old_pixel_x = pixel_x
	var/shake_sound = rand(1, 100) == 1 ? 'sound/machines/blender.ogg' : 'sound/machines/juicer.ogg'
	playsound(src, shake_sound, 25, TRUE)
	animate(src, pixel_x = pixel_x + offset, time = 2, loop = -1) //start shaking
	addtimer(CALLBACK(src, .proc/stop_shake, old_pixel_x), duration)

/obj/structure/xeno/silo/proc/stop_shake(old_px)
	animate(src)
	pixel_x = old_px

