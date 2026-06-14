extends Node2D

enum GameMode {
	MAIN_MENU,
	PAUSE_MENU,
	GAME_OVER_MENU,
	MAIN_AREA,
	ARENA_AREA,
}

# scenes
var finger_projectile_scene = preload("res://scenes/finger_projectile.tscn")

# nodes
@onready var world_view = $WorldView
@onready var overlay_view = $OverlayView
@onready var display = $Display

@onready var player_character_body = $WorldView/World/PlayerCharacterBody
@onready var player_camera = $WorldView/World/PlayerCharacterBody/Camera
@onready var player_hand = $WorldView/World/PlayerCharacterBody/Camera/Hand
@onready var player_projectile_spawn_point = $WorldView/World/PlayerCharacterBody/Camera/ProjectileSpawnPoint
@onready var the_orb = $WorldView/World/MainArea/TheOrb
@onready var player_projectiles = $WorldView/World/PlayerProjectiles

@onready var overlay_camera = $OverlayView/Overlay/Camera

# constants
const EPSILON = 1e-6
const HALF_PI = PI / 2

const MAIN_MENU_BUTTON_START := Rect2(0, 0, 512, 144)
const MAIN_MENU_BUTTON_QUIT := Rect2(0, 144, 512, 144)
const PAUSE_MENU_BUTTON_RESUME := Rect2(0, 0, 512, 144)
const PAUSE_MENU_BUTTON_MAIN_MENU := Rect2(0, 144, 512, 144)
const GAME_OVER_MENU_BUTTON_MAIN_MENU := Rect2(0, 144, 512, 144)
const GAME_OVER_MENU_BUTTON_RESTART := Rect2(0, 0, 512, 144)

const MOUSE_INPUT_SENSITIVITY := 0.005

const FOCUS_AREA_MAIN_POSITION := Vector3(0, 0, 0)
const FOCUS_AREA_ARENA_POSITION := Vector3(1000, 0, 0)

const PLAYER_CHARACTER_MAIN_MENU_INITIAL_POSITION := Vector3(0, 70, 0)
const PLAYER_CHARACTER_MAIN_AREA_INITIAL_POSITION := Vector3(0, 1, 0)
const PLAYER_CHARACTER_ARENA_AREA_INITIAL_POSITION := Vector3(1000, 1, 0)

const PLAYER_CAMERA_DEFAULT_POSITION := Vector3(0, 0.5, 0)
const PLAYER_CAMERA_SLIDE_POSITION := Vector3(0, -0.4, 0)

const PLAYER_HAND_OUT_POSITION := Vector3(0, -0.6, -0.85)
const PLAYER_HAND_HIDDEN_POSITION := Vector3(0, -1.2, -0.7)

# variables
var rng = RandomNumberGenerator.new()

var game_mode := GameMode.MAIN_MENU
var paused_game_mode: GameMode

var player_input_enabled := false
var player_input_jump_buffer := 0.0
var player_input_slide_buffer := 0.0
var player_input_move_direction := Vector3.ZERO
var player_input_shoot_1_buffer := 0.0
var player_input_shoot_1_cooldown_buffer := 0.0

var player_can_jump_buffer := 0.0
var player_velocity_storage_vector := Vector3.ZERO
var player_velocity_storage_buffer := 0.0
var player_slide_storage_vector := Vector3.ZERO
var player_slide_storage_buffer := 0.0
var player_sliding := false
var player_slide_vector := Vector3.ZERO
var player_initiated_slide := false

var player_camera_shake_amount := 0.0
var player_camera_walk_offset := 0.0
var player_camera_walk_time := 0.0
var player_hand_shake_amount := 0.0
var player_hand_offset := Vector2.ZERO
var player_hand_shake := 0.0
var player_input_physics_frame_accumulated_mouse_movement_x := 0.0
var player_camera_tilt_amount := 0.0

var display_white_out_amount := 0.0
var display_red_outline_amount := 0.0
var display_speed_lines_amount := 0.0

