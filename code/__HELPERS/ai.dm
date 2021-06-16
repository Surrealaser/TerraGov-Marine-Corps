//Various macros
#define NODE_GET_VALUE_OF_WEIGHT(IDENTIFIER, NODE, WEIGHT_NAME) NODE.weights[IDENTIFIER][WEIGHT_NAME]

//The equivalent of get_step_towards but now for nodes; will NOT intelligently pathfind based on node weights or anything else
//Returns nothing if a suitable node in a direction isn't found, otherwise returns a node
/proc/get_node_towards(obj/effect/ai_node/startnode, obj/effect/ai_node/destination)
	if(startnode == destination)
		return startnode
	//Null value returned means no node in that direction
	return startnode.get_node_in_dir_in_adj(get_dir(startnode, destination))

///Returns a list of humans via get_dist and same z level method, very cheap compared to range()
/proc/cheap_get_humans_near(atom/movable/source, distance)
	. = list()
	for(var/human in GLOB.humans_by_zlevel["[source.z]"])
		var/mob/living/carbon/human/nearby_human = human
		if(get_dist(source, nearby_human) > distance)
			continue
		. += nearby_human

//Returns a list of xenos via get_dist and same z level method, very cheap compared to range()
/proc/cheap_get_xenos_near(atom/movable/source, distance)
	. = list()
	for(var/xeno in GLOB.alive_xeno_list)
		var/mob/living/carbon/xenomorph/nearby_xeno = xeno
		if(source.z != nearby_xeno.z)
			continue
		if(get_dist(source, nearby_xeno) > distance)
			continue
		. += nearby_xeno

///Returns a list of humans and xenos via get_dist and same z level method, very cheap compared to range()
/proc/cheap_get_living_near(atom/movable/source, distance)
	. = list()
	. += cheap_get_humans_near(source,distance)
	. += cheap_get_xenos_near(source,distance)
