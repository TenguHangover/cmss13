//use this define to highlight docking port bounding boxes (ONLY FOR DEBUG USE)
//#ifdef TESTING
//#define DOCKING_PORT_HIGHLIGHT
//#endif

//NORTH default dir
/obj/docking_port
	invisibility = 101
	icon = 'icons/obj/items/devices.dmi'
	icon_state = "pinonfar"

// resistance_flags = RESIST_ALL
	anchored = TRUE

	/**
	  * The identifier of the port or ship.
	  * This will be used in numerous other places like the console,
	  * stationary ports and whatnot to tell them your ship's mobile
	  * port can be used in these places, or the docking port is compatible, etc.
	  */
	var/id
	///Possible destinations
	var/port_destinations
	///this should point -away- from the dockingport door, ie towards the ship
	dir = NORTH
	///size of covered area, perpendicular to dir
	var/width = 0
	///size of covered area, parallel to dir
	var/height = 0
	///position relative to covered area, perpendicular to dir
	var/dwidth = 0
	///position relative to covered area, parallel to dir
	var/dheight = 0
	var/area_type
	///are we invisible to shuttle navigation computers?
	var/hidden = FALSE
	///Delete this port after ship fly off.
	var/delete_after = FALSE
	///are we registered in SSshuttles?
	var/registered = FALSE

///register to SSshuttles
/obj/docking_port/proc/register()
	if(registered)
		WARNING("docking_port registered multiple times")
		unregister()
	registered = TRUE
	return

///unregister from SSshuttles
/obj/docking_port/proc/unregister()
	if(!registered)
		WARNING("docking_port unregistered multiple times")
	registered = FALSE
	return

//these objects are indestructible
/obj/docking_port/Destroy(force)
	// unless you assert that you know what you're doing. Horrible things
	// may result.
	if(force)
		..()
		. = QDEL_HINT_QUEUE
	else
		return QDEL_HINT_LETMELIVE

/obj/docking_port/shuttleRotate()
	return //we don't rotate with shuttles via this code.

//returns a list(x0,y0, x1,y1) where points 0 and 1 are bounding corners of the projected rectangle
/obj/docking_port/proc/return_coords(_x, _y, _dir)
	if(_dir == null)
		_dir = dir
	if(_x == null)
		_x = x
	if(_y == null)
		_y = y

	//byond's sin and cos functions are inaccurate. This is faster and perfectly accurate
	var/cos = 1
	var/sin = 0
	switch(_dir)
		if(WEST)
			cos = 0
			sin = 1
		if(SOUTH)
			cos = -1
			sin = 0
		if(EAST)
			cos = 0
			sin = -1

	return list(
		_x + (-dwidth*cos) - (-dheight*sin),
		_y + (-dwidth*sin) + (-dheight*cos),
		_x + (-dwidth+width-1)*cos - (-dheight+height-1)*sin,
		_y + (-dwidth+width-1)*sin + (-dheight+height-1)*cos
		)

/// Return number of turfs
/obj/docking_port/proc/return_number_of_turfs()
	var/list/L = return_coords()
	return (L[3]-L[1]) * (L[4]-L[2])

///returns turfs within our projected rectangle in no particular order
/obj/docking_port/proc/return_turfs()
	var/list/L = return_coords()
	var/turf/T0 = locate(L[1],L[2],z)
	var/turf/T1 = locate(L[3],L[4],z)
	return block(T0,T1)

/obj/docking_port/proc/return_center_turf()
	var/list/L = return_coords()
	var/cos = 1
	var/sin = 0
	switch(dir)
		if(WEST)
			cos = 0
			sin = 1
		if(SOUTH)
			cos = -1
			sin = 0
		if(EAST)
			cos = 0
			sin = -1
	var/_x = L[1] + (round(width/2))*cos - (round(height/2))*sin
	var/_y = L[2] + (round(width/2))*sin + (round(height/2))*cos
	return locate(_x, _y, z)

//returns turfs within our projected rectangle in a specific order.
//this ensures that turfs are copied over in the same order, regardless of any rotation
/obj/docking_port/proc/return_ordered_turfs(_x, _y, _z, _dir)
	var/cos = 1
	var/sin = 0
	switch(_dir)
		if(WEST)
			cos = 0
			sin = 1
		if(SOUTH)
			cos = -1
			sin = 0
		if(EAST)
			cos = 0
			sin = -1

	. = list()

	for(var/dx in 0 to width-1)
		var/compX = dx-dwidth
		for(var/dy in 0 to height-1)
			var/compY = dy-dheight
			// realX = _x + compX*cos - compY*sin
			// realY = _y + compY*cos - compX*sin
			// locate(realX, realY, _z)
			var/turf/T = locate(_x + compX*cos - compY*sin, _y + compY*cos + compX*sin, _z)
			.[T] = NONE

