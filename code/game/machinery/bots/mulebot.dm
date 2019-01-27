//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31

// Mulebot - carries crates around for Quartermaster
// Navigates via floor navbeacons
// Remote Controlled from QM's PDA


/obj/machinery/bot/mulebot
	name = "Mulebot"
	desc = "A Multiple Utility Load Effector bot."
	icon_state = "mulebot0"
	density = 1
	anchored = 1
	animate_movement=1
	health = 150 //yeah, it's tougher than ed209 because it is a big metal box with wheels --rastaf0
	maxhealth = 150
	fire_dam_coeff = 0.7
	brute_dam_coeff = 0.5
	var/atom/movable/load = null		// the loaded crate (usually)
	var/beacon_freq = 1400
	var/control_freq = AI_FREQ

	suffix = ""

	var/turf/target				// this is turf to navigate to (location of beacon)
	var/loaddir = 0				// this the direction to unload onto/load from
	var/new_destination = ""	// pending new destination (waiting for beacon response)
	var/destination = ""		// destination description
	var/home_destination = "" 	// tag of home beacon
	req_access = list(ACCESS_CIVILIAN_ENGINEERING) // added robotics access so assembly line drop-off works properly -veyveyr //I don't think so, Tim. You need to add it to the MULE's hidden robot ID card. -NEO
	var/path[] = new()

	var/mode = 0		//0 = idle/ready
						//1 = loading/unloading
						//2 = moving to deliver
						//3 = returning to home
						//4 = blocked
						//5 = computing navigation
						//6 = waiting for nav computation
						//7 = no destination beacon found (or no route)

	var/blockcount	= 0		//number of times retried a blocked path
	var/reached_target = 1 	//true if already reached the target

	var/refresh = 1		// true to refresh dialogue
	var/auto_return = 1	// true if auto return to home beacon after unload
	var/auto_pickup = 1 // true if auto-pickup at beacon

	var/obj/item/cell/cell
						// the installed power cell

	// constants for internal wiring bitflags
	var/const/wire_power1 = 1			// power connections
	var/const/wire_power2 = 2
	var/const/wire_mobavoid = 4		// mob avoidance
	var/const/wire_loadcheck = 8		// load checking (non-crate)
	var/const/wire_motor1 = 16		// motor wires
	var/const/wire_motor2 = 32		//
	var/const/wire_remote_rx = 64		// remote recv functions
	var/const/wire_remote_tx = 128	// remote trans status
	var/const/wire_beacon_rx = 256	// beacon ping recv
	var/const/wire_beacon_tx = 512	// beacon ping trans

	var/wires = 1023		// all flags on

	var/list/wire_text	// list of wire colours
	var/list/wire_order	// order of wire indices


	var/bloodiness = 0		// count of bloodiness

/obj/machinery/bot/mulebot/Initialize()
	. = ..()
	botcard = new(src)
	var/datum/job/J = RoleAuthority ? RoleAuthority.roles_by_path[/datum/job/logistics/tech/cargo] : new /datum/job/logistics/tech/cargo
	botcard.access = J.get_access()
//	botcard.access += access_robotics //Why --Ikki
	cell = new(src)
	cell.charge = 2000
	cell.maxcharge = 2000
	setup_wires()

	if(radio_controller)
		radio_controller.add_object(src, control_freq, filter = RADIO_MULEBOT)
		radio_controller.add_object(src, beacon_freq, filter = RADIO_NAVBEACONS)

	var/count = 0
	for(var/obj/machinery/bot/mulebot/other in GLOB.machines)
		count++
	if(!suffix)
		suffix = "#[count]"
	name = "Mulebot ([suffix])"

	verbs -= /atom/movable/verb/pull