func reset_player_effects():
	player_input_jump_buffer = 0
	player_input_slide_buffer = 0
	player_input_move_direction = Vector3.ZERO
	player_input_shoot_1_buffer = 0
	player_input_shoot_1_cooldown_buffer = 0
	player_can_jump_buffer = 0
	player_velocity_storage_vector = Vector3.ZERO
	player_velocity_storage_buffer = 0
	player_sliding = false
	player_slide_vector = Vector3.ZERO
	player_camera_shake_amount = 0
	player_camera_walk_offset = 0
	player_camera_walk_time = 0
	player_hand_shake_amount = 0
	player_hand_offset = Vector2.ZERO
	player_hand_shake = 0
	player_input_physics_frame_accumulated_mouse_movement_x = 0
	player_camera_tilt_amount = 0
	
func reset_focus_area():
	for child in player_projectiles.get_children():
		child.queue_free()

func settup_main_menu():
	game_mode = GameMode.MAIN_MENU
	player_input_enabled = false

	player_character_body.position = PLAYER_CHARACTER_MAIN_MENU_INITIAL_POSITION
	player_character_body.velocity = Vector3(0, -42, 0)
	player_hand.position = PLAYER_HAND_HIDDEN_POSITION
	player_character_body.rotation = Vector3.ZERO
	player_camera.rotation = Vector3.ZERO
	
	reset_player_effects()
	reset_focus_area()

func settup_game_over_menu():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_mode = GameMode.GAME_OVER_MENU
	player_input_enabled = false

func settup_respawn():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game_mode = GameMode.MAIN_AREA
	player_input_enabled = true

	player_character_body.position = PLAYER_CHARACTER_MAIN_AREA_INITIAL_POSITION
	player_character_body.velocity = Vector3.ZERO
	player_hand.position = PLAYER_HAND_HIDDEN_POSITION
	player_character_body.rotation = Vector3.ZERO
	player_camera.rotation = Vector3.ZERO

	reset_player_effects()
	reset_focus_area()

func settup_arena_enter():
	game_mode = GameMode.ARENA_AREA
	player_input_enabled = true

	player_character_body.position = PLAYER_CHARACTER_ARENA_AREA_INITIAL_POSITION
	player_character_body.velocity = Vector3.ZERO
	player_hand.position = PLAYER_HAND_HIDDEN_POSITION
	player_character_body.rotation = Vector3.ZERO
	player_camera.rotation = Vector3.ZERO

	reset_player_effects()
	reset_focus_area()