#ifdef DOCKING_PORT_HIGHLIGHT
//Debug proc used to highlight bounding area
/obj/docking_port/proc/highlight(_color)
	var/list/L = return_coords()
	var/turf/T0 = locate(L[1],L[2],z)
	var/turf/T1 = locate(L[3],L[4],z)
	for(var/turf/T in block(T0,T1))
		T.color = _color
		T.maptext = null
	if(_color)
		var/turf/T = locate(L[1], L[2], z)
		T.color = "#0f0"
		T = locate(L[3], L[4], z)
		T.color = "#00f"
#endif

//return first-found touching dockingport
/obj/docking_port/proc/get_docked()
	return locate(/obj/docking_port/stationary) in loc

/obj/docking_port/proc/getDockedId()
	var/obj/docking_port/P = get_docked()
	if(P)
		return P.id

/obj/docking_port/proc/is_in_shuttle_bounds(atom/A)
	var/turf/T = get_turf(A)
	if(T.z != z)
		return FALSE
	var/list/bounds = return_coords()
	var/x0 = bounds[1]
	var/y0 = bounds[2]
	var/x1 = bounds[3]
	var/y1 = bounds[4]
	if(!ISINRANGE(T.x, min(x0, x1), max(x0, x1)))
		return FALSE
	if(!ISINRANGE(T.y, min(y0, y1), max(y0, y1)))
		return FALSE
	return TRUE

/obj/docking_port/stationary
	name = "dock"

	var/last_dock_time

	var/datum/map_template/shuttle/roundstart_template
	var/json_key

/obj/docking_port/stationary/register(replace = FALSE)
	. = ..()
	if(!id)
		id = "dock"
	else
		port_destinations = id

	if(!name)
		name = "dock"

	var/counter = SSshuttle.assoc_stationary[id]
	if(!replace || !counter)
		if(counter)
			counter++
			SSshuttle.assoc_stationary[id] = counter
			id = "[id]_[counter]"
			name = "[name] [counter]"
		else
			SSshuttle.assoc_stationary[id] = 1

	if(!port_destinations)
		port_destinations = id

	SSshuttle.stationary += src

/obj/docking_port/stationary/Initialize(mapload)
	. = ..()
	register()
	if(!area_type)
		var/area/place = get_area(src)
		area_type = place?.type // We might be created in nullspace

// if(mapload)
// for(var/turf/T in return_turfs())
// T.flags_1 |= NO_RUINS_1

	#ifdef DOCKING_PORT_HIGHLIGHT
	highlight("#f00")
	#endif

/obj/docking_port/stationary/unregister()
	. = ..()
	SSshuttle.stationary -= src

/obj/docking_port/stationary/Destroy(force)
	if(force)
		unregister()
	. = ..()

/obj/docking_port/stationary/Moved(atom/oldloc, dir, forced)
	. = ..()
	if(area_type) // We already have one
		return
	var/area/newarea = get_area(src)
	area_type = newarea?.type

/obj/docking_port/stationary/proc/load_roundstart()
	if(json_key)
		var/sid = SSmapping.configs[GROUND_MAP].shuttles[json_key]
		roundstart_template = SSmapping.shuttle_templates[sid]
		if(!roundstart_template)
			CRASH("json_key:[json_key] value \[[sid]\] resulted in a null shuttle template for [src]")
	else if(roundstart_template) // passed a PATH
		var/sid = "[initial(roundstart_template.shuttle_id)]"

		roundstart_template = SSmapping.shuttle_templates[sid]
		if(!roundstart_template)
			CRASH("Invalid path ([roundstart_template]) passed to docking port.")

	if(roundstart_template)
		SSshuttle.action_load(roundstart_template, src)

/obj/docking_port/stationary/proc/on_crash()
	return

/// Called when a new shuttle arrives
/obj/docking_port/stationary/proc/on_arrival(obj/docking_port/mobile/arriving_shuttle)
	return

/// Called when a new shuttle is about to arrive
/obj/docking_port/stationary/proc/on_prearrival(obj/docking_port/mobile/arriving_shuttle)
	return

/// Called when the docked shuttle ignites
/obj/docking_port/stationary/proc/on_dock_ignition(obj/docking_port/mobile/departing_shuttle)
	return