// set up the wire colours in random order
// and the random wire display order
// needs 10 wire colours
/obj/machinery/bot/mulebot/proc/setup_wires()
	var/list/colours = list("Red", "Green", "Blue", "Magenta", "Cyan", "Yellow", "Black", "White", "Orange", "Grey")
	var/list/orders = list("0","1","2","3","4","5","6","7","8","9")
	wire_text = list()
	wire_order = list()
	while(colours.len > 0)
		var/colour = colours[ rand(1,colours.len) ]
		wire_text += colour
		colours -= colour

		var/order = orders[ rand(1,orders.len) ]
		wire_order += text2num(order)
		orders -= order



// attack by item
// emag : lock/unlock,
// screwdriver: open/close hatch
// cell: insert it
// other: chance to knock rider off bot
/obj/machinery/bot/mulebot/attackby(var/obj/item/I, var/mob/user)
	if(istype(I,/obj/item/card/emag))
		locked = !locked
		to_chat(user, "<span class='notice'>You [locked ? "lock" : "unlock"] the mulebot's controls!</span>")
		flick("mulebot-emagged", src)
		playsound(src.loc, 'sound/effects/sparks1.ogg', 25, 0)
	else if(istype(I,/obj/item/cell) && open && !cell)
		var/obj/item/cell/C = I
		if(user.transferItemToLoc(C, src))
			cell = C
			updateDialog()
	else if(istype(I,/obj/item/tool/screwdriver))
		if(locked)
			to_chat(user, "<span class='notice'>The maintenance hatch cannot be opened or closed while the controls are locked.</span>")
			return

		open = !open
		if(open)
			src.visible_message("[user] opens the maintenance hatch of [src]", "<span class='notice'> You open [src]'s maintenance hatch.</span>")
			on = 0
			icon_state="mulebot-hatch"
		else
			src.visible_message("[user] closes the maintenance hatch of [src]", "<span class='notice'> You close [src]'s maintenance hatch.</span>")
			icon_state = "mulebot0"

		updateDialog()
	else if (istype(I, /obj/item/tool/wrench))
		if (src.health < maxhealth)
			src.health = min(maxhealth, src.health+25)
			user.visible_message(
				"<span class='warning'> [user] repairs [src]!</span>",
				"<span class='notice'> You repair [src]!</span>"
			)
		else
			to_chat(user, "<span class='notice'>[src] does not need a repair!</span>")
	else if(load && ismob(load))  // chance to knock off rider
		if(prob(1+I.force * 2))
			unload(0)
			user.visible_message("<span class='warning'> [user] knocks [load] off [src] with \the [I]!</span>", "<span class='warning'> You knock [load] off [src] with \the [I]!</span>")
		else
			to_chat(user, "You hit [src] with \the [I] but to no effect.")
	else
		..()
	return


/obj/machinery/bot/mulebot/ex_act(var/severity)
	unload(0)
	switch(severity)
		if(2)
			wires &= ~(1 << rand(0,9))
			wires &= ~(1 << rand(0,9))
			wires &= ~(1 << rand(0,9))
		if(3)
			wires &= ~(1 << rand(0,9))
	..()
	return

/obj/machinery/bot/mulebot/bullet_act()
	if(prob(50) && !isnull(load))
		unload(0)
	if(prob(25))
		src.visible_message("<span class='warning'> Something shorts out inside [src]!</span>")
		var/index = 1<< (rand(0,9))
		if(wires & index)
			wires &= ~index
		else
			wires |= index
	..()
	return 1


/obj/machinery/bot/mulebot/attack_ai(var/mob/user)
	user.set_interaction(src)
	interact(user, 1)

/obj/machinery/bot/mulebot/attack_hand(var/mob/user)
	. = ..()
	if (.)
		return
	user.set_interaction(src)
	interact(user, 0)