func process_player_movement(delta: float) -> void:
	if player_input_enabled:
		if Input.is_action_pressed("slide"):
			player_input_slide_buffer = 0.15

		player_input_move_direction = Vector3.ZERO
		if Input.is_action_pressed("move_forward"):
			player_input_move_direction.z -= 1
		if Input.is_action_pressed("move_backward"):
			player_input_move_direction.z += 1
		if Input.is_action_pressed("move_left"):
			player_input_move_direction.x -= 1
		if Input.is_action_pressed("move_right"):
			player_input_move_direction.x += 1
		player_input_move_direction = player_input_move_direction.normalized()

	player_character_body.velocity.y = max(player_character_body.velocity.y - 12 * delta, -42)

	player_initiated_slide = false
	if player_input_slide_buffer != 0:
		if player_character_body.is_on_floor():
			if !player_sliding:
				player_slide_vector = player_character_body.basis * Vector3.FORWARD * 11
				player_sliding = true
				player_initiated_slide = true
			player_input_slide_buffer = 0
		else:
			player_sliding = false
	else:
		if player_sliding:
			player_slide_storage_vector = player_slide_vector
			player_slide_storage_buffer = 0.15
		player_sliding = false

	if player_character_body.is_on_floor():
		player_can_jump_buffer = 0.15

	var just_jumped := false
	if player_input_jump_buffer != 0:
		if player_can_jump_buffer != 0:
			if player_sliding:
				player_sliding = false
				player_character_body.velocity.x = player_slide_vector.x
				player_character_body.velocity.z = player_slide_vector.z
				player_character_body.velocity.y = 9
			else:
				if player_velocity_storage_buffer != 0:
					player_character_body.velocity.x = player_velocity_storage_vector.x
					player_character_body.velocity.z = player_velocity_storage_vector.z
					player_velocity_storage_buffer = 0
				if player_slide_storage_buffer != 0:
					player_character_body.velocity.x = player_slide_storage_vector.x
					player_character_body.velocity.z = player_slide_storage_vector.z
					player_slide_storage_buffer = 0
				player_character_body.velocity.y = 9
			just_jumped = true
			player_input_jump_buffer = 0
			player_can_jump_buffer = 0

	if player_sliding:
		player_character_body.velocity.x = player_slide_vector.x
		player_character_body.velocity.z = player_slide_vector.z
	else:
		var player_input_move_direction_length := player_input_move_direction.length()
		if player_character_body.is_on_floor() and !just_jumped:
			if player_input_move_direction_length > 0:
				player_character_body.velocity.x *= pow(0.01, delta)
				player_character_body.velocity.z *= pow(0.01, delta)
			else:
				player_character_body.velocity.x *= pow(0.001, delta)
				player_character_body.velocity.z *= pow(0.001, delta)

			var new_player_character_body_velocity: Vector3 = player_character_body.velocity + player_character_body.basis * player_input_move_direction * 35 * delta
			var new_player_character_body_velocity_length = (new_player_character_body_velocity * Vector3(1, 0, 1)).length()

			if new_player_character_body_velocity_length > 8:
				new_player_character_body_velocity = new_player_character_body_velocity / new_player_character_body_velocity_length * 8

			player_character_body.velocity.x = new_player_character_body_velocity.x
			player_character_body.velocity.z = new_player_character_body_velocity.z
		else:
			if player_input_move_direction_length > 0:
				var player_character_body_velocity_length: float = (player_character_body.velocity * Vector3(1, 0, 1)).length()

				if player_character_body_velocity_length < 8:
					player_character_body.velocity.x *= pow(0.01, delta)
					player_character_body.velocity.z *= pow(0.01, delta)

					var new_player_character_body_velocity: Vector3 = player_character_body.velocity + player_character_body.basis * player_input_move_direction * 35 * delta
					var new_player_character_body_velocity_length = (new_player_character_body_velocity * Vector3(1, 0, 1)).length()

					if new_player_character_body_velocity_length > 8:
						new_player_character_body_velocity = new_player_character_body_velocity / new_player_character_body_velocity_length * 8

					player_character_body.velocity.x = new_player_character_body_velocity.x
					player_character_body.velocity.z = new_player_character_body_velocity.z
				else:
					var new_player_character_body_velocity: Vector3 = player_character_body.velocity + player_character_body.basis * player_input_move_direction * 50 * delta
					var new_player_character_body_velocity_length = (new_player_character_body_velocity * Vector3(1, 0, 1)).length()

					if new_player_character_body_velocity_length > player_character_body_velocity_length:
						new_player_character_body_velocity = new_player_character_body_velocity / new_player_character_body_velocity_length * player_character_body_velocity_length

					player_character_body.velocity.x = new_player_character_body_velocity.x
					player_character_body.velocity.z = new_player_character_body_velocity.z

	var player_is_not_on_floor_old = false
	if !player_character_body.is_on_floor() or just_jumped:
		player_is_not_on_floor_old = true

	player_character_body.move_and_slide()
	
	if player_character_body.is_on_floor() and !just_jumped and player_is_not_on_floor_old:
		player_velocity_storage_buffer = 0.15
		player_velocity_storage_vector = player_character_body.velocity

	player_input_jump_buffer = max(player_input_jump_buffer - delta, 0)
	player_input_slide_buffer = max(player_input_slide_buffer - delta, 0)
	player_can_jump_buffer = max(player_can_jump_buffer - delta, 0)
	player_velocity_storage_buffer = max(player_velocity_storage_buffer - delta, 0)
	player_slide_storage_buffer = max(player_slide_storage_buffer - delta, 0)