/// Called when a shuttle is about to complete undocking from this stationary dock (already physically gone)
/obj/docking_port/stationary/proc/on_departure(obj/docking_port/mobile/departing_shuttle)
	return

//returns first-found touching shuttleport
/obj/docking_port/stationary/get_docked()
	. = locate(/obj/docking_port/mobile) in loc

/obj/docking_port/stationary/transit
	name = "In Transit"
	var/datum/turf_reservation/reserved_area
	var/area/shuttle/transit/assigned_area
	var/obj/docking_port/mobile/owner

	var/spawn_time

/obj/docking_port/stationary/transit/Initialize()
	. = ..()
	SSshuttle.transit += src
	spawn_time = world.time

/obj/docking_port/stationary/transit/Destroy(force=FALSE)
	if(force)
		if(get_docked())
			log_world("A transit dock was destroyed while something was docked to it.")
		SSshuttle.transit -= src
		if(owner)
			if(owner.assigned_transit == src)
				log_world("A transit dock was qdeled while it was assigned to [owner].")
				owner.assigned_transit = null
			owner = null
		if(!QDELETED(reserved_area))
			qdel(reserved_area)
		reserved_area = null
	return ..()

/obj/docking_port/mobile
	name = "shuttle"
	icon_state = "pinonclose"

	area_type = SHUTTLE_DEFAULT_SHUTTLE_AREA_TYPE

	var/list/shuttle_areas

	var/timer //used as a timer (if you want time left to complete move, use timeLeft proc)
	var/last_timer_length

	var/mode = SHUTTLE_IDLE //current shuttle mode
	var/callTime = 100 //time spent in transit (deciseconds). Should not be lower then 10 seconds without editing the animation of the hyperspace ripples.
	var/ignitionTime = 55 // time spent "starting the engines". Also rate limits how often we try to reserve transit space if its ever full of transiting shuttles.
	var/rechargeTime = 0 //time spent after arrival before being able to launch again
	var/prearrivalTime = 0 //delay after call time finishes for sound effects, explosions, etc.

	var/landing_sound = 'sound/effects/engine_landing.ogg'
	var/ignition_sound = 'sound/effects/engine_startup.ogg'
	/// Default shuttle audio ambience while flying
	VAR_PROTECTED/ambience_flight = 'sound/ambience/shuttle_fly_loop.ogg'
	/// Default shuttle audio ambience while not flying
	VAR_PROTECTED/ambience_idle = 'sound/ambience/shuttle_idle_loop.ogg'

	// The direction the shuttle prefers to travel in
	var/preferred_direction = NORTH
	// And the angle from the front of the shuttle to the port
	var/port_direction = NORTH

	var/obj/docking_port/stationary/destination
	var/obj/docking_port/stationary/previous

	var/obj/docking_port/stationary/transit/assigned_transit

	var/launch_status = NOLAUNCH

	var/list/movement_force = list("KNOCKDOWN" = 3, "THROW" = 0)

	var/list/ripples = list()
	var/use_ripples = TRUE
	var/engine_coeff = 1 //current engine coeff
	var/cooldown_coeff = 1 // cooldown coeff
	var/current_engines = 0 //current engine power
	var/initial_engines = 0 //initial engine power
	var/can_move_docking_ports = FALSE //if this shuttle can move docking ports other than the one it is docked at
	var/list/hidden_turfs = list()

	var/crashing = FALSE

	var/shuttle_flags = NONE

/obj/docking_port/mobile/register()
	. = ..()
	SSshuttle.mobile += src

/obj/docking_port/mobile/Destroy(force)
	if(force)
		SSshuttle.mobile -= src
		destination = null
		previous = null
		QDEL_NULL(assigned_transit) //don't need it where we're goin'!
		shuttle_areas = null
		remove_ripples()
	return ..()

/obj/docking_port/mobile/Initialize(mapload)
	. = ..()

	if(!id)
		id = "[SSshuttle.mobile.len]"
	if(name == "shuttle")
		name = "shuttle[SSshuttle.mobile.len]"

	shuttle_areas = list()
	var/list/all_turfs = return_ordered_turfs(x, y, z, dir)
	for(var/i in 1 to all_turfs.len)
		var/turf/curT = all_turfs[i]
		var/area/cur_area = get_area(curT)
		if(istype(cur_area, area_type))
			shuttle_areas[cur_area] = TRUE

	initial_engines = count_engines()
	current_engines = initial_engines

	#ifdef DOCKING_PORT_HIGHLIGHT
	highlight("#0f0")
	#endif