/obj/machinery/bot/mulebot/interact(var/mob/user, var/ai=0)
	var/dat
	dat += "<TT><B>Multiple Utility Load Effector Mk. III</B></TT><BR><BR>"
	dat += "ID: [suffix]<BR>"
	dat += "Power: [on ? "On" : "Off"]<BR>"

	if(!open)

		dat += "Status: "
		switch(mode)
			if(0)
				dat += "Ready"
			if(1)
				dat += "Loading/Unloading"
			if(2)
				dat += "Navigating to Delivery Location"
			if(3)
				dat += "Navigating to Home"
			if(4)
				dat += "Waiting for clear path"
			if(5,6)
				dat += "Calculating navigation path"
			if(7)
				dat += "Unable to locate destination"


		dat += "<BR>Current Load: [load ? load.name : "<i>none</i>"]<BR>"
		dat += "Destination: [!destination ? "<i>none</i>" : destination]<BR>"
		dat += "Power level: [cell ? cell.percent() : 0]%<BR>"

		if(locked && !ai)
			dat += "<HR>Controls are locked <A href='byond://?src=\ref[src];op=unlock'><I>(unlock)</I></A>"
		else
			dat += "<HR>Controls are unlocked <A href='byond://?src=\ref[src];op=lock'><I>(lock)</I></A><BR><BR>"

			dat += "<A href='byond://?src=\ref[src];op=power'>Toggle Power</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=stop'>Stop</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=go'>Proceed</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=home'>Return to Home</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=destination'>Set Destination</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=setid'>Set Bot ID</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=sethome'>Set Home</A><BR>"
			dat += "<A href='byond://?src=\ref[src];op=autoret'>Toggle Auto Return Home</A> ([auto_return ? "On":"Off"])<BR>"
			dat += "<A href='byond://?src=\ref[src];op=autopick'>Toggle Auto Pickup Crate</A> ([auto_pickup ? "On":"Off"])<BR>"

			if(load)
				dat += "<A href='byond://?src=\ref[src];op=unload'>Unload Now</A><BR>"
			dat += "<HR>The maintenance hatch is closed.<BR>"

	else
		if(!ai)
			dat += "The maintenance hatch is open.<BR><BR>"
			dat += "Power cell: "
			if(cell)
				dat += "<A href='byond://?src=\ref[src];op=cellremove'>Installed</A><BR>"
			else
				dat += "<A href='byond://?src=\ref[src];op=cellinsert'>Removed</A><BR>"

			dat += wires()
		else
			dat += "The bot is in maintenance mode and cannot be controlled.<BR>"

	user << browse("<HEAD><TITLE>Mulebot [suffix ? "([suffix])" : ""]</TITLE></HEAD>[dat]", "window=mulebot;size=350x500")
	onclose(user, "mulebot")
	return

// returns the wire panel text
/obj/machinery/bot/mulebot/proc/wires()
	var/t = ""
	for(var/i = 0 to 9)
		var/index = 1<<wire_order[i+1]
		t += "[wire_text[i+1]] wire: "
		if(index & wires)
			t += "<A href='byond://?src=\ref[src];op=wirecut;wire=[index]'>(cut)</A> <A href='byond://?src=\ref[src];op=wirepulse;wire=[index]'>(pulse)</A><BR>"
		else
			t += "<A href='byond://?src=\ref[src];op=wiremend;wire=[index]'>(mend)</A><BR>"

	return t




