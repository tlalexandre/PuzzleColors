extends Light
@onready var torch_light_player: PointLight2D = $TorchLight

func _ready():
	super._ready()

#func _draw():
	## Draw lines for each raycast showing all collisions
	#for raycast in raycast_array:
		#if raycast:
			#var multi_hits = get_multiple_collisions(raycast)
			#var start_pos = raycast.position
			#
			#if multi_hits.size() > 0:
				## Draw line to first solid collision or end of ray
				#var final_collision = null
				#
				#for hit_info in multi_hits:
					#var collider = hit_info.collider
					#
					## Check if this collision should stop the ray visually
					#if collider and collider.is_in_group("walls"):
						#final_collision = hit_info.position
						#break
					#elif collider and collider.is_in_group("barriers"):
						#var barrier = collider.get_parent()
						#if barrier and barrier.should_block_light():
							#final_collision = hit_info.position
							#break
				#
				#if final_collision:
					#var collision_point = to_local(final_collision)
					#draw_line(start_pos, collision_point, Color.RED, 3.0)
					#draw_circle(collision_point, 3, Color.YELLOW)
				#else:
					## No solid collision, draw full ray
					#var end_pos = start_pos + raycast.target_position
					#draw_line(start_pos, end_pos, Color.RED, 3.0)
				#
				## Draw small markers for passable barriers
				#for hit_info in multi_hits:
					#var collider = hit_info.collider
					#if collider and collider.is_in_group("barriers"):
						#var barrier = collider.get_parent()
						#if barrier and not barrier.should_block_light():
							#var point = to_local(hit_info.position)
							#draw_circle(point, 2, Color.GREEN)

func _physics_process(delta):
	# Call parent physics process (which now handles multi-collision)
	super._physics_process(delta)
	
	# Force redraw every frame to update the lines
	queue_redraw()