/// Requests the proper sound ambience to play in the shuttle based on its state
/obj/docking_port/mobile/proc/get_sound_ambience()
	if(in_flight())
		return ambience_flight
	return ambience_idle

/// Update the sound ambience of ALL shuttle passengers
/obj/docking_port/mobile/proc/update_ambience()
	SHOULD_NOT_SLEEP(TRUE)
	PROTECTED_PROC(TRUE)
	for(var/client/C as anything in GLOB.clients)
		if(is_in_shuttle_bounds(C?.mob))
			C?.soundOutput.update_ambience()

// Called after the shuttle is loaded from template
/obj/docking_port/mobile/proc/linkup(datum/map_template/shuttle/template, obj/docking_port/stationary/dock)
	var/list/static/shuttle_id = list()
	var/idnum = ++shuttle_id[template]
	if(idnum > 1)
		if(id == initial(id))
			id = "[id][idnum]"
		if(name == initial(name))
			name = "[name] [idnum]"
	for(var/place in shuttle_areas)
		var/area/area = place
		area.connect_to_shuttle(src, dock, idnum, FALSE)
		for(var/each in place)
			var/atom/atom = each
			atom.connect_to_shuttle(src, dock, idnum, FALSE)


//this is a hook for custom behaviour. Maybe at some point we could add checks to see if engines are intact
/obj/docking_port/mobile/proc/canMove()
	return TRUE

//this is to check if this shuttle can physically dock at dock S
/obj/docking_port/mobile/proc/canDock(obj/docking_port/stationary/S)
	if(!istype(S))
		return SHUTTLE_NOT_A_DOCKING_PORT

	if(istype(S, /obj/docking_port/stationary/transit))
		return SHUTTLE_CAN_DOCK

	if(dwidth > S.dwidth)
		return SHUTTLE_DWIDTH_TOO_LARGE

	if(width-dwidth > S.width-S.dwidth)
		return SHUTTLE_WIDTH_TOO_LARGE

	if(dheight > S.dheight)
		return SHUTTLE_DHEIGHT_TOO_LARGE

	if(height-dheight > S.height-S.dheight)
		return SHUTTLE_HEIGHT_TOO_LARGE

	//check the dock isn't occupied
	var/currently_docked = S.get_docked()
	if(currently_docked)
		// by someone other than us
		if(currently_docked != src)
			return SHUTTLE_SOMEONE_ELSE_DOCKED
		else
		// This isn't an error, per se, but we can't let the shuttle code
		// attempt to move us where we currently are, it will get weird.
			return SHUTTLE_ALREADY_DOCKED

	return SHUTTLE_CAN_DOCK

/obj/docking_port/mobile/proc/check_dock(obj/docking_port/stationary/S, silent=FALSE)
	if(crashing)
		return TRUE
	var/status = canDock(S)
	if(status == SHUTTLE_CAN_DOCK)
		return TRUE
	if(status == SHUTTLE_ALREADY_DOCKED)
		return TRUE
	else
		if(!silent) // SHUTTLE_ALREADY_DOCKED is no cause for error
			var/msg = "Shuttle [src] cannot dock at [S], error: [status]"
			message_admins(msg)
		// We're already docked there, don't need to do anything.
		// Triggering shuttle movement code in place is weird
		return FALSE

/obj/docking_port/mobile/proc/transit_failure()
	message_admins("Shuttle [src] repeatedly failed to create transit zone.")
	log_debug("Setting [src]/[src.id] idle")
	set_idle()

//call the shuttle to destination S
/obj/docking_port/mobile/proc/request(obj/docking_port/stationary/S)
	if(!check_dock(S))
		WARNING("check_dock failed on request for [src]")
		return

	if(mode == SHUTTLE_IGNITING && destination == S)
		return

	switch(mode)
		if(SHUTTLE_CALL)
			if(S == destination)
				if(timeLeft(1) < callTime * engine_coeff)
					setTimer(callTime * engine_coeff)
			else
				destination = S
				setTimer(callTime * engine_coeff)
		if(SHUTTLE_RECALL)
			if(S == destination)
				setTimer(callTime * engine_coeff - timeLeft(1))
			else
				destination = S
				setTimer(callTime * engine_coeff)
			set_mode(SHUTTLE_CALL)
		if(SHUTTLE_IDLE, SHUTTLE_IGNITING, SHUTTLE_RECHARGING)
			destination = S
			set_mode(SHUTTLE_IGNITING)
			on_ignition()
			setTimer(ignitionTime)
		else
			stack_trace("Called request() with mode: [mode].")