/obj/machinery/bot/mulebot/Topic(href, href_list)
	if(..())
		return
	if (usr.stat)
		return
	if ((in_range(src, usr) && istype(src.loc, /turf)) || (istype(usr, /mob/living/silicon)))
		usr.set_interaction(src)

		switch(href_list["op"])
			if("lock", "unlock")
				if(src.allowed(usr))
					locked = !locked
					updateDialog()
				else
					to_chat(usr, "<span class='warning'>Access denied.</span>")
					return
			if("power")
				if (src.on)
					turn_off()
				else if (cell && !open)
					if (!turn_on())
						to_chat(usr, "<span class='warning'>You can't switch on [src].</span>")
						return
				else
					return
				visible_message("[usr] switches [on ? "on" : "off"] [src].")
				updateDialog()


			if("cellremove")
				if(open && cell && !usr.get_active_held_item())
					cell.updateicon()
					usr.put_in_active_hand(cell)
					cell.add_fingerprint(usr)
					cell = null

					usr.visible_message("<span class='notice'> [usr] removes the power cell from [src].</span>", "<span class='notice'> You remove the power cell from [src].</span>")
					updateDialog()

			if("cellinsert")
				if(open && !cell)
					var/obj/item/cell/C = usr.get_active_held_item()
					if(istype(C))
						if(usr.drop_held_item())
							cell = C
							C.forceMove(src)
							C.add_fingerprint(usr)

							usr.visible_message("<span class='notice'> [usr] inserts a power cell into [src].</span>", "<span class='notice'> You insert the power cell into [src].</span>")
							updateDialog()


			if("stop")
				if(mode >=2)
					mode = 0
					updateDialog()

			if("go")
				if(mode == 0)
					start()
					updateDialog()

			if("home")
				if(mode == 0 || mode == 2)
					start_home()
					updateDialog()

			if("destination")
				refresh=0
				var/new_dest = input("Enter new destination tag", "Mulebot [suffix ? "([suffix])" : ""]", destination) as text|null
				refresh=1
				if(new_dest)
					set_destination(new_dest)


			if("setid")
				refresh=0
				var/new_id = stripped_input(usr, "Enter new bot ID", "Mulebot [suffix ? "([suffix])" : ""]", suffix)
				refresh=1
				if(new_id)
					suffix = new_id
					name = "Mulebot ([suffix])"
					updateDialog()

			if("sethome")
				refresh=0
				var/new_home = stripped_input(usr, "Enter new home tag", "Mulebot [suffix ? "([suffix])" : ""]", home_destination)
				refresh=1
				if(new_home)
					home_destination = new_home
					updateDialog()

			if("unload")
				if(load && mode !=1)
					if(loc == target)
						unload(loaddir)
					else
						unload(0)

			if("autoret")
				auto_return = !auto_return

			if("autopick")
				auto_pickup = !auto_pickup

			if("close")
				usr.unset_interaction()
				usr << browse(null,"window=mulebot")


			if("wirecut")
				if(istype(usr.get_active_held_item(), /obj/item/tool/wirecutters))
					var/wirebit = text2num(href_list["wire"])
					wires &= ~wirebit
				else
					to_chat(usr, "<span class='notice'>You need wirecutters!</span>")
			if("wiremend")
				if(istype(usr.get_active_held_item(), /obj/item/tool/wirecutters))
					var/wirebit = text2num(href_list["wire"])
					wires |= wirebit
				else
					to_chat(usr, "<span class='notice'>You need wirecutters!</span>")

			if("wirepulse")
				if(istype(usr.get_active_held_item(), /obj/item/device/multitool))
					switch(href_list["wire"])
						if("1","2")
							to_chat(usr, "<span class='notice'>\icon[src] The charge light flickers.</span>")
						if("4")
							to_chat(usr, "<span class='notice'>\icon[src] The external warning lights flash briefly.</span>")
						if("8")
							to_chat(usr, "<span class='notice'>\icon[src] The load platform clunks.</span>")
						if("16", "32")
							to_chat(usr, "<span class='notice'>\icon[src] The drive motor whines briefly.</span>")
						else
							to_chat(usr, "<span class='notice'>\icon[src] You hear a radio crackle.</span>")
				else
					to_chat(usr, "<span class='notice'>You need a multitool!</span>")



		updateDialog()
		//src.updateUsrDialog()
	else
		usr << browse(null, "window=mulebot")
		usr.unset_interaction()
	return



// returns true if the bot has power
/obj/machinery/bot/mulebot/proc/has_power()
	return !open && cell && cell.charge>0 && (wires & wire_power1) && (wires & wire_power2)

// mousedrop a crate to load the bot
// can load anything if emagged