func process_player_main_area(delta: float) -> void:
	var previous_player_character_body_velocity = player_character_body.velocity

	process_player_movement(delta)

	player_camera_shake_amount *= pow(0.01, delta)
	player_camera_tilt_amount *= pow(0.05, delta)
	if player_character_body.velocity.y - previous_player_character_body_velocity.y >= 42 - EPSILON:
		player_camera_shake_amount = 0.3
	if player_character_body.is_on_floor():
		if player_camera_shake_amount < 0.01:
			player_input_enabled = true
	if player_character_body.is_on_floor() and !player_sliding and player_input_move_direction.length() != 0:
		player_camera_walk_offset = sin(player_camera_walk_time * 10) * 0.02
		player_camera_walk_time += delta
	else:
		player_camera_walk_time = 0
	player_camera.position += Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.5, 0.1), rng.randf_range(-1.2, 1.2)) * (player_camera_shake_amount + 0.003)
	if !player_sliding:
		if player_camera_walk_time != 0:
			player_camera.position.y += player_camera_walk_offset
		player_camera.position = lerp(player_camera.position, PLAYER_CAMERA_DEFAULT_POSITION, delta * 10)
		player_camera_tilt_amount -= player_input_move_direction.x * 0.6 * delta
		player_input_physics_frame_accumulated_mouse_movement_x = 0
		if player_initiated_slide:
			display_speed_lines_amount = 1
	else:
		player_camera.position = lerp(player_camera.position, PLAYER_CAMERA_SLIDE_POSITION, delta * 10)
		player_camera_tilt_amount += min(abs(player_input_physics_frame_accumulated_mouse_movement_x) * 0.02, 0.02) * sign(player_input_physics_frame_accumulated_mouse_movement_x)
		display_speed_lines_amount = 1
	player_camera.rotation.z = player_camera_tilt_amount

	if abs((the_orb.position - player_character_body.position).length()) < 1.5:
		display_white_out_amount = min(display_white_out_amount + delta, 1)
	else:
		display_white_out_amount *= pow(0.00001, delta)
	if display_white_out_amount == 1:
		settup_arena_enter()
	if player_character_body.position.y < -50:
		display_red_outline_amount = 1
		settup_respawn()

func process_player_arena_area(delta: float) -> void:
	process_player_movement(delta)

	if player_input_enabled:
		if Input.is_action_pressed("button_0"):
			player_hand_shake_amount = max(player_hand_shake_amount, 0.015)
			player_camera_shake_amount = max(player_camera_shake_amount, 0.02)

			var new_finger_projectile = finger_projectile_scene.instantiate()
			new_finger_projectile.position = player_projectile_spawn_point.global_position + (Vector3(randf(), randf(), randf()) * 2 - Vector3.ONE) * 0.2
			new_finger_projectile.rotation.x = randf() * 10
			new_finger_projectile.rotation.y = randf() * 10
			new_finger_projectile.rotation.z = randf() * 10
			new_finger_projectile.direction = -player_camera.global_basis.z
			new_finger_projectile.speed = 25
			new_finger_projectile.drag = 0.0
			new_finger_projectile.life_time = 2
			player_projectiles.add_child(new_finger_projectile)
		if player_input_shoot_1_buffer != 0 and player_input_shoot_1_cooldown_buffer == 0:
			player_character_body.velocity += player_camera.global_basis.z * Vector3(3.5, 3, 3.5)
			player_hand_shake_amount = 0.12
			player_camera_shake_amount = max(player_camera_shake_amount, 0.2)

			for i in range(50):
				var new_finger_projectile = finger_projectile_scene.instantiate()
				new_finger_projectile.position = player_projectile_spawn_point.global_position
				var base_direction = -player_camera.global_basis.z
				var spread = 0.15
				var random_x = rng.randfn() * spread
				var random_y = rng.randfn() * spread
				var random_z = rng.randfn() * spread
				var spread_transform = Transform3D(
				Basis().rotated(Vector3.RIGHT, random_x).rotated(Vector3.UP, random_y).rotated(Vector3.FORWARD, random_z))
				var final_direction = (spread_transform.basis * base_direction).normalized()
				new_finger_projectile.direction = final_direction
				new_finger_projectile.speed = 35
				new_finger_projectile.drag = 0.03
				new_finger_projectile.life_time = 0.5 + randf() * 0.5

				player_projectiles.add_child(new_finger_projectile)

			player_input_shoot_1_buffer = 0
			player_input_shoot_1_cooldown_buffer = 0.5

	player_input_shoot_1_buffer = max(player_input_shoot_1_buffer - delta, 0)
	player_input_shoot_1_cooldown_buffer = max(player_input_shoot_1_cooldown_buffer - delta, 0)

	player_camera_shake_amount *= pow(0.01, delta)
	player_hand_shake_amount *= pow(0.005, delta)
	player_camera_tilt_amount *= pow(0.05, delta)
	player_hand_offset.x *= pow(0.0005, delta)
	player_hand_offset.y *= pow(0.00001, delta)
	if player_character_body.is_on_floor() and !player_sliding and player_input_move_direction.length() != 0:
		player_camera_walk_offset = sin(player_camera_walk_time * 10) * 0.02
		player_camera_walk_time += delta
	else:
		player_camera_walk_time = 0
	player_camera.position += Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * (player_camera_shake_amount + 0.01)
	if !player_sliding:
		if player_camera_walk_time != 0:
			player_camera.position.y += player_camera_walk_offset
			player_hand.position.y -= player_camera_walk_offset * 0.15
		player_camera.position = lerp(player_camera.position, PLAYER_CAMERA_DEFAULT_POSITION, delta * 10)
		player_camera_tilt_amount -= player_input_move_direction.x * 0.6 * delta
		player_input_physics_frame_accumulated_mouse_movement_x = 0
		if player_initiated_slide:
			display_speed_lines_amount = 1
	else:
		player_camera.position = lerp(player_camera.position, PLAYER_CAMERA_SLIDE_POSITION, delta * 10)
		player_camera_tilt_amount += min(abs(player_input_physics_frame_accumulated_mouse_movement_x) * 0.02, 0.02) * sign(player_input_physics_frame_accumulated_mouse_movement_x)
		display_speed_lines_amount = 1
		player_hand_offset.y += 0.003
	player_hand.position += Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8), 1.) * player_hand_shake_amount
	player_hand.position = lerp(player_hand.position, PLAYER_HAND_OUT_POSITION, delta * 6)
	player_camera.rotation.z = player_camera_tilt_amount
	display_white_out_amount *= pow(0.00001, delta)
	player_hand_offset.y -= min(abs(player_character_body.velocity.y) * 0.0004, 0.003) * sign(player_character_body.velocity.y)
	player_hand.position.x += player_hand_offset.x
	player_hand.position.y += player_hand_offset.y

	if player_character_body.position.y < -50:
		display_red_outline_amount = 1
		settup_game_over_menu()

