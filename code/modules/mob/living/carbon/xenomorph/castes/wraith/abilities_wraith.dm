// ***************************************
// *********** Place Warp Shadow
// ***************************************
/datum/action/xeno_action/place_warp_shadow
	name = "Place Warp Shadow"
	action_icon_state = "warp_shadow"
	mechanics_text = "Binds our psychic essence to a spot of our choosing. We can use Hyperposition to swap locations with this essence."
	plasma_cost = 150
	cooldown_timer = 60 SECONDS
	keybind_signal = COMSIG_XENOABILITY_PLACE_WARP_BEACON

/datum/action/xeno_action/place_warp_shadow/action_activate()
	var/mob/living/carbon/xenomorph/wraith/TI = owner

	TI.visible_message("<span class='xenowarning'>The air starts to violently roil and shimmer around [TI]!</span>", \
	"<span class='xenodanger'>We begin to imprint our essence upon reality, causing the air about us to roil and shimmer...</span>") //Fluff

	if(!do_after(TI, WRAITH_PLACE_WARP_BEACON_WINDUP, TRUE, TI, BUSY_ICON_BUILD)) //Channel time/wind up
		TI.visible_message("<span class='xenowarning'>The space around [TI] abruptly stops shifting and wavering.</span>", \
		"<span class='xenodanger'>We cease binding our essence to this place...</span>")
		return fail_activate()

	var/turf/T = get_turf(TI)
	TI.visible_message("<span class='xenonotice'>\A shimmering point suddenly coalesces from the warped space around [T].</span>", \
	"<span class='xenodanger'>We complete our work, binding our essence to this point.</span>", null, 5) //Fluff
	var/obj/effect/xenomorph/warp_shadow/WB = new(T) //Create the new beacon.
	playsound(T, 'sound/weapons/emitter.ogg', 25, 1)
	QDEL_NULL(TI.warp_shadow) //Delete the old beacon
	TI.warp_shadow = WB //Set our warp shadow
	WB.dir = TI.dir //Have it imitate our facing
	WB.pixel_x = TI.pixel_x //Inherit pixel offsets
	teleport_debuff_aoe(WB) //SFX

	succeed_activate()
	add_cooldown()


// ***************************************
// *********** Hyperposition
// ***************************************
/datum/action/xeno_action/hyperposition
	name = "Hyperposition"
	action_icon_state = "hyperposition"
	mechanics_text = "We teleport back to our warp shadow after a delay. The delay scales with the distance teleported."
	plasma_cost = 25
	cooldown_timer = 5 SECONDS
	keybind_signal = COMSIG_XENOABILITY_HYPERPOSITION


/datum/action/xeno_action/hyperposition/action_activate()

	var/mob/living/carbon/xenomorph/wraith/TI = owner
	var/obj/effect/xenomorph/warp_shadow/WB = TI.warp_shadow

	if(!WB)
		to_chat(TI, "<span class='xenodanger'>We have no warp shadow to teleport to!</span>")
		return fail_activate()

	var/area/A = get_area(WB)

	TI.do_jitter_animation(2000) //Animation

	var/distance = get_dist(TI, TI.warp_shadow) //Get the distance so we can calculate the wind up
	var/hyperposition_windup = clamp(WRAITH_HYPERPOSITION_MIN_WINDUP, distance * 0.5 SECONDS - 5 SECONDS, WRAITH_HYPERPOSITION_MAX_WINDUP)

	TI.visible_message("<span class='warning'>The air starts to violently roil and shimmer around [TI]!</span>", \
	"<span class='xenodanger'>We begin to teleport to our warp shadow located at [A] (X: [WB.x], Y: [WB.y]). We estimate this will take [hyperposition_windup * 0.1] seconds.</span>")

	if(!do_after(TI, hyperposition_windup, TRUE, TI, BUSY_ICON_FRIENDLY)) //Channel time/wind up
		TI.visible_message("<span class='xenowarning'>The space around [TI] abruptly stops shifting and wavering.</span>", \
		"<span class='xenodanger'>We abort teleporting back to our warp shadow.</span>")
		return fail_activate()


	hyperposition_warp() //We swap positions with our warp shadow

	succeed_activate()
	GLOB.round_statistics.wraith_hyperpositions++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "wraith_hyperpositions") //Statistics

	add_cooldown()