/obj/machinery/bot/mulebot/MouseDrop_T(var/atom/movable/C, mob/user)

	if(user.stat)
		return

	if (!on || !istype(C)|| C.anchored || get_dist(user, src) > 1 || get_dist(src,C) > 1 )
		return

	if(load)
		return

	load(C)


// called to load a crate
/obj/machinery/bot/mulebot/proc/load(var/atom/movable/C)
	if((wires & wire_loadcheck) && !istype(C,/obj/structure/closet/crate))
		src.visible_message("[src] makes a sighing buzz.", "You hear an electronic buzzing sound.")
		playsound(src.loc, 'sound/machines/buzz-sigh.ogg', 25, 0)
		return		// if not emagged, only allow crates to be loaded

	//I'm sure someone will come along and ask why this is here... well people were dragging screen items onto the mule, and that was not cool.
	//So this is a simple fix that only allows a selection of item types to be considered. Further narrowing-down is below.
	if(!istype(C,/obj/item) && !istype(C,/obj/machinery) && !istype(C,/obj/structure) && !ismob(C))
		return
	if(!isturf(C.loc)) //To prevent the loading from stuff from someone's inventory, which wouldn't get handled properly.
		return

	if(get_dist(C, src) > 1 || load || !on)
		return
	for(var/obj/structure/plasticflaps/P in src.loc)//Takes flaps into account
		if(!CanPass(C,P))
			return
	mode = 1

	// if a create, close before loading
	var/obj/structure/closet/crate/crate = C
	if(istype(crate))
		crate.close()

	C.loc = src.loc
	sleep(2)
	if(C.loc != src.loc) //To prevent you from going onto more thano ne bot.
		return
	C.loc = src
	load = C

	C.pixel_y += 9
	if(C.layer < layer)
		C.layer = layer + 0.1
	overlays += C

	if(ismob(C))
		var/mob/M = C
		if(M.client)
			M.client.perspective = EYE_PERSPECTIVE
			M.client.eye = src

	mode = 0
	send_status()

// called to unload the bot
// argument is optional direction to unload
// if zero, unload at bot's location
/obj/machinery/bot/mulebot/proc/unload(var/dirn = 0)
	if(!load)
		return

	mode = 1
	overlays.Cut()

	load.loc = src.loc
	load.pixel_y -= 9
	load.layer = initial(load.layer)
	if(ismob(load))
		var/mob/M = load
		if(M.client)
			M.client.perspective = MOB_PERSPECTIVE
			M.client.eye = src


	if(dirn)
		var/turf/T = src.loc
		T = get_step(T,dirn)
		if(CanPass(load,T))//Can't get off onto anything that wouldn't let you pass normally
			step(load, dirn)
		else
			load.loc = src.loc//Drops you right there, so you shouldn't be able to get yourself stuck

	load = null

	// in case non-load items end up in contents, dump every else too
	// this seems to happen sometimes due to race conditions
	// with items dropping as mobs are loaded

	for(var/atom/movable/AM in src)
		if(AM == cell || AM == botcard) continue

		AM.loc = src.loc
		AM.layer = initial(AM.layer)
		AM.pixel_y = initial(AM.pixel_y)
		if(ismob(AM))
			var/mob/M = AM
			if(M.client)
				M.client.perspective = MOB_PERSPECTIVE
				M.client.eye = src
	mode = 0


/obj/machinery/bot/mulebot/process()
	if(!has_power())
		on = 0
		return
	if(on)
		var/speed = ((wires & wire_motor1) ? 1:0) + ((wires & wire_motor2) ? 2:0)
		//to_chat(world, "speed: [speed]")
		switch(speed)
			if(0)
				// do nothing
			if(1)
				process_bot()
				spawn(2)
					process_bot()
					sleep(2)
					process_bot()
					sleep(2)
					process_bot()
					sleep(2)
					process_bot()
			if(2)
				process_bot()
				spawn(4)
					process_bot()
			if(3)
				process_bot()

	if(refresh) updateDialog()

