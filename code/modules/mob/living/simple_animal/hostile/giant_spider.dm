#define SPINNING_WEB 1
#define LAYING_EGGS 2
#define MOVING_TO_TARGET 3
#define SPINNING_COCOON 4

//base type, generic 'worker' type spider with no defining gimmick
/mob/living/simple_animal/hostile/giant_spider
	name = "giant spider"
	desc = "A monstrously huge green spider with shimmering eyes."
	icon = 'icons/mob/spider.dmi'
	icon_state = "green"
	icon_living = "green"
	icon_dead = "green_dead"
	speak_emote = list("chitters")
	emote_hear = list("chitters")
	emote_see = list("rubs its forelegs together", "wipes its fangs", "stops suddenly")
	speak_chance = 5
	turns_per_move = 5
	see_in_dark = 10
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/spider
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "pokes"
	maxHealth = 125
	health = 125
	melee_damage_lower = 8
	melee_damage_upper = 15
	heat_damage_per_tick = 20
	cold_damage_per_tick = 20
	faction = "spiders"
	pass_flags = PASS_FLAG_TABLE
	move_to_delay = 3
	speed = 1
	max_gas = list("phoron" = 1, "carbon_dioxide" = 5, "methyl_bromide" = 1)
	mob_size = MOB_LARGE
	bleed_colour = "#0d5a71"
	break_stuff_probability = 25
	pry_time = 8 SECONDS

	var/poison_per_bite = 8
	var/poison_type = /datum/reagent/toxin/venom
	var/busy = 0
	var/eye_colour
	var/allowed_eye_colours = list(COLOR_RED, COLOR_ORANGE, COLOR_YELLOW, COLOR_LIME, COLOR_DEEP_SKY_BLUE, COLOR_INDIGO, COLOR_VIOLET, COLOR_PINK)
	var/hunt_chance = 1 //percentage chance the mob will run to a random nearby tile

//guards - less venomous, tanky, slower, prioritises protecting nurses
/mob/living/simple_animal/hostile/giant_spider/guard
	desc = "A monstrously huge brown spider with shimmering eyes."
	icon_state = "brown"
	icon_living = "brown"
	icon_dead = "brown_dead"
	meat_amount = 4
	maxHealth = 200
	health = 200
	melee_damage_lower = 10
	melee_damage_upper = 15
	poison_per_bite = 5
	speed = 2
	move_to_delay = 4
	break_stuff_probability = 15
	pry_time = 7 SECONDS

	var/paired_nurse //spider we follow
	var/vengance //how likely we are to fly into a rage if our nurse dies
	var/berserking

//nursemaids - these create webs and eggs - the weakest and least threatening
/mob/living/simple_animal/hostile/giant_spider/nurse
	desc = "A monstrously huge beige spider with shimmering eyes."
	icon_state = "beige"
	icon_living = "beige"
	icon_dead = "beige_dead"
	maxHealth = 80
	health = 80
	melee_damage_lower = 8
	melee_damage_upper = 12
	poison_per_bite = 8
	speed = 0
	poison_type = /datum/reagent/soporific
	break_stuff_probability = 10
	pry_time = 9 SECONDS

	var/atom/cocoon_target
	var/fed = 0
	var/max_eggs = 12
	var/infest_chance = 8
	var/paired_guard //spider that follows us

//hunters - the most damage, fast, average health and the only caste tenacious enough to break out of nets
/mob/living/simple_animal/hostile/giant_spider/hunter
	desc = "A monstrously huge black spider with shimmering eyes."
	icon_state = "black"
	icon_living = "black"
	icon_dead = "black_dead"
	maxHealth = 150
	health = 150
	melee_damage_lower = 15
	melee_damage_upper = 15
	poison_per_bite = 10
	speed = -1
	move_to_delay = 2
	break_stuff_probability = 30
	hunt_chance = 25
	can_escape = TRUE
	pry_time = 6 SECONDS

	var/leap_range = 5
	var/last_leapt
	var/leap_cooldown = 1 MINUTE

//spitters - fast, comparatively weak, very venomous; projectile attacks but will resort to melee once out of ammo
/mob/living/simple_animal/hostile/giant_spider/spitter
	desc = "A monstrously huge iridescent spider with shimmering eyes."
	icon_state = "purple"
	icon_living = "purple"
	icon_dead = "purple_dead"
	maxHealth = 100
	health = 100
	melee_damage_lower = 8
	melee_damage_upper = 12
	poison_per_bite = 15
	ranged = TRUE
	move_to_delay = 2
	projectiletype = /obj/item/projectile/venom
	projectilesound = 'sound/effects/hypospray.ogg'
	fire_desc = "spits venom"
	ranged_range = 5
	pry_time = 7 SECONDS

	var/venom_charge = 16

