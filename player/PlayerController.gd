extends KinematicBody

const SPRINT_INTERPOLATE_SPEED_MULTIPLIER= 1.8
const HANG_INTERPOLATE_SPEED = 10
const CROUCH_INTERPOLATE_SPEED = 5
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10
const JUMP_SPEED = 5

const CAMERA_MOUSE_ROTATION_SPEED = 0.001
const CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
const CAMERA_X_ROT_MIN = -40
const CAMERA_X_ROT_MAX = 30

onready var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")
onready var animation_tree = $"Character Model/RootMotionPlayerTry5/AnimationTree"
onready var camera_base := $CameraBase
onready var camera_rot := $CameraBase/CameraRot
onready var camera := $CameraBase/CameraRot/SpringArm/Camera
onready var character_model := $"Character Model"
onready var front_ray_cast := $"Character Model/FrontRayCast"
onready var ledge_ray_cast := $"Character Model/LedgeRayCast"

var camera_x_rot := 0.0
var aiming := false

var orientation = Transform()
var root_motion = Transform()
var velocity = Vector3()
var motion = Vector2()
var crouch_motion := 0.0 
var is_hanging := false


#temp variables that needs 
var move_blend_vec = Vector2() # -1 crouch, 0 stand 1 hang
var target_move_blend := Vector2.ZERO
var h_velocity = Vector3.ZERO


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	process_input(delta)
	_reset_variables()


func process_input(delta):
	var gravity = GRAVITY
	
	# player rotation with camera
	var camera_x = camera_rot.global_transform.basis.x
	var camera_z = camera_rot.global_transform.basis.z
	var target = camera_x * motion.x + camera_z * motion.y
	if target.length() > 0.001:
		var q_from = orientation.basis.get_rotation_quat()
		var q_to = Transform().looking_at(target, Vector3.UP).basis.get_rotation_quat()
	# Interpolate current rotation with desired one.
		if is_on_floor():
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

	# get inputs
	var motion_target = Vector2(
		Input.get_action_strength("move_r") - Input.get_action_strength("move_l"), 
		Input.get_action_strength("move_bw") - Input.get_action_strength("move_fw")
	)
	var crouch = Input.get_action_strength("move_crouch")
	var sprint = Input.get_action_strength("move_sprint")
	
	if not is_on_floor() and ledge_ray_cast.is_colliding():
		is_hanging = true
		gravity *= 0 
	# jump
	if is_on_floor() and Input.is_action_just_pressed("move_j"):
		velocity.y = JUMP_SPEED
		# select jump animation
		animation_tree.set(
			"parameters/jump_selector/blend_position", 
			front_ray_cast.is_colliding()
		)
		# play jump animation
		animation_tree.set("parameters/jump_blend/active", 1.0)
	
	# play movement animations
	# choose move_multiplex
	var interpolate_speed = MOTION_INTERPOLATE_SPEED
	if crouch:
		interpolate_speed = CROUCH_INTERPOLATE_SPEED
		target_move_blend.x = -1.0
	elif is_hanging:
		interpolate_speed = HANG_INTERPOLATE_SPEED
		target_move_blend.x = 1.0
		if motion.y > 0.5: # is behind by one frame
			is_hanging = false
	else: # if standing
		interpolate_speed = MOTION_INTERPOLATE_SPEED
		target_move_blend.x = 0.0
	
	if sprint:
		interpolate_speed *= SPRINT_INTERPOLATE_SPEED_MULTIPLIER
	
	move_blend_vec = move_blend_vec.linear_interpolate(
		target_move_blend, interpolate_speed * delta
	) 
	animation_tree.set("parameters/move_multiplex/blend_amount", move_blend_vec.x)
	
	# if sprint is pressed, motion_target (-2,2) else (-1,1)
	motion_target += motion_target * sprint
	motion = motion.linear_interpolate(motion_target, interpolate_speed * delta)
	
	# blend move
	var motion_length = motion.length() / 2
	animation_tree.set("parameters/move_crouch/blend_position", motion_length)
	animation_tree.set("parameters/move_normal/blend_position", motion_length)
	animation_tree.set_indexed("parameters/move_hanging/blend_position", motion)
	
	# todo:
	# - create 2 more raycast to help move left or right while hanging.
	# - use ik bones animation for wall climbing. get the coords on collision position
	# - this is going to take a very very long time. 
#	So instead, start with kidnapping and stealth kill and shooting
	# process movement
	root_motion = animation_tree.get_root_motion_transform()
	orientation *= root_motion
	h_velocity = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	
	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.
	character_model.global_transform.basis.x = orientation.basis.x
	character_model.global_transform.basis.z = orientation.basis.z


func _input(event):
	if event is InputEventMouseMotion:
		var camera_frame_speed = CAMERA_MOUSE_ROTATION_SPEED
		if aiming:
			camera_frame_speed *= 0.75
		_rotate_camera(event.relative * camera_frame_speed)


func _rotate_camera(move):
	camera_base.rotate_y(-move.x)
	camera_base.orthonormalize()
	camera_x_rot += move.y
	camera_x_rot = clamp(camera_x_rot, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX))
	camera_rot.rotation.x = camera_x_rot


func _reset_variables():
	target_move_blend.x = 0
	target_move_blend.y = 0
	