/obj/machinery/bot/mulebot/proc/process_bot()
	//if(mode) to_chat(world, "Mode: [mode]")
	switch(mode)
		if(0)		// idle
			icon_state = "mulebot0"
			return
		if(1)		// loading/unloading
			return
		if(2,3,4)		// navigating to deliver,home, or blocked

			if(loc == target)		// reached target
				at_target()
				return

			else if(path.len > 0 && target)		// valid path

				var/turf/next = path[1]
				reached_target = 0
				if(next == loc)
					path -= next
					return


				if(istype( next, /turf))
					//to_chat(world, "at ([x],[y]) moving to ([next.x],[next.y])")


					if(bloodiness)
						var/obj/effect/decal/cleanable/blood/tracks/B = new(loc)
						var/newdir = get_dir(next, loc)
						if(newdir == dir)
							B.dir = newdir
						else
							newdir = newdir|dir
							if(newdir == 3)
								newdir = 1
							else if(newdir == 12)
								newdir = 4
							B.dir = newdir
						bloodiness--



					var/moved = step_towards(src, next)	// attempt to move
					if(cell) cell.use(1)
					if(moved)	// successful move
						//to_chat(world, "Successful move.")
						blockcount = 0
						path -= loc


						if(mode==4)
							spawn(1)
								send_status()

						if(destination == home_destination)
							mode = 3
						else
							mode = 2

					else		// failed to move

						//to_chat(world, "Unable to move.")



						blockcount++
						mode = 4
						if(blockcount == 3)
							src.visible_message("[src] makes an annoyed buzzing sound", "You hear an electronic buzzing sound.")
							playsound(src.loc, 'sound/machines/buzz-two.ogg', 25, 0)

						if(blockcount > 5)	// attempt 5 times before recomputing
							// find new path excluding blocked turf
							src.visible_message("[src] makes a sighing buzz.", "You hear an electronic buzzing sound.")
							playsound(src.loc, 'sound/machines/buzz-sigh.ogg', 25, 0)

							spawn(2)
								calc_path(next)
								if(path.len > 0)
									src.visible_message("[src] makes a delighted ping!", "You hear a ping.")
									playsound(src.loc, 'sound/machines/ping.ogg', 25, 0)
								mode = 4
							mode =6
							return
						return
				else
					src.visible_message("[src] makes an annoyed buzzing sound", "You hear an electronic buzzing sound.")
					playsound(src.loc, 'sound/machines/buzz-two.ogg', 25, 0)
					//to_chat(world, "Bad turf.")
					mode = 5
					return
			else
				//to_chat(world, "No path.")
				mode = 5
				return

		if(5)		// calculate new path
			//to_chat(world, "Calc new path.")
			mode = 6
			spawn(0)

				calc_path()

				if(path.len > 0)
					blockcount = 0
					mode = 4
					src.visible_message("[src] makes a delighted ping!", "You hear a ping.")
					playsound(src.loc, 'sound/machines/ping.ogg', 25, 0)

				else
					src.visible_message("[src] makes a sighing buzz.", "You hear an electronic buzzing sound.")
					playsound(src.loc, 'sound/machines/buzz-sigh.ogg', 25, 0)

					mode = 7
		//if(6)
			//to_chat(world, "Pending path calc.")
		//if(7)
			//to_chat(world, "No dest / no route.")
	return


// calculates a path to the current destination
// given an optional turf to avoid
/obj/machinery/bot/mulebot/proc/calc_path(var/turf/avoid = null)
	src.path = AStar(src.loc, src.target, /turf/proc/CardinalTurfsWithAccess, /turf/proc/Distance, 0, 250, id=botcard, exclude=avoid)
	if(!src.path)
		src.path = list()


