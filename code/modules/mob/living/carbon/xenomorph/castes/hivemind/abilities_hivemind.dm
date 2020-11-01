/datum/action/xeno_action/return_to_core
	name = "Return to Core"
	action_icon_state = "lay_hivemind"
	mechanics_text = "Teleport back to your core."
// ***************************************
// *********** Reposition Core
// ***************************************
/datum/action/xeno_action/activable/reposition_core
	name = "Reposition Core"
	action_icon_state = "emit_neurogas"
	mechanics_text = "Reposition your core to a target location on weeds. The further away the location is the longer this will take up to a maximum of 60 seconds. 3 minute cooldown."
	ability_name = "reposition core"
	plasma_cost = 150
	cooldown_timer = 300 SECONDS
	keybind_flags = XACT_KEYBIND_USE_ABILITY
	keybind_signal = COMSIG_XENOABILITY_REPOSITION_CORE

/datum/action/xeno_action/return_to_core/action_activate()
	SEND_SIGNAL(owner, COMSIG_XENOMORPH_CORE_RETURN)

/datum/action/xeno_action/activable/reposition_core/on_cooldown_finish()
	owner.playsound_local(owner.loc, 'sound/voice/alien_drool1.ogg', 50, TRUE)
	to_chat(owner, "<span class='xenonotice'>We regain the strength to reposition our neural core.</span>")
	return ..()