// called on entering the igniting state
/obj/docking_port/mobile/proc/on_ignition()
	var/obj/docking_port/stationary/S = get_docked()
	S?.on_dock_ignition(src)
	if(ignition_sound)
		playsound(return_center_turf(), ignition_sound, 60, 0, falloff=4)
	return

/obj/docking_port/mobile/proc/on_prearrival()
	if(destination)
		destination.on_prearrival(src)
	playsound(return_center_turf(), landing_sound, 60, 0)
	return

/obj/docking_port/mobile/proc/on_crash()
	return

/obj/docking_port/mobile/proc/set_idle()
	timer = 0
	set_mode(SHUTTLE_IDLE)
	destination = null

//recall the shuttle to where it was previously
/obj/docking_port/mobile/proc/cancel()
	if(mode != SHUTTLE_CALL)
		return

	remove_ripples()

	invertTimer()
	set_mode(SHUTTLE_RECALL)

/obj/docking_port/mobile/proc/enterTransit()
	if((SSshuttle.lockdown && !is_reserved_level(z)) || !canMove()) //emp went off, no escape
		set_mode(SHUTTLE_IDLE)
		return
	previous = null
	if(!destination)
		// sent to transit with no destination -> unlimited timer
		timer = INFINITY
	var/obj/docking_port/stationary/S0 = get_docked()
	var/obj/docking_port/stationary/S1 = assigned_transit
	if(S1)
		if(initiate_docking(S1) != DOCKING_SUCCESS)
			WARNING("shuttle \"[id]\" could not enter transit space. Docked at [S0 ? S0.id : "null"]. Transit dock [S1 ? S1.id : "null"].")
		if(S0.delete_after)
			qdel(S0, TRUE)
		else
			previous = S0
			return TRUE
	else
		WARNING("shuttle \"[id]\" could not enter transit space. S0=[S0 ? S0.id : "null"] S1=[S1 ? S1.id : "null"]")


/obj/docking_port/mobile/proc/jumpToNullSpace()
	// Destroys the docking port and the shuttle contents.
	// Not in a fancy way, it just ceases.
	var/obj/docking_port/stationary/current_dock = get_docked()

	var/underlying_area_type = SHUTTLE_DEFAULT_UNDERLYING_AREA
	// If the shuttle is docked to a stationary port, restore its normal
	// "empty" area and turf
	if(current_dock && current_dock.area_type)
		underlying_area_type = current_dock.area_type

	var/list/old_turfs = return_ordered_turfs(x, y, z, dir)

	var/area/underlying_area = GLOB.areas_by_type[underlying_area_type]
	if(!underlying_area)
		underlying_area = new underlying_area_type(null)

	for(var/i in 1 to old_turfs.len)
		var/turf/oldT = old_turfs[i]
		if(!oldT || !istype(oldT.loc, area_type))
			continue
// var/area/old_area = oldT.loc
		underlying_area.contents += oldT
		//oldT.change_area(old_area, underlying_area) //lighting
		oldT.empty(FALSE)

		// Here we locate the bottomost shuttle boundary and remove all turfs above it
		var/list/baseturf_cache = oldT.baseturfs
		for(var/k in 1 to length(baseturf_cache))
			if(ispath(baseturf_cache[k], /turf/baseturf_skipover/shuttle))
				oldT.ScrapeAway(baseturf_cache.len - k + 1)
				break

	qdel(src, force=TRUE)

/obj/docking_port/mobile/proc/intoTheSunset()
	// Loop over mobs
	for(var/t in return_turfs())
		var/turf/T = t
		for(var/mob/living/L in T.GetAllContents())
			// Ghostize them and put them in nullspace stasis (for stat & possession checks)
			//L.notransform = TRUE
			var/mob/dead/observer/O = L.ghostize(FALSE)
			if(O)
				O.timeofdeath = world.time
			L.moveToNullspace()

	// Now that mobs are stowed, delete the shuttle
	jumpToNullSpace()

/obj/docking_port/mobile/proc/create_ripples(obj/docking_port/stationary/S1, animate_time)
	if(!use_ripples)
		return FALSE
	var/list/turfs = ripple_area(S1)
	for(var/t in turfs)
		ripples += new /obj/effect/abstract/ripple/shadow(t, animate_time)
	return TRUE