// sets the current destination
// signals all beacons matching the delivery code
// beacons will return a signal giving their locations
/obj/machinery/bot/mulebot/proc/set_destination(var/new_dest)
	spawn(0)
		new_destination = new_dest
		post_signal(beacon_freq, "findbeacon", "delivery")
		updateDialog()

// starts bot moving to current destination
/obj/machinery/bot/mulebot/proc/start()
	if(destination == home_destination)
		mode = 3
	else
		mode = 2
	icon_state = "mulebot[(wires & wire_mobavoid) == wire_mobavoid]"

// starts bot moving to home
// sends a beacon query to find
/obj/machinery/bot/mulebot/proc/start_home()
	spawn(0)
		set_destination(home_destination)
		mode = 4
	icon_state = "mulebot[(wires & wire_mobavoid) == wire_mobavoid]"

// called when bot reaches current target
/obj/machinery/bot/mulebot/proc/at_target()
	if(!reached_target)
		src.visible_message("[src] makes a chiming sound!", "You hear a chime.")
		playsound(src.loc, 'sound/machines/chime.ogg', 25, 0)
		reached_target = 1

		if(load)		// if loaded, unload at target
			unload(loaddir)
		else
			// not loaded
			if(auto_pickup)		// find a crate
				var/atom/movable/AM
				if(!(wires & wire_loadcheck))		// if emagged, load first unanchored thing we find
					for(var/atom/movable/A in get_step(loc, loaddir))
						if(!A.anchored)
							AM = A
							break
				else			// otherwise, look for crates only
					AM = locate(/obj/structure/closet/crate) in get_step(loc,loaddir)
				if(AM)
					load(AM)
		// whatever happened, check to see if we return home

		if(auto_return && destination != home_destination)
			// auto return set and not at home already
			start_home()
			mode = 4
		else
			mode = 0	// otherwise go idle

	send_status()	// report status to anyone listening

	return

// called when bot bumps into anything
/obj/machinery/bot/mulebot/Bump(var/atom/obs)
	if(!(wires & wire_mobavoid))		//usually just bumps, but if avoidance disabled knock over mobs
		var/mob/M = obs
		if(ismob(M))
			if(istype(M,/mob/living/silicon/robot))
				src.visible_message("<span class='warning'> [src] bumps into [M]!</span>")
			else
				src.visible_message("<span class='warning'> [src] knocks over [M]!</span>")
				M.stop_pulling()
				M.Stun(8)
				M.KnockDown(5)
				M.lying = 1
	..()

/obj/machinery/bot/mulebot/alter_health()
	return get_turf(src)


// called from mob/living/carbon/human/Crossed()
// when mulebot is in the same loc
/obj/machinery/bot/mulebot/proc/RunOver(var/mob/living/carbon/human/H)
	src.visible_message("<span class='warning'> [src] drives over [H]!</span>")
	playsound(src.loc, 'sound/effects/splat.ogg', 25, 1)

	var/damage = rand(5,15)
	H.apply_damage(2*damage, BRUTE, "head")
	H.apply_damage(2*damage, BRUTE, "chest")
	H.apply_damage(0.5*damage, BRUTE, "l_leg")
	H.apply_damage(0.5*damage, BRUTE, "r_leg")
	H.apply_damage(0.5*damage, BRUTE, "l_arm")
	H.apply_damage(0.5*damage, BRUTE, "r_arm")

	H.add_splatter_floor(loc, 1)
	bloodiness += 4

// player on mulebot attempted to move
/obj/machinery/bot/mulebot/relaymove(mob/user)
	if(user.is_mob_incapacitated(TRUE)) return
	if(load == user)
		unload(0)


// receive a radio signal
// used for control and beacon reception

