/mob/living/carbon/xenomorph/wraith
	caste_base_type = /mob/living/carbon/xenomorph/wraith
	name = "Wraith"
	desc = "A strange tendriled alien. The air around it warps and shimmers like a heat mirage."
	icon = 'icons/Xeno/2x2_Xenos.dmi'
	icon_state = "Wraith Walking"
	health = 150
	maxHealth = 150
	plasma_stored = 150
	pixel_x = -16
	old_x = -16
	tier = XENO_TIER_TWO
	upgrade = XENO_UPGRADE_ZERO
	inherent_verbs = list(
		/mob/living/carbon/xenomorph/proc/vent_crawl,
	)

/obj/flamer_fire/CanAllowThrough(atom/movable/mover, turf/target)
	. = ..()
	if(isxenohivemind(mover))
		return FALSE
	if(isxenowraith(mover) && mover.get_filter("wraith_phase_shift")) //If we're Phase Shifting we cannot pass this; don't ask me why I have to specify this as being non-false; it won't work otherwise
		return FALSE

/obj/effect/particle_effect/smoke/plasmaloss/CanAllowThrough(atom/movable/mover, turf/target)
	. = ..()
	if(isxenowraith(mover) && (mover.get_filter("wraith_phase_shift") != FALSE)) //If we're Phase Shifting we cannot pass this; don't ask me why I have to specify this as being non-false; it won't work otherwise
		return FALSE

/turf/open/space/CanAllowThrough(atom/movable/mover, turf/target)
	. = ..()
	if(isxenowraith(mover) && mover.get_filter("wraith_phase_shift")) //If we're Phase Shifting we cannot pass this; don't ask me why I have to specify this as being non-false; it won't work otherwise
		return FALSE