//General spider procs
/mob/living/simple_animal/hostile/giant_spider/Initialize(var/mapload, var/atom/parent)
	get_light_and_color(parent)
	spider_randomify()
	update_icon()
	. = ..()

/mob/living/simple_animal/hostile/giant_spider/proc/spider_randomify() //random math nonsense to get their damage, health and venomness values
	melee_damage_lower = rand(0.8 * initial(melee_damage_lower), initial(melee_damage_lower))
	melee_damage_upper = rand(initial(melee_damage_upper), (1.2 * initial(melee_damage_upper)))
	maxHealth = rand(initial(maxHealth), (1.3 * initial(maxHealth)))
	health = maxHealth
	eye_colour = pick(allowed_eye_colours)
	if(eye_colour)
		var/image/I = image(icon = icon, icon_state = "[icon_state]_eyes", layer = EYE_GLOW_LAYER)
		I.color = eye_colour
		I.plane = EFFECTS_ABOVE_LIGHTING_PLANE
		I.appearance_flags = RESET_COLOR
		overlays += I

/mob/living/simple_animal/hostile/giant_spider/on_update_icon()
	if(stat == DEAD)
		overlays.Cut()
		var/image/I = image(icon = icon, icon_state = "[icon_dead]_eyes")
		I.color = eye_colour
		I.appearance_flags = RESET_COLOR
		overlays += I

/mob/living/simple_animal/hostile/giant_spider/FindTarget()
	. = ..()
	if(.)
		if(!ranged) //ranged mobs find target after each shot, dont need this spammed quite so much
			custom_emote(1,"raises its forelegs at [.]")
		else
			if(prob(15))
				custom_emote(1,"locks its eyes on [.]")

/mob/living/simple_animal/hostile/giant_spider/AttackingTarget()
	. = ..()
	if(isliving(.))
		if(health < maxHealth)
			health += (0.2 * rand(melee_damage_lower, melee_damage_upper)) //heal a bit on hit
		var/mob/living/L = .
		if(L.reagents)
			L.reagents.add_reagent(poison_type, rand(0.5 * poison_per_bite, poison_per_bite))
			if(prob(poison_per_bite))
				to_chat(L, "<span class='warning'>You feel a tiny prick.</span>")

/mob/living/simple_animal/hostile/giant_spider/Life()
	. = ..()
	if(!stat && !incapacitated())
		if(stance == HOSTILE_STANCE_IDLE)
			//chance to skitter madly away
			if(!busy && prob(hunt_chance))
				stop_automated_movement = 1
				walk_to(src, pick(orange(20, src)), 1, move_to_delay)
				addtimer(CALLBACK(src, .proc/disable_stop_automated_movement), 5 SECONDS)

/mob/living/simple_animal/hostile/giant_spider/proc/disable_stop_automated_movement()
	stop_automated_movement = 0
	walk(src,0)

//Guard procs
/mob/living/simple_animal/hostile/giant_spider/guard/Life()
	. = ..()
	if(berserking)
		return
	if(!stat)
		if(!paired_nurse)
			find_nurse()
		if(paired_nurse && !busy && stance == HOSTILE_STANCE_IDLE)
			protect(paired_nurse)

/mob/living/simple_animal/hostile/giant_spider/guard/death()
	. = ..()
	if(paired_nurse)
		var/mob/living/simple_animal/hostile/giant_spider/nurse/N = paired_nurse
		if(N.paired_guard)
			N.paired_guard = null
		paired_nurse = null

/mob/living/simple_animal/hostile/giant_spider/guard/Destroy()
	. = ..()
	var/mob/living/simple_animal/hostile/giant_spider/nurse/N = paired_nurse
	paired_nurse = null
	if(N.paired_guard)
		N.paired_guard = null

/mob/living/simple_animal/hostile/giant_spider/guard/proc/find_nurse()
	var/mob/living/simple_animal/hostile/giant_spider/nurse/N 
	for(N in ListTargets(10))
		if(N.stat || N.paired_guard)
			continue
		paired_nurse = N
		N.paired_guard = src
		return 1

/mob/living/simple_animal/hostile/giant_spider/guard/proc/protect(mob/nurse)
	stop_automated_movement = 1
	walk_to(src, nurse, 2, move_to_delay)
	addtimer(CALLBACK(src, .proc/disable_stop_automated_movement), 5 SECONDS)

