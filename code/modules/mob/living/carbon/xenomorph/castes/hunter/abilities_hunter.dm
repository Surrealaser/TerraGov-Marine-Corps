// ***************************************
// *********** Stealth
// ***************************************
/datum/action/xeno_action/stealth
	name = "Toggle Stealth"
	action_icon_state = "stealth_on"
	mechanics_text = "Become harder to see, almost invisible if you stand still, and ready a sneak attack. Uses plasma to move."
	ability_name = "stealth"
	plasma_cost = 10
	keybind_signal = COMSIG_XENOABILITY_TOGGLE_STEALTH
	cooldown_timer = HUNTER_STEALTH_COOLDOWN
	var/last_stealth = null
	var/stealth = FALSE
	var/can_sneak_attack = FALSE
	var/stealth_alpha_multiplier = 1

/datum/action/xeno_action/stealth/give_action(mob/living/L)
	. = ..()
	RegisterSignal(L, COMSIG_XENOMORPH_POUNCE, .proc/sneak_attack_pounce)
	RegisterSignal(L, COMSIG_XENO_LIVING_THROW_HIT, .proc/mob_hit)
	RegisterSignal(L, COMSIG_XENOMORPH_ATTACK_LIVING, .proc/sneak_attack_slash)
	RegisterSignal(L, COMSIG_XENOMORPH_DISARM_HUMAN, .proc/sneak_attack_disarm)
	RegisterSignal(L, COMSIG_XENOMORPH_ZONE_SELECT, .proc/sneak_attack_zone)
	RegisterSignal(L, COMSIG_XENOMORPH_PLASMA_REGEN, .proc/plasma_regen)

	// TODO: attack_alien() overrides are a mess and need a lot of work to make them require parentcalling
	RegisterSignal(L, list(
		COMSIG_XENOMORPH_GRAB,
		COMSIG_XENOMORPH_ATTACK_BARRICADE,
		COMSIG_XENOMORPH_ATTACK_CLOSET,
		COMSIG_XENOMORPH_ATTACK_RAZORWIRE,
		COMSIG_XENOMORPH_ATTACK_BED,
		COMSIG_XENOMORPH_ATTACK_NEST,
		COMSIG_XENOMORPH_ATTACK_TABLE,
		COMSIG_XENOMORPH_ATTACK_RACK,
		COMSIG_XENOMORPH_ATTACK_SENTRY,
		COMSIG_XENOMORPH_ATTACK_M56_POST,
		COMSIG_XENOMORPH_ATTACK_M56,
		COMSIG_XENOMORPH_ATTACK_TANK,
		COMSIG_XENOMORPH_THROW_HIT,
		COMSIG_XENOMORPH_FIRE_BURNING,
		COMSIG_LIVING_ADD_VENTCRAWL), .proc/cancel_stealth)

	RegisterSignal(L, list(SIGNAL_ADDTRAIT(TRAIT_KNOCKEDOUT), SIGNAL_ADDTRAIT(TRAIT_FLOORED)), .proc/cancel_stealth)

	RegisterSignal(src, COMSIG_XENOMORPH_TAKING_DAMAGE, .proc/damage_taken)

/datum/action/xeno_action/stealth/remove_action(mob/living/L)
	UnregisterSignal(L, list(
		COMSIG_XENOMORPH_POUNCE,
		COMSIG_XENO_LIVING_THROW_HIT,
		COMSIG_XENOMORPH_ATTACK_LIVING,
		COMSIG_XENOMORPH_DISARM_HUMAN,
		COMSIG_XENOMORPH_GRAB,
		COMSIG_XENOMORPH_ATTACK_BARRICADE,
		COMSIG_XENOMORPH_ATTACK_CLOSET,
		COMSIG_XENOMORPH_ATTACK_RAZORWIRE,
		COMSIG_XENOMORPH_ATTACK_BED,
		COMSIG_XENOMORPH_ATTACK_NEST,
		COMSIG_XENOMORPH_ATTACK_TABLE,
		COMSIG_XENOMORPH_ATTACK_RACK,
		COMSIG_XENOMORPH_ATTACK_SENTRY,
		COMSIG_XENOMORPH_ATTACK_M56_POST,
		COMSIG_XENOMORPH_ATTACK_M56,
		COMSIG_XENOMORPH_ATTACK_TANK,
		COMSIG_XENOMORPH_THROW_HIT,
		COMSIG_XENOMORPH_FIRE_BURNING,
		COMSIG_LIVING_ADD_VENTCRAWL,
		SIGNAL_ADDTRAIT(TRAIT_KNOCKEDOUT),
		SIGNAL_ADDTRAIT(TRAIT_FLOORED),
		COMSIG_XENOMORPH_ZONE_SELECT,
		COMSIG_XENOMORPH_PLASMA_REGEN))
	return ..()