/obj/docking_port/mobile/proc/remove_ripples()
	QDEL_LIST(ripples)

/obj/docking_port/mobile/proc/ripple_area(obj/docking_port/stationary/S1)
	if(!S1)
		return list()
	var/list/L0 = return_ordered_turfs(x, y, z, dir)
	var/list/L1 = return_ordered_turfs(S1.x, S1.y, S1.z, S1.dir)

	var/list/ripple_turfs = list()

	for(var/i in 1 to L0.len)
		var/turf/T0 = L0[i]
		var/turf/T1 = L1[i]
		if(!T0 || !T1)
			continue  // out of bounds
		if(!istype(T0.loc, area_type) || istype(T0.loc, /area/shuttle/transit))
			continue  // not part of the shuttle
		ripple_turfs += T1

	return ripple_turfs

/obj/docking_port/mobile/proc/dock_id(id)
	var/port = SSshuttle.getDock(id)
	if(port)
		. = initiate_docking(port)
	else
		. = null

//used by shuttle subsystem to check timers
/obj/docking_port/mobile/proc/check()
	check_effects()

	if(mode == SHUTTLE_IGNITING)
		check_transit_zone()

	if(timeLeft(1) > 0)
		return
	// If we can't dock or we don't have a transit slot, wait for 20 ds,
	// then try again
	switch(mode)
		if(SHUTTLE_CALL, SHUTTLE_PREARRIVAL)
			if(prearrivalTime && mode != SHUTTLE_PREARRIVAL)
				set_mode(SHUTTLE_PREARRIVAL)
				setTimer(prearrivalTime)
				return
			on_prearrival()
			var/error = initiate_docking(destination, preferred_direction)
			if(error && error & (DOCKING_NULL_DESTINATION | DOCKING_NULL_SOURCE))
				//var/msg = "A mobile dock in transit exited initiate_docking() with an error. This is most likely a mapping problem: Error: [error],  ([src]) ([previous][ADMIN_JMP(previous)] -> [destination][ADMIN_JMP(destination)])"
				//WARNING(msg)
				//message_admins(msg)
				set_mode(SHUTTLE_IDLE)
				return
			else if(error)
				setTimer(20)
				return
			if(rechargeTime)
				set_mode(SHUTTLE_RECHARGING)
				destination = null
				setTimer(rechargeTime * cooldown_coeff())
				return
		if(SHUTTLE_RECALL)
			if(initiate_docking(previous) != DOCKING_SUCCESS)
				setTimer(20)
				return
		if(SHUTTLE_IGNITING)
			if(check_transit_zone() != TRANSIT_READY)
				setTimer(20)
				return
			else
				set_mode(SHUTTLE_CALL)
				setTimer(callTime * engine_coeff())
				enterTransit()
				return

	set_idle()

/obj/docking_port/mobile/proc/check_effects()
	if(!ripples.len)
		if((mode == SHUTTLE_PREARRIVAL))
			var/tl = timeLeft(1)
			if(tl <= SHUTTLE_RIPPLE_TIME)
				create_ripples(destination, tl)

	//var/obj/docking_port/stationary/S0 = get_docked()
	//if(istype(S0, /obj/docking_port/stationary/transit) && timeLeft(1) <= PARALLAX_LOOP_TIME)
		//for(var/place in shuttle_areas)
			//var/area/shuttle/shuttle_area = place
			//if(shuttle_area.parallax_movedir)
			// parallax_slowdown()

/obj/docking_port/mobile/proc/parallax_slowdown()
	//for(var/place in shuttle_areas)
	// var/area/shuttle/shuttle_area = place
	// shuttle_area.parallax_movedir = FALSE
	//if(assigned_transit && assigned_transit.assigned_area)
	// assigned_transit.assigned_area.parallax_movedir = FALSE
// var/list/L0 = return_ordered_turfs(x, y, z, dir)
// for (var/thing in L0)
// var/turf/T = thing
// if(!T || !istype(T.loc, area_type))
// continue
// for (var/thing2 in T)
// var/atom/movable/AM = thing2
// if (length(AM.client_mobs_in_contents))
// AM.update_parallax_contents()

/obj/docking_port/mobile/proc/check_transit_zone()
	if(assigned_transit)
		return TRANSIT_READY
	else
		SSshuttle.request_transit_dock(src)

/obj/docking_port/mobile/proc/setTimer(wait)
	timer = world.time + wait
	last_timer_length = wait