/mob/living/simple_animal/hostile/giant_spider/guard/proc/go_berserk()
	audible_message("<span class='danger'>\The [src] chitters wildly!</span>")
	melee_damage_lower +=5
	melee_damage_upper +=5
	move_to_delay--
	break_stuff_probability = 45
	addtimer(CALLBACK(src, .proc/calm_down), 3 MINUTES)

/mob/living/simple_animal/hostile/giant_spider/guard/proc/calm_down()
	berserking = FALSE
	visible_message("<span class='notice'>\The [src] calms down and surveys the area.</span>")
	melee_damage_lower -= 5
	melee_damage_upper -= 5
	move_to_delay++
	break_stuff_probability = 10

//Nurse procs
/mob/living/simple_animal/hostile/giant_spider/nurse/death()
	. = ..()
	if(paired_guard)
		var/mob/living/simple_animal/hostile/giant_spider/guard/G = paired_guard
		G.vengance = rand(50,100)
		if(prob(G.vengance))
			G.berserking = TRUE
			G.go_berserk()
			if(G.paired_nurse)
				G.paired_nurse = null
		paired_guard = null

/mob/living/simple_animal/hostile/giant_spider/nurse/Destroy()
	. = ..()
	var/mob/living/simple_animal/hostile/giant_spider/guard/G = paired_guard
	paired_guard = null
	if(G.paired_nurse)
		G.paired_nurse = null

/mob/living/simple_animal/hostile/giant_spider/nurse/AttackingTarget()
	. = ..()
	if(ishuman(.))
		var/mob/living/carbon/human/H = .
		if(prob(infest_chance) && max_eggs)
			var/obj/item/organ/external/O = pick(H.organs)
			if(!BP_IS_ROBOTIC(O) && !BP_IS_CRYSTAL(O) && (LAZYLEN(O.implants) < 2))
				var/eggs = new /obj/effect/spider/eggcluster(O, src)
				O.implants += eggs
				max_eggs--

/mob/living/simple_animal/hostile/giant_spider/nurse/proc/GiveUp(var/C)
	spawn(100)
		if(busy == MOVING_TO_TARGET)
			if(cocoon_target == C && get_dist(src,cocoon_target) > 1)
				cocoon_target = null
			busy = 0
			stop_automated_movement = 0

/mob/living/simple_animal/hostile/giant_spider/nurse/Life()
	..()
	if(!stat)
		if(stance == HOSTILE_STANCE_IDLE)
			var/list/can_see = view(src, 10)
			//30% chance to stop wandering and do something
			if(!busy && prob(30))
				//first, check for potential food nearby to cocoon
				for(var/mob/living/C in can_see)
					if(C.stat)
						cocoon_target = C
						busy = MOVING_TO_TARGET
						walk_to(src, C, 1, move_to_delay)
						//give up if we can't reach them after 10 seconds
						GiveUp(C)
						return

				//second, spin a sticky spiderweb on this tile
				var/obj/effect/spider/stickyweb/W = locate() in get_turf(src)
				if(!W)
					busy = SPINNING_WEB
					src.visible_message("<span class='notice'>\The [src] begins to secrete a sticky substance.</span>")
					stop_automated_movement = 1
					spawn(40)
						if(busy == SPINNING_WEB)
							new /obj/effect/spider/stickyweb(src.loc)
							busy = 0
							stop_automated_movement = 0
				else
					//third, lay an egg cluster there
					var/obj/effect/spider/eggcluster/E = locate() in get_turf(src)
					if(!E && fed > 0 && max_eggs)
						busy = LAYING_EGGS
						src.visible_message("<span class='notice'>\The [src] begins to lay a cluster of eggs.</span>")
						stop_automated_movement = 1
						spawn(50)
							if(busy == LAYING_EGGS)
								E = locate() in get_turf(src)
								if(!E)
									new /obj/effect/spider/eggcluster(loc, src)
									max_eggs--
									fed--
								busy = 0
								stop_automated_movement = 0
					else
						//fourthly, cocoon any nearby items so those pesky pinkskins can't use them
						for(var/obj/O in can_see)

							if(O.anchored)
								continue

							if(istype(O, /obj/item) || istype(O, /obj/structure) || istype(O, /obj/machinery))
								cocoon_target = O
								busy = MOVING_TO_TARGET
								stop_automated_movement = 1
								walk_to(src, O, 1, move_to_delay)
								//give up if we can't reach them after 10 seconds
								GiveUp(O)

			else if(busy == MOVING_TO_TARGET && cocoon_target)
				if(get_dist(src, cocoon_target) <= 1)
					busy = SPINNING_COCOON
					src.visible_message("<span class='notice'>\The [src] begins to secrete a sticky substance around \the [cocoon_target].</span>")
					stop_automated_movement = 1
					walk(src,0)
					spawn(50)
						if(busy == SPINNING_COCOON)
							if(cocoon_target && istype(cocoon_target.loc, /turf) && get_dist(src,cocoon_target) <= 1)
								var/obj/effect/spider/cocoon/C = new(cocoon_target.loc)
								var/large_cocoon = 0
								C.pixel_x = cocoon_target.pixel_x
								C.pixel_y = cocoon_target.pixel_y
								for(var/mob/living/M in C.loc)
									if(istype(M, /mob/living/simple_animal/hostile/giant_spider))
										continue
									large_cocoon = 1
									fed++
									max_eggs++
									src.visible_message("<span class='warning'>\The [src] sticks a proboscis into \the [cocoon_target] and sucks a viscous substance out.</span>")
									M.forceMove(C)
									C.pixel_x = M.pixel_x
									C.pixel_y = M.pixel_y
									break
								for(var/obj/item/I in C.loc)
									I.forceMove(C)
								for(var/obj/structure/S in C.loc)
									if(!S.anchored)
										S.forceMove(C)
								for(var/obj/machinery/M in C.loc)
									if(!M.anchored)
										M.forceMove(C)
								if(large_cocoon)
									C.icon_state = pick("cocoon_large1","cocoon_large2","cocoon_large3")
							busy = 0
							stop_automated_movement = 0

		else
			busy = 0
			stop_automated_movement = 0