/datum/action/xeno_action/stealth/on_xeno_upgrade()

	if(owner.alpha > HUNTER_STEALTH_RUN_ALPHA * stealth_alpha_multiplier) //If we actually have stealth translucency, assume we were stealthed pre-upgrade for reset and continue
		return

	stealth = TRUE //So we can properly reset
	cancel_stealth(TRUE, FALSE) //Silent cancel, don't change move intent

	//Now we reset Stealth:
	stealth = TRUE
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, .proc/handle_stealth)
	handle_stealth()


/datum/action/xeno_action/stealth/can_use_action(silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/carbon/xenomorph/stealthy_beno = owner
	if(stealthy_beno.on_fire)
		to_chat(stealthy_beno, "<span class='warning'>We're too busy being on fire to enter Stealth!</span>")
		return FALSE
	return TRUE

/datum/action/xeno_action/stealth/on_cooldown_finish()
	to_chat(owner, "<span class='xenodanger'><b>We're ready to use Stealth again.</b></span>")
	owner.playsound_local(owner, 'sound/effects/xeno_newlarva.ogg', 25, 0, 1)
	return ..()

/datum/action/xeno_action/stealth/action_activate()
	if(stealth)
		cancel_stealth()
		add_cooldown()
		return TRUE

	succeed_activate()
	to_chat(owner, "<span class='xenodanger'>We vanish into the shadows...</span>")
	last_stealth = world.time
	stealth = TRUE
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, .proc/handle_stealth)
	handle_stealth()
	add_cooldown()
	addtimer(CALLBACK(src, .proc/sneak_attack_cooldown), HUNTER_POUNCE_SNEAKATTACK_DELAY) //Short delay before we can sneak attack.

/datum/action/xeno_action/stealth/proc/cancel_stealth(silent = FALSE, change_move_intent = TRUE) //This happens if we take damage, attack, pounce, toggle stealth off, and do other such exciting stealth breaking activities.
	SIGNAL_HANDLER
	if(!stealth)//sanity check/safeguard
		return
	if(!silent)
		to_chat(owner, "<span class='xenodanger'>We emerge from the shadows.</span>")
	if(change_move_intent) //By default we swap to running after sneak attack for quick get-aways
		owner.m_intent = MOVE_INTENT_RUN

	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED) //This should be handled on the ability datum or a component.
	stealth = FALSE
	can_sneak_attack = FALSE
	owner.alpha = 255 //no transparency/translucency

/datum/action/xeno_action/stealth/proc/sneak_attack_cooldown()
	if(!stealth || can_sneak_attack)
		return
	can_sneak_attack = TRUE
	to_chat(owner, "<span class='xenodanger'>We're ready to use Sneak Attack while stealthed.</span>")
	owner.playsound_local(owner, 'sound/effects/xeno_newlarva.ogg', 25, 0, 1)

/datum/action/xeno_action/stealth/proc/handle_stealth()
	SIGNAL_HANDLER
	if(!stealth)
		return

	var/mob/living/carbon/xenomorph/xenoowner = owner
	//Initial stealth
	if(last_stealth > world.time - HUNTER_STEALTH_INITIAL_DELAY) //We don't start out at max invisibility
		owner.alpha = HUNTER_STEALTH_RUN_ALPHA * stealth_alpha_multiplier
		return
	//Stationary stealth
	else if(owner.last_move_intent < world.time - HUNTER_STEALTH_STEALTH_DELAY) //If we're standing still for 4 seconds we become almost completely invisible
		owner.alpha = HUNTER_STEALTH_STILL_ALPHA * stealth_alpha_multiplier
	//Walking stealth
	else if(owner.m_intent == MOVE_INTENT_WALK)
		xenoowner.use_plasma(HUNTER_STEALTH_WALK_PLASMADRAIN)
		owner.alpha = HUNTER_STEALTH_WALK_ALPHA * stealth_alpha_multiplier
	//Running stealth
	else
		xenoowner.use_plasma(HUNTER_STEALTH_RUN_PLASMADRAIN)
		owner.alpha = HUNTER_STEALTH_RUN_ALPHA * stealth_alpha_multiplier
	//If we have 0 plasma after expending stealth's upkeep plasma, end stealth.
	if(!xenoowner.plasma_stored)
		to_chat(xenoowner, "<span class='xenodanger'>We lack sufficient plasma to remain camouflaged.</span>")
		cancel_stealth()