/datum/action/xeno_action/hyperposition/proc/hyperposition_warp() //This handles the location swap between the Wraith and the Warp Shadow

	var/mob/living/carbon/xenomorph/wraith/TI = owner
	var/obj/effect/xenomorph/warp_shadow/WB = TI.warp_shadow
	var/beacon_turf = get_turf(WB)
	var/wraith_turf = get_turf(TI)

	if(!TI) //Sanity
		return FALSE

	if(!WB)
		to_chat(TI, "<span class='xenodanger'>We have no warp shadow to teleport to!</span>")
		return FALSE

	if(!beacon_turf || !wraith_turf)
		to_chat(TI, "<span class='xenodanger'>Our warp shadow is currently beyond our power to influence!</span>")
		return FALSE

	WB.forceMove(wraith_turf) //Move the beacon to where we are leaving
	WB.dir = TI.dir //Have it imitate our facing
	WB.pixel_x = TI.pixel_x //Inherit pixel offsets
	teleport_debuff_aoe(TI) //Apply tele debuff

	TI.forceMove(beacon_turf) //Move to where the beacon was
	teleport_debuff_aoe(TI) //Apply tele debuff

	var/area/A = get_area(WB)
	TI.visible_message("<span class='warning'>\ [TI] suddenly vanishes in a vortex of warped space!</span>", \
	"<span class='xenodanger'>We teleport, swapping positions with our warp shadow. Our warp shadow has moved to [A] (X: [WB.x], Y: [WB.y]).</span>", null, 5) //Let user know the new location


// ***************************************
// *********** Phase Shift
// ***************************************
/datum/action/xeno_action/phase_shift
	name = "Phase Shift"
	action_icon_state = "stealth_on"
	mechanics_text = "We force ourselves temporarily out of sync with reality, allowing us to become incorporeal and move through any physical obstacles for a short duration."
	plasma_cost = 75
	cooldown_timer = 20 SECONDS
	keybind_signal = COMSIG_XENOABILITY_PHASE_SHIFT
	var/turf/starting_turf = null


/datum/action/xeno_action/phase_shift/action_activate()
	var/mob/living/carbon/xenomorph/wraith/TI = owner

	TI.visible_message("<span class='warning'>[TI.name] is becoming faint and translucent!</span>", \
	"<span class='xenodanger'>We begin to move out of phase with reality....</span>") //Fluff

	TI.do_jitter_animation(2000) //Animation

	if(!do_after(TI, WRAITH_PHASE_SHIFT_WINDUP, TRUE, TI, BUSY_ICON_FRIENDLY)) //Channel time/wind up
		TI.visible_message("<span class='xenowarning'>[TI]'s form abruptly consolidates, returning to normalcy.</span>", \
		"<span class='xenodanger'>We abort our desynchronization.</span>")
		return fail_activate()

	addtimer(CALLBACK(GLOBAL_PROC, .proc/to_chat, TI, "<span class='highdanger'>We begin to move back into phase with reality...</span>"), WRAITH_PHASE_SHIFT_DURATION * 0.7) //Warn them when Phase Shift is about to end
	addtimer(CALLBACK(TI, /mob/.proc/playsound_local, TI, 'sound/voice/hiss4.ogg', 50), WRAITH_PHASE_SHIFT_DURATION * 0.7)
	addtimer(CALLBACK(src, .proc/phase_shift_deactivate), WRAITH_PHASE_SHIFT_DURATION)

	TI.status_flags = GODMODE | INCORPOREAL //Become temporarily invulnerable and incorporeal
	TI.resistance_flags = RESIST_ALL
	TI.density = FALSE
	TI.throwpass = TRUE
	TI.alpha = WRAITH_PHASE_SHIFT_ALPHA //Become translucent

	starting_turf = get_turf(TI) //Get our starting turf so we can calculate the stun duration later.

	GLOB.round_statistics.wraith_phase_shifts++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "wraith_phase_shifts") //Statistics

	succeed_activate()
	add_cooldown()