/obj/machinery/bot/mulebot/receive_signal(datum/signal/signal)

	if(!on)
		return

	/*
	to_chat(world, "rec signal: [signal.source]")
	for(var/x in signal.data)
		to_chat(world, "* [x] = [signal.data[x]]")
	*/
	var/recv = signal.data["command"]
	// process all-bot input
	if(recv=="bot_status" && (wires & wire_remote_rx))
		send_status()


	recv = signal.data["command [suffix]"]
	if(wires & wire_remote_rx)
		// process control input
		switch(recv)
			if("stop")
				mode = 0
				return

			if("go")
				start()
				return

			if("target")
				set_destination(signal.data["destination"] )
				return

			if("unload")
				if(loc == target)
					unload(loaddir)
				else
					unload(0)
				return

			if("home")
				start_home()
				return

			if("bot_status")
				send_status()
				return

			if("autoret")
				auto_return = text2num(signal.data["value"])
				return

			if("autopick")
				auto_pickup = text2num(signal.data["value"])
				return

	// receive response from beacon
	recv = signal.data["beacon"]
	if(wires & wire_beacon_rx)
		if(recv == new_destination)	// if the recvd beacon location matches the set destination
									// the we will navigate there
			destination = new_destination
			target = signal.source.loc
			var/direction = signal.data["dir"]	// this will be the load/unload dir
			if(direction)
				loaddir = text2num(direction)
			else
				loaddir = 0
			icon_state = "mulebot[(wires & wire_mobavoid) == wire_mobavoid]"
			calc_path()
			updateDialog()

// send a radio signal with a single data key/value pair
/obj/machinery/bot/mulebot/proc/post_signal(var/freq, var/key, var/value)
	post_signal_multiple(freq, list("[key]" = value) )

// send a radio signal with multiple data key/values
/obj/machinery/bot/mulebot/proc/post_signal_multiple(var/freq, var/list/keyval)

	if(freq == beacon_freq && !(wires & wire_beacon_tx))
		return
	if(freq == control_freq && !(wires & wire_remote_tx))
		return

	var/datum/radio_frequency/frequency = radio_controller.return_frequency(freq)

	if(!frequency) return



	var/datum/signal/signal = new()
	signal.source = src
	signal.transmission_method = 1
	//for(var/key in keyval)
	//	signal.data[key] = keyval[key]
	signal.data = keyval
		//to_chat(world, "sent [key],[keyval[key]] on [freq]")
	if (signal.data["findbeacon"])
		frequency.post_signal(src, signal, filter = RADIO_NAVBEACONS)
	else if (signal.data["type"] == "mulebot")
		frequency.post_signal(src, signal, filter = RADIO_MULEBOT)
	else
		frequency.post_signal(src, signal)

// signals bot status etc. to controller
/obj/machinery/bot/mulebot/proc/send_status()
	var/list/kv = list(
		"type" = "mulebot",
		"name" = suffix,
		"loca" = (loc ? loc.loc : "Unknown"),	// somehow loc can be null and cause a runtime - Quarxink
		"mode" = mode,
		"powr" = (cell ? cell.percent() : 0),
		"dest" = destination,
		"home" = home_destination,
		"load" = load,
		"retn" = auto_return,
		"pick" = auto_pickup,
	)
	post_signal_multiple(control_freq, kv)

/obj/machinery/bot/mulebot/emp_act(severity)
	if (cell)
		cell.emp_act(severity)
	if(load)
		load.emp_act(severity)
	..()


/obj/machinery/bot/mulebot/explode()
	src.visible_message("<span class='danger'>[src] blows apart!</span>", 1)
	var/turf/Tsec = get_turf(src)

	new /obj/item/device/assembly/prox_sensor(Tsec)
	new /obj/item/stack/rods(Tsec)
	new /obj/item/stack/rods(Tsec)
	new /obj/item/stack/cable_coil/cut(Tsec)
	if (cell)
		cell.loc = Tsec
		cell.update_icon()
		cell = null

	var/datum/effect_system/spark_spread/s = new /datum/effect_system/spark_spread
	s.set_up(3, 1, src)
	s.start()

	new /obj/effect/decal/cleanable/blood/oil(src.loc)
	unload(0)
	qdel(src)