/obj/docking_port/mobile/proc/modTimer(multiple)
	var/time_remaining = timer - world.time
	if(time_remaining < 0 || !last_timer_length)
		return
	time_remaining *= multiple
	last_timer_length *= multiple
	setTimer(time_remaining)

/obj/docking_port/mobile/proc/invertTimer()
	if(!last_timer_length)
		return
	var/time_remaining = timer - world.time
	if(time_remaining > 0)
		var/time_passed = last_timer_length - time_remaining
		setTimer(time_passed)

//returns timeLeft
/obj/docking_port/mobile/proc/timeLeft(divisor)
	if(divisor <= 0)
		divisor = 10

	var/ds_remaining
	if(!timer)
		ds_remaining = callTime * engine_coeff
	else
		ds_remaining = max(0, timer - world.time)

	. = round(ds_remaining / divisor, 1)

// returns 3-letter mode string, used by status screens and mob status panel
/obj/docking_port/mobile/proc/getModeStr()
	switch(mode)
		if(SHUTTLE_IGNITING)
			return "IGN"
		if(SHUTTLE_RECALL)
			return "RCL"
		if(SHUTTLE_CALL)
			return "ETA"
		if(SHUTTLE_DOCKED)
			return "ETD"
		if(SHUTTLE_ESCAPE)
			return "ESC"
		if(SHUTTLE_STRANDED)
			return "ERR"
	return ""

// returns 5-letter timer string, used by status screens and mob status panel
/obj/docking_port/mobile/proc/getTimerStr()
	if(mode == SHUTTLE_STRANDED)
		return "--:--"

	var/timeleft = timeLeft()
	if(timeleft > 1 HOURS)
		return "--:--"
	else if(timeleft > 0)
		return "[add_leading(num2text((timeleft / 60) % 60), 2, "0")]:[add_leading(num2text(timeleft % 60), 2, "0")]"
	else
		return "00:00"


/obj/docking_port/mobile/proc/getStatusText()
	var/obj/docking_port/stationary/dockedAt = get_docked()

	if(mode == SHUTTLE_RECHARGING)
		return "recharging, [timeLeft()] seconds remaining"

	if(istype(dockedAt, /obj/docking_port/stationary/transit))
		if (timeLeft() > 1 HOURS)
			return "hyperspace"
		else
			var/obj/docking_port/stationary/dst
			if(mode == SHUTTLE_RECALL)
				dst = previous
			else
				dst = destination
			. = "transit towards [dst?.name || "unknown location"] ([getTimerStr()])"
	else
		return dockedAt?.name || "unknown"


/obj/docking_port/mobile/proc/getDbgStatusText()
	var/obj/docking_port/stationary/dockedAt = get_docked()
	. = (dockedAt && dockedAt.name) ? dockedAt.name : "unknown"
	if(istype(dockedAt, /obj/docking_port/stationary/transit))
		var/obj/docking_port/stationary/dst
		if(mode == SHUTTLE_RECALL)
			dst = previous
		else
			dst = destination
		if(dst)
			. = "(transit to) [dst.name || dst.id]"
		else
			. = "(transit to) nowhere"
	else if(dockedAt)
		. = dockedAt.name || dockedAt.id
	else
		. = "unknown"


// attempts to locate /obj/structure/machinery/computer/shuttle with matching ID inside the shuttle
/obj/docking_port/mobile/proc/getControlConsole()
	for(var/place in shuttle_areas)
		var/area/shuttle/shuttle_area = place
		for(var/obj/structure/machinery/computer/shuttle/S in shuttle_area)
			if(S.shuttleId == id)
				return S
	return null
/*
/obj/docking_port/mobile/proc/hyperspace_sound(phase, list/areas)
	var/s
	switch(phase)
		if(HYPERSPACE_WARMUP)
			s = 'sound/effects/hyperspace_begin.ogg'
		if(HYPERSPACE_LAUNCH)
			s = 'sound/effects/hyperspace_progress.ogg'
		if(HYPERSPACE_END)
			s = 'sound/effects/hyperspace_end.ogg'
		else
			CRASH("Invalid hyperspace sound phase: [phase]")
	for(var/A in areas)
		for(var/obj/structure/machinery/door/E in A) //dumb, I know, but playing it on the engines doesn't do it justice
			playsound(E, s, 100, FALSE, max(width, height) - WORLD_VIEW_NUM)
*/
// Losing all initial engines should get you 2
// Adding another set of engines at 0.5 time
/obj/docking_port/mobile/proc/alter_engines(mod)
	if(mod == 0)
		return
	var/old_coeff = engine_coeff
	engine_coeff = get_engine_coeff(current_engines,mod)
	current_engines = max(0,current_engines + mod)
	if(in_flight())
		var/delta_coeff = engine_coeff / old_coeff
		modTimer(delta_coeff)