/datum/action/xeno_action/phase_shift/proc/phase_shift_deactivate()

	var/mob/living/carbon/xenomorph/wraith/TI = owner

	if(!TI) //Sanity
		return

	TI.status_flags = initial(TI.status_flags) //Become merely mortal again
	TI.resistance_flags = initial(TI.resistance_flags)
	TI.density = initial(TI.density)
	TI.throwpass = initial(TI.throwpass)
	TI.alpha = initial(TI.alpha) //Become opaque

	playsound(owner, "sound/effects/escape_pod_launch.ogg", 25, 0, 1)

	var/current_turf = get_turf(TI)

	if(isclosedturf(current_turf) || isspaceturf(current_turf)) //So we rematerialized in a solid wall/space for some reason; Darwin award winner folks.
		to_chat(TI, "<span class='highdanger'>As we idiotically rematerialize in an obviously unsafe position, we revert to where we slipped out of reality through sheer instinct, albeit at great cost.</span>")
		TI.adjustFireLoss(TI.maxHealth * 0.5, TRUE) //Lose half of our maximum health
		TI.apply_status_effect(STATUS_EFFECT_STUN, 10 SECONDS) //That oughta teach them.
		TI.forceMove(starting_turf)
		teleport_debuff_aoe(TI) //Debuff when we reappear
		starting_turf = null
		return

	var/distance = get_dist(current_turf, starting_turf)
	var/phase_shift_stun_time = clamp(0.5 SECONDS, distance * 0.1 SECONDS, 3 SECONDS) //Recovery time
	TI.apply_status_effect(STATUS_EFFECT_STUN, phase_shift_stun_time * 2)

	TI.visible_message("<span class='warning'>[TI.name] form wavers and becomes opaque.</span>", \
	"<span class='highdanger'>We phase back into reality, our mind reeling from the experience. We estimate we will take [phase_shift_stun_time * 0.1] seconds to recover!</span>")

	starting_turf = null

/datum/action/xeno_action/evasion/on_cooldown_finish()

	if(!owner) //Sanity
		return

	to_chat(owner, "<span class='xenonotice'>We are able to fade from reality again.</span>")
	owner.playsound_local(owner, 'sound/effects/xeno_newlarva.ogg', 25, 0, 1)
	return ..()


// ***************************************
// *********** Blink
// ***************************************
/datum/action/xeno_action/activable/blink
	name = "Blink"
	action_icon_state = "blink"
	mechanics_text = "We teleport ourselves a short distance to a location within line of sight."
	use_state_flags = XABB_TURF_TARGET
	plasma_cost = 50
	cooldown_timer = 0.5 SECONDS
	keybind_signal = COMSIG_XENOABILITY_BLINK

/datum/action/xeno_action/activable/blink/can_use_ability(atom/A, silent = FALSE, override_flags)
	. = ..()
	var/turf/T = get_turf(A)

	if(!T)
		to_chat(owner, "<span class='xenowarning'>Even we cannot go there!</span>")
		return FALSE

	if(isclosedturf(T) || isspaceturf(T))
		to_chat(owner, "<span class='xenowarning'>We cannot blink here!</span>")
		return FALSE

	if(!owner.line_of_sight(T) || A.opacity) //Needs to be in line of sight.
		to_chat(owner, "<span class='xenowarning'>We can't blink without line of sight to our destination!</span>")
		return FALSE



/datum/action/xeno_action/activable/blink/use_ability(atom/A)

	var/turf/T = get_turf(A)
	var/distance = get_dist(owner, T)
	if(distance > WRAITH_BLINK_RANGE) //If it's out of range, try to go as far as possible
		var/list/turf/turfs = getline(owner, T)
		for(var/turf/T2 in turfs)
			if(get_dist(owner, T2) == WRAITH_BLINK_RANGE) //Find the turf at the max distance we can go and break
				T = T2
				break
			else
				continue

	if(!can_use_ability(T)) //Since we updated the turf, check it again.
		fail_activate()

	var/mob/living/carbon/xenomorph/wraith/TI = owner
	var/mob/pulled

	if(ismob(TI.pulling)) //bring the target we're pulling with us, but at the cost of sharply increasing the next cooldown
		pulled = TI.pulling

	blink_warp(TI, T, pulled)

	succeed_activate()
	add_cooldown()

	GLOB.round_statistics.wraith_blinks++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "wraith_blinks") //Statistics