/// Callback listening for a xeno using the pounce ability
/datum/action/xeno_action/stealth/proc/sneak_attack_pounce()
	SIGNAL_HANDLER
	// TODO: find out if this is needed
	if(owner.m_intent == MOVE_INTENT_WALK) //Hunter that is currently using its stealth ability, need to unstealth him
		owner.toggle_move_intent(MOVE_INTENT_RUN)
		if(owner.hud_used?.move_intent)
			owner.hud_used.move_intent.icon_state = "running"
		owner.update_icons()

	cancel_stealth()

	if(!can_sneak_attack)
		return
	to_chat(owner, "<span class='xenodanger'>Our pounce has left us off-balance; we'll need to wait [HUNTER_POUNCE_SNEAKATTACK_DELAY*0.1] seconds before we can Sneak Attack again.</span>")
	can_sneak_attack = FALSE
	addtimer(CALLBACK(src, .proc/sneak_attack_cooldown), HUNTER_POUNCE_SNEAKATTACK_DELAY)

/// Callback for when a mob gets hit as part of a pounce
/datum/action/xeno_action/stealth/proc/mob_hit(datum/source, mob/living/M)
	SIGNAL_HANDLER
	if(M.stat || isxeno(M))
		return
	if(can_sneak_attack)
		M.adjust_stagger(3)
		M.add_slowdown(1)
		to_chat(owner, "<span class='xenodanger'>Pouncing from the shadows, we stagger our victim.</span>")

/datum/action/xeno_action/stealth/proc/sneak_attack_slash(datum/source, mob/living/target, damage, list/damage_mod, list/armor_mod)
	SIGNAL_HANDLER
	if(!stealth || !can_sneak_attack)
		return

	var/staggerslow_stacks = HUNTER_SNEAK_ATTACK_STAGGERSLOW_STACKS
	var/flavour

	if(huntah.m_intent == MOVE_INTENT_RUN && ( huntah.last_move_intent > (world.time - HUNTER_SNEAK_ATTACK_RUN_DELAY) ) ) //We penalize running with a compromised sneak attack, unless they've been stationary; walking is fine.
		flavour = "vicious"
		staggerslow_stacks *= HUNTER_SNEAK_ATTACK_RUNNING_MULTIPLIER //half as much stagger slow if we're running and not stationary
		armor_mod += (1 - (1 - HUNTER_SNEAK_SLASH_ARMOR_PEN) * HUNTER_SNEAK_ATTACK_RUNNING_MULTIPLIER) //We halve the penetration.
	else
		armor_mod += HUNTER_SNEAK_SLASH_ARMOR_PEN
		flavour = "deadly"

	huntah.visible_message("<span class='danger'>\The [huntah] strikes [target] with [flavour] precision!</span>", \
	"<span class='danger'>We strike [target] with [flavour] precision!</span>")
	target.adjust_stagger(staggerslow_stacks)
	target.add_slowdown(staggerslow_stacks)

	cancel_stealth()
	return COMPONENT_BYPASS_SHIELDS

/datum/action/xeno_action/stealth/proc/sneak_attack_disarm(datum/source, mob/living/target, tackle_pain, list/pain_mod)
	SIGNAL_HANDLER
	if(!stealth || !can_sneak_attack)
		return

	var/staggerslow_stacks = HUNTER_SNEAK_ATTACK_STAGGERSLOW_STACKS
	var/paralyze_time = HUNTER_SNEAK_ATTACK_PARALYZE_TIME
	var/flavour

	if(owner.m_intent == MOVE_INTENT_RUN && ( owner.last_move_intent > (world.time - HUNTER_SNEAK_ATTACK_RUN_DELAY) ) )  //We penalize running with a compromised sneak attack, unless they've been stationary; walking is fine.
		pain_mod += (HUNTER_SNEAK_ATTACK_DISARM_MULTIPLIER * HUNTER_SNEAK_ATTACK_RUNNING_MULTIPLIER * tackle_pain)
		flavour = "vicious"
		staggerslow_stacks *= HUNTER_SNEAK_ATTACK_RUNNING_MULTIPLIER //Penalize staggerslow
		paralyze_time *= HUNTER_SNEAK_ATTACK_RUNNING_MULTIPLIER
	else
		pain_mod += (HUNTER_SNEAK_ATTACK_DISARM_MULTIPLIER * tackle_pain)

		flavour = "deadly"

	huntah.visible_message("<span class='danger'>\The [huntah] strikes [target] with [flavour] precision!</span>", \
	"<span class='danger'>We strike [target] with [flavour] precision!</span>")
	target.ParalyzeNoChain(paralyze_time)
	target.adjust_stagger(staggerslow_stacks)
	target.add_slowdown(staggerslow_stacks)

	cancel_stealth()
	return COMPONENT_BYPASS_SHIELDS