func process_player_game_over_screen(delta):
	process_player_movement(delta)

	player_camera_shake_amount *= pow(0.01, delta)
	player_hand_shake_amount *= pow(0.005, delta)
	player_camera_tilt_amount *= pow(0.05, delta)
	player_hand_offset.x *= pow(0.0005, delta)
	player_hand_offset.y *= pow(0.00001, delta)
	if player_character_body.is_on_floor() and !player_sliding and player_input_move_direction.length() != 0:
		player_camera_walk_offset = sin(player_camera_walk_time * 10) * 0.02
		player_camera_walk_time += delta
	else:
		player_camera_walk_time = 0
	player_camera.position += Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * (player_camera_shake_amount + 0.01)
	if !player_sliding:
		if player_camera_walk_time != 0:
			player_camera.position.y += player_camera_walk_offset
			player_hand.position.y -= player_camera_walk_offset * 0.15
		player_camera.position = lerp(player_camera.position, PLAYER_CAMERA_DEFAULT_POSITION, delta * 10)
		player_camera_tilt_amount -= player_input_move_direction.x * 0.6 * delta
		player_input_physics_frame_accumulated_mouse_movement_x = 0
		if player_initiated_slide:
			display_speed_lines_amount = 1
	else:
		player_camera.position = lerp(player_camera.position, PLAYER_CAMERA_SLIDE_POSITION, delta * 10)
		player_camera_tilt_amount += min(abs(player_input_physics_frame_accumulated_mouse_movement_x) * 0.02, 0.02) * sign(player_input_physics_frame_accumulated_mouse_movement_x)
		display_speed_lines_amount = 1
		player_hand_offset.y += 0.003
	player_hand.position += Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8), 1.) * player_hand_shake_amount
	player_hand.position = lerp(player_hand.position, PLAYER_HAND_OUT_POSITION, delta * 6)
	player_camera.rotation.z = player_camera_tilt_amount
	display_white_out_amount *= pow(0.00001, delta)
	player_hand_offset.y -= min(abs(player_character_body.velocity.y) * 0.0004, 0.003) * sign(player_character_body.velocity.y)
	player_hand.position.x += player_hand_offset.x
	player_hand.position.y += player_hand_offset.y
	display_red_outline_amount = 1