/datum/action/xeno_action/activable/blink/proc/blink_warp(mob/living/carbon/xenomorph/wraith/TI, turf/T, mob/pulled = null) //This handles the location swap between the Wraith and the Warp Shadow

	TI.face_atom(T) //Face the target so we don't look like an ass

	teleport_debuff_aoe(TI) //Debuff when we vanish

	TI.forceMove(T) //Teleport to our target turf

	if(pulled) //bring the pulled target with us if applicable
		cooldown_timer *= WRAITH_BLINK_DRAG_MULTIPLIER
		to_chat(TI, "<span class='xenodanger'>We bring [pulled.name] with us. We won't be ready to blink again for [cooldown_timer * 0.1] seconds due to the strain of doing so.</span>")

	teleport_debuff_aoe(TI) //Debuff when we reappear


/datum/action/xeno_action/proc/teleport_debuff_aoe(atom/movable/teleporter, silent = FALSE, no_visuals = FALSE) //Called by many of the Wraith' teleportation effects

	if(!teleporter) //Sanity
		return

	var/mob/living/carbon/xenomorph/source = owner

	if(!silent) //Sound effects
		playsound(teleporter, 'sound/effects/EMPulse.ogg', 25, 1) //Sound at the location we are arriving at

	if(!no_visuals) //Visuals
		new /obj/effect/temp_visual/blink_portal(get_turf(teleporter))

	for(var/turf/affected_tile in range(1,teleporter.loc))
		affected_tile.Shake(4, 4, 1 SECONDS) //SFX
		for(var/mob/living/target in affected_tile)
			target.Shake(4, 4, 1 SECONDS) //SFX
			if(target.stat == DEAD)
				continue
			if(isxeno(target))
				var/mob/living/carbon/xenomorph/X = target
				if(X.hive == source.hive) //No friendly fire
					continue

			shake_camera(target, 2, 1)
			target.adjust_stagger(WRAITH_TELEPORT_DEBUFF_STACKS)
			target.add_slowdown(WRAITH_TELEPORT_DEBUFF_STACKS)
			target.adjust_drugginess(WRAITH_TELEPORT_DEBUFF_STACKS) //minor visual distortion
			to_chat(target, WRAITH_TELEPORT_DEBUFF_MSG)

/datum/action/xeno_action/evasion/on_cooldown_finish()
	if(!owner) //Sanity
		return

	if(cooldown_timer > initial(cooldown_timer) ) //Reset the cooldown if increased from dragging someone.
		to_chat(owner, "<span class='xenonotice'>We are able to take blink again.</span>")
		owner.playsound_local(owner, 'sound/effects/xeno_newlarva.ogg', 25, 0, 1)
		cooldown_timer = initial(cooldown_timer)
	return ..()

// ***************************************
// *********** Banish
// ***************************************
/datum/action/xeno_action/activable/banish
	name = "Banish"
	action_icon_state = "banish"
	mechanics_text = "We banish a target object or creature within line of sight to nullspace for a short duration. Can target onself and allies."
	use_state_flags = XACT_TARGET_SELF
	plasma_cost = 100
	cooldown_timer = 20 SECONDS
	keybind_signal = COMSIG_XENOABILITY_BANISH
	var/turf/banished_turf = null //The turf the target was banished on
	var/atom/movable/banishment_target = null //Target we've banished
	var/obj/effect/temp_visual/banishment_portal/portal = null //SFX indicating the banished target's position

/datum/action/xeno_action/activable/banish/give_action(mob/living/L)
	. = ..()
	RegisterSignal(L, COMSIG_XENOMORPH_WRAITH_RECALL, .proc/banish_deactivate)

/datum/action/xeno_action/activable/banish/remove_action(mob/living/L)
	UnregisterSignal(L, COMSIG_XENOMORPH_WRAITH_RECALL)
	return ..()


/datum/action/xeno_action/activable/banish/can_use_ability(atom/A, silent = FALSE, override_flags)
	. = ..()

	if(!ismovable(A) || A.resistance_flags == RESIST_ALL) //Cannot banish non-movables/things that are supposed to be invul
		to_chat(owner, "<span class='xenowarning'>We cannot banish this!</span>")
		return FALSE

	var/distance = get_dist(owner, A)
	if(distance > WRAITH_BANISH_RANGE) //Needs to be in range.
		to_chat(owner, "<span class='xenowarning'>Our target is too far away! It must be [distance - WRAITH_BANISH_RANGE] tiles closer!</span>")
		return FALSE

	if(!owner.line_of_sight(A)) //Needs to be in line of sight.
		to_chat(owner, "<span class='xenowarning'>We can't banish without line of sight to our target!</span>")
		return FALSE