/datum/action/xeno_action/stealth/proc/damage_taken(mob/living/carbon/xenomorph/X, damage_taken)
	SIGNAL_HANDLER
	if(damage_taken > 15)
		cancel_stealth()

/datum/action/xeno_action/stealth/proc/plasma_regen(datum/source, list/plasma_mod)
	SIGNAL_HANDLER
	handle_stealth()

	if(stealth && owner.last_move_intent > world.time - 20) //Stealth halves the rate of plasma recovery on weeds, and eliminates it entirely while moving
		plasma_mod += 0.0
	else
		plasma_mod += 0.5

/datum/action/xeno_action/stealth/proc/sneak_attack_zone()
	SIGNAL_HANDLER
	if(!stealth || !can_sneak_attack)
		return
	return COMSIG_ACCURATE_ZONE

// ***************************************
// *********** Pounce/sneak attack
// ***************************************
/datum/action/xeno_action/activable/pounce/hunter
	plasma_cost = 20
	range = 7

// ***************************************
// *********** Haunt
// ***************************************
/datum/action/xeno_action/activable/haunt
	name = "Haunt"
	action_icon_state = "haunt"
	mechanics_text = "Haunts the target, causing hallucinations and minor paranoia."
	ability_name = "haunt"
	plasma_cost = 25
	keybind_signal = COMSIG_XENOABILITY_HAUNT
	cooldown_timer = 30 SECONDS

