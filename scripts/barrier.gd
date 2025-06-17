# barrier.gd - Timer-based solution with ColorRect visual feedback
extends Node2D

# Add this single signal - that's it!
signal passable_state_changed

@export var barrier_color: Color = Color.RED
@export var target_color: Color = Color.WHITE : set = set_target_color
@export var color_tolerance: float = 0.15
@export var show_target_outline: bool = true : set = set_show_target_outline
@export var outline_opacity: float = 0.8 : set = set_outline_opacity
@export var passable_duration: float = 3.0  # How long to stay passable once activated

@onready var color_rect: ColorRect = $ColorRect
@onready var static_body: StaticBody2D = $StaticBody2D
@onready var light_occluder_2d: LightOccluder2D = $LightOccluder2D
@onready var target_outline: Sprite2D = $TargetOutline
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var original_occluder: OccluderPolygon2D
var current_display_color: Color
var match_threshold: float = 0.15
var is_currently_passable: bool = false

# Timer-based state management
var passable_timer: float = 0.0
var was_color_matched: bool = false

func _ready() -> void:
	current_display_color = barrier_color
	color_rect.color = barrier_color
	original_occluder = light_occluder_2d.occluder
	update_target_outline()
	
	if LightManager:
		LightManager.light_hit_barrier.connect(_on_light_hit)
		LightManager.light_removed_from_barrier.connect(_on_light_removed)

func _process(delta: float) -> void:
	# Update timer
	if passable_timer > 0:
		passable_timer -= delta
		update_color_visual()  # Update the ColorRect color based on timer
	
	update_collision()

func update_color_visual():
	"""Update the ColorRect color based on timer progress"""
	if is_currently_passable and passable_timer > 0:
		# Calculate progress (1.0 = just activated, 0.0 = about to expire)
		var progress = passable_timer / passable_duration
		
		# Interpolate from target_color (when activated) back to current_display_color (when expiring)
		var visual_color = target_color.lerp(current_display_color, 1.0 - progress)
		color_rect.color = visual_color
	elif is_currently_passable:
		# Timer expired, show current display color
		color_rect.color = current_display_color
	else:
		# Not passable, show current display color
		color_rect.color = current_display_color

# Called by LightManager when lights change
func update_color_from_manager(new_color: Color):
	current_display_color = new_color
	
	# Update visual if not currently in timer mode
	if not is_currently_passable:
		color_rect.color = new_color

func _on_light_hit(light: Node2D, barrier: Node2D, color: Color):
	if barrier == self:
		pass

func _on_light_removed(light: Node2D, barrier: Node2D):
	if barrier == self:
		pass

func is_color_match(current: Color, target: Color, tolerance: float) -> bool:
	var distance = sqrt(
		pow(current.r - target.r, 2) + 
		pow(current.g - target.g, 2) + 
		pow(current.b - target.b, 2)
	)
	return distance < tolerance

func update_collision():
	var color_matches_now = is_color_match(current_display_color, target_color, match_threshold)
	
	# If color matches and we weren't matched before, start the timer
	if color_matches_now and not was_color_matched:
		passable_timer = passable_duration
		print("Color matched! Barrier passable for ", passable_duration, " seconds")
		animated_sprite_2d.play("unlock")
	
	# Update the match state
	was_color_matched = color_matches_now
	
	# Determine if barrier should be passable
	var should_be_passable = passable_timer > 0
	
	# Apply state change
	if should_be_passable != is_currently_passable:
		is_currently_passable = should_be_passable
		apply_collision_state()
		
		if is_currently_passable:
			print("Barrier became passable (", int(passable_timer), "s remaining)")
		else:
			print("Barrier became solid (timer expired)")
			animated_sprite_2d.play("lock")

func apply_collision_state():
	var previous_state = is_currently_passable
	
	if is_currently_passable:
		static_body.set_collision_layer_value(3, false)  # Player can pass through
		static_body.set_collision_layer_value(5, true)   # Keep light detection
		light_occluder_2d.occluder = null                # Light passes through
	else:
		static_body.set_collision_layer_value(3, true)   # Player blocked
		static_body.set_collision_layer_value(5, true)   # Light detection
		light_occluder_2d.occluder = original_occluder   # Light blocked

	
	# Only change: emit signal when state changes
	if previous_state != is_currently_passable:
		passable_state_changed.emit()

# Manual control functions for testing
func extend_timer(additional_time: float = 2.0):
	"""Extend the passable timer"""
	passable_timer += additional_time
	print("Timer extended by ", additional_time, "s. New total: ", passable_timer)

func force_passable_for_time(duration: float):
	"""Force barrier to be passable for specific duration"""
	passable_timer = duration
	print("Forced passable for ", duration, " seconds")

# Target outline functions
func set_target_color(new_color: Color):
	target_color = new_color
	update_target_outline()

func set_show_target_outline(show: bool):
	show_target_outline = show
	update_target_outline()

func set_outline_opacity(opacity: float):
	outline_opacity = opacity
	update_target_outline()

func update_target_outline():
	if not animated_sprite_2d:
		return
	
	if show_target_outline:
		animated_sprite_2d.visible = true
		animated_sprite_2d.modulate = Color(target_color.r, target_color.g, target_color.b, outline_opacity)
	else:
		animated_sprite_2d.visible = false

func update_outline_opacity(alpha: float):
	if animated_sprite_2d and show_target_outline:
		animated_sprite_2d.modulate.a = alpha

func should_block_light() -> bool:
	return not is_currently_passable

func cleanup():
	if LightManager:
		if LightManager.light_hit_barrier.is_connected(_on_light_hit):
			LightManager.light_hit_barrier.disconnect(_on_light_hit)
		if LightManager.light_removed_from_barrier.is_connected(_on_light_removed):
			LightManager.light_removed_from_barrier.disconnect(_on_light_removed)

func _exit_tree():
	cleanup()