/datum/action/xeno_action/activable/banish/use_ability(atom/movable/A)
	var/mob/living/carbon/xenomorph/wraith/TI = owner
	banished_turf = get_turf(A) //Set the banishment turf.
	banishment_target = A //Set the banishment target

	TI.face_atom(A) //Face the target so we don't look like an ass

	teleport_debuff_aoe(banishment_target) //Debuff when we disappear
	banishment_target.moveToNullspace() //Banish the target to Brazil; yes he's going there
	portal = new /obj/effect/temp_visual/banishment_portal(banished_turf)

	var/duration = WRAITH_BANISH_BASE_DURATION //Set the duration

	if(isxeno(banishment_target) ) //We halve the max duration for living non-allies
		var/mob/living/carbon/xenomorph/X = banishment_target
		if(X.hive != TI.hive) //Enemy hive
			duration *= 0.5

	else if(isliving(banishment_target) ) //We halve the max duration for living non-allies
		duration *= 0.5

	banishment_target.visible_message("<span class='warning'>Space abruptly twists and warps around [banishment_target.name] as it suddenly vanishes!</span>", \
	"<span class='highdanger'>The world around you reels, reality seeming to twist and tear until you find yourself trapped in a forsaken void beyond space and time.</span>")
	playsound(banished_turf, 'sound/weapons/emitter2.ogg', 50, 1) //this isn't quiet

	to_chat(TI,"<span class='xenodanger'>We have banished [banishment_target.name] to nullspace for [duration * 0.1] seconds.</span>")

	addtimer(CALLBACK(src, .proc/banish_warning), duration * 0.7) //Warn when Banish is about to end
	addtimer(CALLBACK(src, .proc/banish_deactivate), duration)

	succeed_activate()
	add_cooldown()

	GLOB.round_statistics.wraith_banishes++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "wraith_banishes") //Statistics

/datum/action/xeno_action/activable/banish/proc/banish_warning()
	var/mob/living/carbon/xenomorph/wraith/TI = owner

	if(!TI) //Sanity
		return

	if(!banished_turf || !banishment_target)
		return

	to_chat(TI,"<span class='highdanger'>Our banishment target [banishment_target.name] is about to return!</span>")
	owner.playsound_local(owner, 'sound/voice/hiss4.ogg', 50, 0, 1)


/datum/action/xeno_action/activable/banish/proc/banish_deactivate()
	SIGNAL_HANDLER
	var/mob/living/carbon/xenomorph/wraith/TI = owner

	if(!TI) //Sanity
		return

	if(!banished_turf || !banishment_target)
		return

	banishment_target.forceMove(banished_turf)
	teleport_debuff_aoe(banishment_target) //Debuff/distortion when we reappear

	banishment_target.visible_message("<span class='warning'>[banishment_target.name] abruptly reappears!</span>", \
	"<span class='warning'>You suddenly reappear back in what you believe to be reality. It takes you a moment to regain your bearings.</span>")

	if(isliving(banishment_target))
		var/mob/living/L = banishment_target
		L.Stun(1 SECONDS) //Short stun upon returning to reality

	to_chat(TI, "<span class='xenodanger'>Our target [banishment_target.name] has returned to reality.</span>") //Always alert the Wraith

	if(portal)
		QDEL_NULL(portal) //Eliminate the Brazil portal if we need to

	banishment_target = null //Clear vars
	banished_turf = null
	portal = null

	return COMPONENT_BANISH_TARGETS_EXIST //For the recall sub-ability

// ***************************************
// *********** Recall
// ***************************************
/datum/action/xeno_action/recall
	name = "Recall"
	action_icon_state = "recall"
	mechanics_text = "We recall a target we've banished back from the depths of nullspace."
	use_state_flags = XACT_USE_NOTTURF //So we can recall ourselves from nether Brazil
	cooldown_timer = 1 SECONDS //Token for anti-spam
	keybind_signal = COMSIG_XENOABILITY_RECALL


/datum/action/xeno_action/recall/action_activate()

	if(!(SEND_SIGNAL(owner, COMSIG_XENOMORPH_WRAITH_RECALL) & COMPONENT_BANISH_TARGETS_EXIST))
		to_chat(owner,"<span class='xenodanger'>We have no targets banished!</span>")
		return fail_activate()

	succeed_activate()
	add_cooldown()