/datum/action/xeno_action/activable/haunt/can_use_action(silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/carbon/xenomorph/haunter = owner
	if(haunter.on_fire)
		to_chat(haunter, "<span class='warning'>We're too busy being on fire to haunt them!</span>")
		return FALSE
	return TRUE


/datum/action/xeno_action/activable/haunt/use_ability(atom/A)
	var/mob/living/carbon/xenomorph/X = owner
	var/mob/living/carbon/victim = A

	if(!istype(victim))
		return

	if(victim.stat == DEAD)
		return

	if(!can_use_ability(A, TRUE, override_flags = XACT_IGNORE_SELECTED_ABILITY))
		return fail_activate()

	if(get_dist(X, victim) > 5)
		to_chat(X, "<span class='warning'>They are too far for us to reach their minds!</spam>")

	succeed_activate()
	X.playsound_local(X, 'sound/voice/4_xeno_roars.ogg', 30, TRUE)
	to_chat(X, "<span class='notice'>We reach out into mind of the creature, infecting their thoughts...</span>")
	victim.hallucination += 100
	add_cooldown()

// ***************************************
// *********** Sneak Stinger
// ***************************************
/datum/action/xeno_action/activable/sneak_stinger
	name = "Stealth Stinger"
	action_icon_state = "neuro_sting"
	mechanics_text = "Use on an adjacent target while stealthed and your sneak attack is ready, while stationary or off run intent. Injects Acid while on Harm intent and Neurotoxin while on any other intent."
	plasma_cost = 50
	keybind_signal = COMSIG_XENOABILITY_STEALTH_STINGER
	cooldown_timer = 30 SECONDS

/datum/action/xeno_action/activable/sneak_stinger/can_use_ability(atom/A, silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE

	if(QDELETED(A))
		return FALSE

	var/mob/living/carbon/xenomorph/hunter/X = owner
	var/mob/living/carbon/human/C = A

	if(!A?.can_sting())
		to_chat(X, "<span class='xenowarning'>We cannot sting this target!</span>")
		return FALSE

	if(X.on_fire)
		to_chat(X, "<span class='xenowarning'>We're too busy being on fire to sting them!</span>")
		return FALSE

	if(X.m_intent == MOVE_INTENT_RUN && ( X.last_move_intent > (world.time - HUNTER_SNEAK_ATTACK_RUN_DELAY) ) )//We can't sprint up to the target and use this.
		to_chat(X, "<span class='xenowarning'>We must be stalking or stationary to properly sting the target!</span>")
		return FALSE

	if(!X.Adjacent(C))
		to_chat(X, "<span class='xenowarning'>We must be adjacent to the target.</span>")
		return FALSE

	if(isnestedhost(C)) //no bully
		to_chat(X, "<span class='xenowarning'>We refrain from unnecessarily bullying the host.</span>")
		return FALSE

	if(C.stat == DEAD)
		to_chat(X, "<span class='xenowarning'>We care not for the deceased!</span>")
		return FALSE

	var/datum/action/xeno_action/stealth/S = locate() in X.xeno_abilities //Gotta reference the datum for whether we're stealthed/able to sneak attack

	if(!S) //Sanity; should not be possible.
		stack_trace("We somehow don't have the stealth ability as a Hunter.")
		return FALSE

	if(!S.stealth || !S.can_sneak_attack)
		to_chat(X, "<span class='xenowarning'>We must be able to sneak attack the target to properly sting it!</span>")
		return FALSE

	return TRUE


/datum/action/xeno_action/activable/sneak_stinger/on_cooldown_finish()
	var/mob/living/carbon/xenomorph/X = owner
	to_chat(X, "<span class='xenowarning'><b>Our toxin glands refill, allowing us to sting our victims.</b></span>")
	X.playsound_local(X, 'sound/voice/alien_drool1.ogg', 25, 0, 1)
	return ..()


/datum/action/xeno_action/activable/sneak_stinger/use_ability(atom/A)
	var/mob/living/carbon/xenomorph/X = owner
	var/mob/living/carbon/C = A

	X.face_atom(C)

	to_chat(X, "<span class='xenodanger'>We prepare to sting our quarry...</span>")

	if(!do_after(X, HUNTER_STINGER_WINDUP, TRUE, target, BUSY_ICON_HOSTILE)) //Slight wind up
		return fail_activate()

	C.attack_alien(X) //We auto-sneak attack as part of this ability.
	var/datum/reagent/toxin = /datum/reagent/toxin/acid/xeno_acid
	var/transfer_amount = HUNTER_SNEAK_ATTACK_INJECT_AMOUNT
	if(X.a_intent != INTENT_HARM) //Inject neurotoxin instead of acid while on disarm intent
		toxin = /datum/reagent/toxin/xeno_neurotoxin

	C.reagents.add_reagent(toxin, transfer_amount)
	to_chat(C, "<span class='danger'>You feel a tiny prick.</span>") //Fluff
	to_chat(X, "<span class='xenowarning'>Our stinger silently injects our victim!</span>")
	X.playsound_local(C, 'sound/effects/spray3.ogg', 5, 0, 1)
	C.playsound_local(C, 'sound/effects/spray3.ogg', 5, 0, 1)

	succeed_activate()

	GLOB.round_statistics.hunter_stings++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "hunter_stings") //Statistics
	add_cooldown()


// ***************************************
// *********** Hunter's Mark
// ***************************************
/datum/action/xeno_action/activable/hunter_mark
	name = "Hunter's Mark"
	action_icon_state = "hunter_mark"
	mechanics_text = "Psychically mark a creature you have line of sight to, allowing you to sense its direction, distance and location."
	plasma_cost = 75
	keybind_signal = COMSIG_XENOABILITY_HUNTER_MARK
	cooldown_timer = 60 SECONDS

/datum/action/xeno_action/activable/hunter_mark/can_use_ability(atom/A, silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE

	if(QDELETED(A))
		return FALSE

	var/mob/living/carbon/xenomorph/hunter/X = owner
	var/mob/living/C = A

	if(!isliving(C))
		to_chat(X, "<span class='xenowarning'>We cannot psychically mark this target!</span>")
		return FALSE

	if(C == X)
		to_chat(X, "<span class='xenowarning'>Why would we target ourselves?</span>")
		return FALSE

	if(X.on_fire)
		to_chat(X, "<span class='xenowarning'>We're too busy being on fire to mark them!</span>")
		return FALSE

	if(!X.line_of_sight(C)) //Need line of sight.
		to_chat(X, "<span class='xenowarning'>We require line of sight to mark them!</span>")
		return FALSE

	return TRUE


/datum/action/xeno_action/activable/hunter_mark/on_cooldown_finish()
	var/mob/living/carbon/xenomorph/X = owner
	to_chat(X, "<span class='xenowarning'><b>We are able to impose our psychic mark again.</b></span>")
	X.playsound_local(X, 'sound/effects/xeno_newlarva.ogg', 25, 0, 1)
	return ..()


/datum/action/xeno_action/activable/hunter_mark/use_ability(atom/A)
	var/mob/living/carbon/xenomorph/X = owner
	var/mob/living/M = A

	if(!isliving(M)) //Sanity
		to_chat(X, "<span class='xenodanger'>We cannot mark this target!</span>")
		fail_activate()

	X.face_atom(M) //Face towards the target so we don't look silly

	to_chat(X, "<span class='xenodanger'>We prepare to psychically mark [M.name] as our quarry.</span>")

	if(!do_after(X, HUNTER_MARK_WINDUP, TRUE, target, BUSY_ICON_HOSTILE)) //Slight wind up
		return fail_activate()

	if(!X.line_of_sight(M)) //Need line of sight.
		to_chat(X, "<span class='xenowarning'>We lost line of sight to the target!</span>")
		return fail_activate()

	X.hunter_mark_target = M //Set our target
	RegisterSignal(X.hunter_mark_target, COMSIG_PARENT_PREQDELETED, .proc/unset_target) //For var clean up

	to_chat(X, "<span class='xenodanger'>We psychically mark [M.name] as our quarry.</span>")
	X.playsound_local(X, 'sound/effects/ghost.ogg', 25, 0, 1)

	succeed_activate()

	GLOB.round_statistics.hunter_marks++
	SSblackbox.record_feedback("tally", "round_statistics", 1, "hunter_marks") //Statistics
	add_cooldown()

/datum/action/xeno_action/activable/hunter_mark/proc/unset_target()
	var/mob/living/carbon/xenomorph/X = owner
	UnregisterSignal(X.hunter_mark_target, COMSIG_PARENT_PREQDELETED)
	X.hunter_mark_target = null

// ***************************************
// *********** Psychic Trace
// ***************************************
/datum/action/xeno_action/psychic_trace
	name = "Psychic Trace"
	action_icon_state = "toggle_queen_zoom"
	mechanics_text = "Psychically ping the creature you marked, letting you know its direction, distance and location, and general condition."
	plasma_cost = 1 //Token amount
	keybind_signal = COMSIG_XENOABILITY_PSYCHIC_TRACE
	cooldown_timer = HUNTER_PSYCHIC_TRACE_COOLDOWN

/datum/action/xeno_action/psychic_trace/action_activate()

	var/mob/living/carbon/xenomorph/hunter/X = owner
	var/mob/living/M = X.hunter_mark_target

	if(X.on_fire)
		to_chat(X, "<span class='xenowarning'>We're too busy being on fire to trace!</span>")
		return fail_activate()

	if(!M)
		to_chat(X, "<span class='xenowarning'>We have no target we can trace!</span>")
		return fail_activate()

	if(M.z != X.z)
		to_chat(X, "<span class='xenowarning'>Our target is too far away, and is beyond our senses!</span>")
		return fail_activate()

	var/name = M.name
	var/area = "[get_area(M)] (X: [M.x], Y: [M.y])"
	var/distance = get_dist(X, M)
	var/condition = calculate_mark_health()

	to_chat(X, "<span class='xenodanger'>We sense our quarry <b>[name]</b> is currently located in <b>[area]</b> and is <b>[distance]</b> tiles away. It is <b>[condition]</b> and <b>[M.status_flags & XENO_HOST ? "impregnated" : "barren"]</b>.</span>")
	X.playsound_local(X, 'sound/effects/ghost2.ogg', 10, 0, 1)


	var/obj/screen/hunter_tracker/T = new /obj/screen/hunter_tracker //Prepare the tracker object and set its parameters
	T.hunter = X
	T.target = M
	T.add_hud(X)
	T.color = X.hive.color
	T.process() //Ping immediately after parameters have been set

	add_cooldown()

	return succeed_activate()

/datum/action/xeno_action/psychic_trace/proc/calculate_mark_health() //Where we calculate the approximate health of our trace target
	var/mob/living/carbon/xenomorph/X = owner
	var/mob/living/target = X.hunter_mark_target

	if(!isliving(target)) //Sanity
		return "indeterminant"

	if(target.stat == DEAD)
		return "deceased"

	var/percentage = round(target.health * 100 / target.maxHealth)
	switch(percentage)
		if(100 to INFINITY)
			return "in perfect health"
		if(76 to 99)
			return "slightly injured"
		if(51 to 75)
			return "moderately injured"
		if(26 to 50)
			return "badly injured"
		if(1 to 25)
			return "severely injured"
		if(-51 to 0)
			return "critically injured"
		if(-99 to -50)
			return "on the verge of death"
		else
			return "deceased"