/datum/action/xeno_action/activable/reposition_core/can_use_ability(atom/target, silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE
	if(QDELETED(target))
		return FALSE

	var/turf/target_turf = target
	var/mob/living/carbon/xenomorph/hivemind/X = owner

	if(!X.hivemind_weed_vibecheck()) //If no weeds are within range, we get yeeted back to Brazil
		return FALSE

	if(!istype(X))
		return FALSE

	if(!check_build_location(target_turf, X))
		return FALSE

/datum/action/xeno_action/activable/reposition_core/use_ability(atom/A)
	var/mob/living/carbon/xenomorph/hivemind/X = owner
	var/obj/effect/alien/hivemindcore/core = X.core
	var/turf/target_turf = get_turf(X)
	var/distance = get_dist(target_turf, get_turf(core))

	var/delay = max(HIVEMIND_REPOSITION_CORE_DELAY_MIN, HIVEMIND_REPOSITION_CORE_DELAY_MOD * distance) //Calculate the distance scaling delay before we complete the reposition


	if(!check_build_location(target_turf, X)) //Check target turf for suitability
		return fail_activate()
	to_chat(owner, "<span class='xenodanger'>We begin the process of transfering our consciousness... We estimate this will require [delay * 0.1] seconds.</span>")

	succeed_activate()
	if(!do_after(X, delay, TRUE, null, BUSY_ICON_BUILD))
		if(!QDELETED(src))
			to_chat(X, "<span class='xenodanger'>We abort transferring our consciousness, expending our precious plasma for naught.</span>")
			return fail_activate()

	if(!can_use_ability(target_turf))
		return fail_activate()

	core.forceMove(get_turf(target_turf)) //Move the core
	core.obj_integrity = 1 //Reset the core's health to 1; travelling is hard, exhausting work!
	to_chat(X, "<span class='xenodanger'>We succeed in transferring our consciousness to a new neural core!</span>")

	add_cooldown()

	GLOB.round_statistics.hivemind_reposition_core_uses++ //Increment the statistics
	SSblackbox.record_feedback("tally", "round_statistics", 1, "hivemind_reposition_core_uses")

	//Now we handle announcements
	if(!is_centcom_level(core))
		var/area/new_core_area = get_area(core)
		xeno_message("Hive: \ [X] has <b>transferred its core</b>[A? " to [sanitize(new_core_area.name)]":""]!", 3, X.hivenumber) //Let the hive know the Hivemind's new location.
		notify_ghosts("\The [X] has <b>transferred its core</b>[A? " to [sanitize(new_core_area.name)]":""]!", source = X, action = NOTIFY_ORBIT)

	var/list/decoy_area_list = list()
	var/area/real_area = get_area(core) //Set our real area
	var/list/buffer_list = list() //Buffer list for randomization
	var/list/details = list() //The actual final list for the announcement

	for(var/area/core_areas in world) //Build the list of areas on the core's Z.
		if(core_areas.z != core.z) //Must be on the same Z
			continue
		decoy_area_list += core_areas //Add to the list of potential decoys

	decoy_area_list -= real_area //Remove the real area from our decoy list.
	buffer_list += sanitize(real_area.name) //Add the real location to our buffer list

	var/decoys
	var/area/decoy_area
	while(decoys < HIVEMIND_REPOSITION_CORE_DECOY_NUMBER) //Populate our list of areas
		decoy_area = pick(decoy_area_list) //Pick random area for our  decoy.
		decoy_area_list -= decoy_area //Remove it from our list of possible decoy options
		buffer_list += sanitize(decoy_area.name)
		++decoys

	var/buffer_list_pick
	while(buffer_list.len > 0) //Now populate our randomized order list for the announcement
		buffer_list_pick = pick(buffer_list) //Get random entry in the list
		buffer_list -= buffer_list_pick //Remove that random entry from the buffer
		if(buffer_list.len > 0) //Add that random entry to the final list of areas
			details += ("[buffer_list_pick], ")
		else
			details += ("[buffer_list_pick].")

	priority_announce("Attention: Anomalous energy readings detected in the following areas: [details.Join(" ")] Further investigation advised.", "Priority Alert", sound = 'sound/AI/commandreport.ogg')


/datum/action/xeno_action/activable/reposition_core/proc/check_build_location(turf/target_turf, mob/living/carbon/xenomorph/hivemind/X)

	if(!X || !target_turf) //Sanity
		return FALSE

	if(target_turf.z != X.core.z)
		to_chat(X, "<span class='xenodanger'>We cannot transfer our core here.</span>")
		return FALSE

	if(target_turf.density) //Check to see if there's room
		to_chat(X, "<span class='xenodanger'>We require adequate room to transfer our core.</span>")
		return FALSE

	var/obj/effect/alien/weeds/W = locate() in range(0, target_turf) //Make sure we actually have weeds at our destination.
	if(!W)
		to_chat(X, "<span class='xenodanger'>There are no weeds for us to transfer our consciousness to!</span>")
		return FALSE

	for(var/obj/structure/O in target_turf.contents)
		if(O.density && !(O.flags_atom = ON_BORDER))
			to_chat(X, "<span class='xenodanger'>An object is occupying this space!</span>")
			return FALSE

	return TRUE



// ***************************************
// *********** Mind Wrack
// ***************************************
/datum/action/xeno_action/activable/mind_wrack
	name = "Mind Wrack"
	action_icon_state = "screech"
	mechanics_text = "Afflicts the target's mind with disorienting and painful psychic energy. Effect is greater the closer the target is to your core, and the more xenos that are within 5 tiles when used. Must have a core or other xeno within 5 tiles to use."
	ability_name = "mind wrack"
	plasma_cost = 100
	keybind_signal = COMSIG_XENOABILITY_MIND_WRACK
	cooldown_timer = 30 SECONDS

/datum/action/xeno_action/activable/mind_wrack/on_cooldown_finish()
	owner.playsound_local(owner.loc, 'sound/voice/alien_drool1.ogg', 50, TRUE)
	to_chat(owner, "<span class='xenonotice'>We regain the strength to assault the minds of our enemies.</span>")
	return ..()

/datum/action/xeno_action/activable/mind_wrack/can_use_ability(atom/target, silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE
	if(QDELETED(target))
		return FALSE

	var/mob/living/carbon/C = target
	var/mob/living/carbon/xenomorph/hivemind/X = owner

	if(!X.hivemind_weed_vibecheck()) //If no weeds are within range, we get yeeted back to Brazil
		return FALSE

	var/distance = get_dist(owner, C)

	if(!iscarbon(target)) //only items and mobs can be flung.
		to_chat(X, "<span class='xenowarning'>Our mind cannot interface with such an entity!</spam>")
		return FALSE

	if(isxeno(C))
		var/mob/living/carbon/xenomorph/alien = C
		if(alien.hivenumber == X.hivenumber)
			to_chat(X, "<span class='xenonotice'>We would not assail the minds of our sisters!</span>")
			return FALSE

	if(distance > HIVEMIND_MIND_WRACK_MAX_RANGE)
		to_chat(X, "<span class='xenowarning'>They are too far for us to reach their minds! The target must be [distance - HIVEMIND_MIND_WRACK_MAX_RANGE] tiles closer!</spam>")

	if(!owner.line_of_sight(target, HIVEMIND_MIND_WRACK_MAX_RANGE))
		if(!silent)
			to_chat(X, "<span class='xenowarning'>We can't focus our psychic energy properly without a clear line of sight!</span>")
		return FALSE

	if(!CHECK_BITFIELD(use_state_flags|override_flags, XACT_IGNORE_DEAD_TARGET) && C.stat == DEAD)
		to_chat(X, "<span class='xenonotice'>Even we cannot touch the minds of the dead...</span>")
		return FALSE


/datum/action/xeno_action/activable/mind_wrack/use_ability(atom/A)
	var/mob/living/carbon/xenomorph/hivemind/X = owner
	var/mob/living/carbon/victim = A

	var/power_level //What does the scouter say about it?
	for(var/mob/living/carbon/xenomorph/ally in range(HIVEMIND_MIND_WRACK_POWER_CHORUS_RANGE, X ) ) //For each friendly xeno nearby, effect is more powerful
		if(istype(ally) && ally.hivenumber == X.hivenumber)
			++power_level //Increment the power level for each Xeno nearby
		if(power_level > HIVEMIND_MIND_WRACK_POWER_MAX_CHORUS)
			break

	for(var/obj/effect/alien/hivemindcore/node_core in range(HIVEMIND_MIND_WRACK_POWER_CHORUS_RANGE, get_turf(X) ) ) //If our core is nearby, the effect is *especially* powerful.
		if(node_core == X.core)
			power_level = max(power_level, power_level + 2)

	if(power_level < 2) //We need at least one core or xeno other than us.
		to_chat(owner, "<span class='xenodanger'>We require our core or a sister nearby to relay our psychic energy!</span>")
		return FALSE

	succeed_activate()

	var/proximity_offset = get_dist(get_turf(victim), get_turf(X.core) ) //Effect is more powerful the closer the target is to the core, and less powerful the further away it is
	proximity_offset = clamp(-100, (HIVEMIND_MIND_WRACK_POWER_DISTANCE - proximity_offset) * 5, 100)

	power_level = clamp(HIVEMIND_MIND_WRACK_POWER_MINIMUM, power_level * HIVEMIND_MIND_WRACK_POWER_MULTIPLIER + proximity_offset, HIVEMIND_MIND_WRACK_POWER_MAXIMUM)

	X.playsound_local(X.loc, 'sound/magic/invoke_general.ogg', 50, TRUE)
	victim.playsound_local(victim.loc, pick('sound/voice/alien_distantroar_3.ogg','sound/voice/alien_queen_command.ogg','sound/voice/alien_queen_command2.ogg','sound/voice/alien_queen_command3.ogg'), 50, TRUE)
	to_chat(X, "<span class='danger'>We scour the mind of this unfortunate creature with [calculate_power(power_level, X)] power.</span>")
	to_chat(victim, "<span class='danger'>Your mind is suddenly overwhelmed by alien thoughts as unworldly screaming fills your ears. Your brain feels as though it's on fire and your world convulses!</span>")
	new /obj/effect/temp_visual/telepathy(get_turf(victim))
	shake_camera(victim, power_level * 0.01 SECONDS, 1)
	victim.ParalyzeNoChain(0.5 SECONDS)
	victim.hallucination = clamp(power_level, victim.hallucination + power_level, 200) //I want the hallucination effect to *eventually* go away; capped at 200 stacks.
	victim.Confused(power_level * 0.025)
	victim.set_drugginess(power_level * 0.025) //visuals
	victim.adjustStaminaLoss(power_level * 0.5)
	victim.adjust_stagger(power_level * 0.05)
	victim.add_slowdown(power_level * 0.05)

	add_cooldown()

	GLOB.round_statistics.hivemind_mind_wrack_uses++ //Increment the statistics
	SSblackbox.record_feedback("tally", "round_statistics", 1, "hivemind_reposition_wrack_uses")


/datum/action/xeno_action/activable/mind_wrack/proc/calculate_power(power_level, mob/living/carbon/xenomorph/hivemind/X)
	if(isnull(X))
		return
	switch(power_level)
		if(0 to HIVEMIND_MIND_WRACK_POWER_MINIMUM)
			return "<b>minimum</b>"
		if(51 to 100)
			return "<b>low</b>"
		if(101 to 200)
			return "<b>middling</b>"
		if(201 to 299)
			return "<b>high</b>"
		if(HIVEMIND_MIND_WRACK_POWER_MAXIMUM to INFINITY)
			return "<b>MAXIMUM</b>"