func _ready() -> void:
	var display_material := display.material as ShaderMaterial

	display_material.set_shader_parameter(
		"world_view_texture",
		world_view.get_texture()
	)
	display_material.set_shader_parameter(
		"overlay_view_texture",
		overlay_view.get_texture()
	)
	display_material.set_shader_parameter(
		"display_white_out_amount",
		display_white_out_amount
	)
	display_material.set_shader_parameter(
		"display_red_outline_amount",
		display_red_outline_amount
	)
	display_material.set_shader_parameter(
		"display_speed_lines_amount",
		display_red_outline_amount
	)

	settup_main_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_position: Vector2 = event.position

		match game_mode:
			GameMode.MAIN_MENU:
				if Input.is_action_pressed("button_0"):
					if MAIN_MENU_BUTTON_START.has_point(mouse_position):
						game_mode = GameMode.MAIN_AREA
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					elif MAIN_MENU_BUTTON_QUIT.has_point(mouse_position):
						get_tree().quit()
			GameMode.PAUSE_MENU:
				if Input.is_action_pressed("button_0"):
					if PAUSE_MENU_BUTTON_RESUME.has_point(mouse_position):
						game_mode = paused_game_mode
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					elif PAUSE_MENU_BUTTON_MAIN_MENU.has_point(mouse_position):
						settup_main_menu()
			GameMode.GAME_OVER_MENU:
				if Input.is_action_pressed("button_0"):
					if GAME_OVER_MENU_BUTTON_RESTART.has_point(mouse_position):
						settup_respawn()
					elif GAME_OVER_MENU_BUTTON_MAIN_MENU.has_point(mouse_position):
						settup_main_menu()
			GameMode.ARENA_AREA:
					if Input.is_action_just_pressed("button_1"):
						player_input_shoot_1_buffer = 0.2
	elif event is InputEventKey:
		if game_mode == GameMode.MAIN_AREA or game_mode == GameMode.ARENA_AREA:
			if Input.is_action_just_pressed("escape"):
				paused_game_mode = game_mode
				game_mode = GameMode.PAUSE_MENU
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

			if player_input_enabled:
				if Input.is_action_just_pressed("jump"):
					player_input_jump_buffer = 0.15
	elif event is InputEventMouseMotion:
		if (game_mode == GameMode.MAIN_AREA or game_mode == GameMode.ARENA_AREA) and player_input_enabled:
			player_character_body.rotate_y(-event.relative.x * MOUSE_INPUT_SENSITIVITY)
			player_camera.rotation.x -= event.relative.y * MOUSE_INPUT_SENSITIVITY

			player_input_physics_frame_accumulated_mouse_movement_x += event.relative.x * MOUSE_INPUT_SENSITIVITY

			player_hand_offset.x -= min(abs(event.relative.x * MOUSE_INPUT_SENSITIVITY) * 0.05, 0.008) * sign(event.relative.x)

			if player_camera.rotation.x > HALF_PI:
				player_camera.rotation.x = HALF_PI
			elif player_camera.rotation.x < -HALF_PI:
				player_camera.rotation.x = -HALF_PI

func _process(delta: float) -> void:
	var display_material := display.material as ShaderMaterial

	display_material.set_shader_parameter(
		"display_white_out_amount",
		display_white_out_amount
	)
	display_material.set_shader_parameter(
		"display_red_outline_amount",
		display_red_outline_amount
	)
	display_material.set_shader_parameter(
		"display_speed_lines_amount",
		display_speed_lines_amount
	)

	display_red_outline_amount = max(display_red_outline_amount - 0.5 * delta, 0)
	display_speed_lines_amount = max(display_speed_lines_amount - 5 * delta, 0)

	overlay_camera.position.x = float(game_mode as int) * 512

func _physics_process(delta: float) -> void:
	match game_mode:
		GameMode.MAIN_AREA:
			process_player_main_area(delta)
		GameMode.ARENA_AREA:
			process_player_arena_area(delta)
		GameMode.GAME_OVER_MENU:
			process_player_game_over_screen(delta)