//Hunter procs
/mob/living/simple_animal/hostile/giant_spider/hunter/MoveToTarget()
	if(stop_AI || incapacitated())
		return
	var/mob/living/target = target_mob
	if(can_leap(target))
		prepare_leap(target)
		last_leapt = world.time + leap_cooldown
	..()

/mob/living/simple_animal/hostile/giant_spider/hunter/proc/can_leap(mob/living/target)
//	if(incapacitated() || last_leapt > world.time || !target || !isliving(target) || (get_dist(src, target) >= 3))
	if(incapacitated())
		world << "incap check failed"
		return FALSE
	if(last_leapt > world.time)
		world << "cooldown check failed"
		return FALSE
	if(!target)
		world << "target check failed"
		return FALSE
	if(!isliving(target))
		world << "isliving check failed"
		return FALSE
	if(get_dist(src, target) <= 3)
		world << "too close check failed"
		return FALSE
	if(get_dist(src, target) <= leap_range)
		world << "can_leap passed"
		return TRUE

/mob/living/simple_animal/hostile/giant_spider/hunter/proc/prepare_leap(mob/living/target)
	if(get_dist(get_turf(src), get_turf(target)) > leap_range)
		return
	face_atom(target)
	walk(src,0)
	stop_AI = TRUE
	visible_message("<span class='warning'>\The [src] reels back and prepares to launch itself at \the [target]!</span>")
	addtimer(CALLBACK(src, .proc/leap, target), 1 SECOND)

/mob/living/simple_animal/hostile/giant_spider/hunter/proc/leap(mob/living/target)
	visible_message("<span class='danger'>\The [src] springs forward towards \the [target]!</span>")
	throw_at(get_step(get_turf(target),get_turf(src)), leap_range, 1, src)
	addtimer(CALLBACK(src, .proc/resolve_leap, target), 5)

/mob/living/simple_animal/hostile/giant_spider/hunter/proc/resolve_leap(mob/living/target)
	stop_AI = FALSE
	if(Adjacent(target))
		visible_message("<span class='danger'>\The [src] slams into \the [target], knocking them over!</span>")
		target.Weaken(0.1)
		MoveToTarget()
	else
		visible_message("<span class='warning'>\The [src] misses its quarry and staggers!</span>")
		Stun(2) //we missed!

//Spitter procs
/mob/living/simple_animal/hostile/giant_spider/spitter/Life()
	..()
	if(venom_charge <= 0)
		ranged = FALSE
		if(prob(25))
			venom_charge++
			if(venom_charge >= 8)
				ranged = TRUE

/mob/living/simple_animal/hostile/giant_spider/spitter/Shoot()
	..()
	venom_charge--

#undef SPINNING_WEB
#undef LAYING_EGGS
#undef MOVING_TO_TARGET
#undef SPINNING_COCOON