/obj/docking_port/mobile/proc/count_engines()
	. = 0
// for(var/thing in shuttle_areas)
// var/area/shuttle/areaInstance = thing
// for(var/obj/structure/shuttle/engine/E in areaInstance.contents)
// if(!QDELETED(E))
// . += E.engine_power

// Double initial engines to get to 0.5 minimum
// Lose all initial engines to get to 2
//For 0 engine shuttles like BYOS 5 engines to get to doublespeed
/obj/docking_port/mobile/proc/get_engine_coeff(current,engine_mod)
	var/new_value = max(0,current + engine_mod)
	if(new_value == initial_engines)
		return 1
	if(new_value > initial_engines)
		var/delta = new_value - initial_engines
		var/change_per_engine = (1 - ENGINE_COEFF_MIN) / ENGINE_DEFAULT_MAXSPEED_ENGINES // 5 by default
		if(initial_engines > 0)
			change_per_engine = (1 - ENGINE_COEFF_MIN) / initial_engines // or however many it had
		return clamp(1 - delta * change_per_engine,ENGINE_COEFF_MIN,ENGINE_COEFF_MAX)
	if(new_value < initial_engines)
		var/delta = initial_engines - new_value
		var/change_per_engine = 1 //doesn't really matter should not be happening for 0 engine shuttles
		if(initial_engines > 0)
			change_per_engine = (ENGINE_COEFF_MAX -  1) / initial_engines //just linear drop to max delay
		return clamp(1 + delta * change_per_engine,ENGINE_COEFF_MIN,ENGINE_COEFF_MAX)

/obj/docking_port/mobile/proc/engine_coeff()
	return engine_coeff

/obj/docking_port/mobile/proc/cooldown_coeff()
	return cooldown_coeff

/obj/docking_port/mobile/proc/in_flight()
	switch(mode)
		if(SHUTTLE_CALL,SHUTTLE_RECALL)
			return TRUE
		if(SHUTTLE_IDLE,SHUTTLE_IGNITING)
			return FALSE
		else
			return FALSE // hmm

/obj/docking_port/mobile/emergency/in_flight()
	switch(mode)
		if(SHUTTLE_ESCAPE)
			return TRUE
		if(SHUTTLE_STRANDED,SHUTTLE_ENDGAME)
			return FALSE
		else
			return ..()


//Called when emergency shuttle leaves the station
/obj/docking_port/mobile/proc/on_emergency_launch()
	if(launch_status == UNLAUNCHED) //Pods will not launch from the mine/planet, and other ships won't launch unless we tell them to.
		launch_status = ENDGAME_LAUNCHED
		enterTransit()

/obj/docking_port/mobile/emergency/on_emergency_launch()
	return

//Called when emergency shuttle docks at centcom
/obj/docking_port/mobile/proc/on_emergency_dock()
	//Mapping a new docking point for each ship mappers could potentially want docking with centcom would take up lots of space, just let them keep flying off into the sunset for their greentext
	if(launch_status == ENDGAME_LAUNCHED)
		launch_status = ENDGAME_TRANSIT

/obj/docking_port/mobile/pod/on_emergency_dock()
	if(launch_status == ENDGAME_LAUNCHED)
		initiate_docking(SSshuttle.getDock("[id]_away")) //Escape pods dock at centcom
		set_mode(SHUTTLE_ENDGAME)

/obj/docking_port/mobile/emergency/on_emergency_dock()
	return

/obj/docking_port/mobile/proc/set_mode(new_mode)
	mode = new_mode
	SEND_SIGNAL(src, COMSIG_SHUTTLE_SETMODE, mode)
	INVOKE_ASYNC(src, PROC_REF(update_ambience))

/obj/docking_port/mobile/proc/can_move_topic(mob/user)
	if(mode == SHUTTLE_RECHARGING)
		to_chat(user, SPAN_WARNING("The engines are not ready to use yet!"))
		return FALSE
	if(launch_status == ENDGAME_LAUNCHED)
		to_chat(user, SPAN_WARNING("You've already escaped. Never going back to that place again!"))
		return FALSE
	if(mode != SHUTTLE_IDLE)
		to_chat(user, SPAN_WARNING("Shuttle already in transit."))
		return FALSE
	return TRUE
