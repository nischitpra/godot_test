extends KinematicBody

const CROUCH_INTERPOLATE_SPEED = 5
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10
const JUMP_SPEED = 5

const CAMERA_MOUSE_ROTATION_SPEED = 0.001
const CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
const CAMERA_X_ROT_MIN = -40
const CAMERA_X_ROT_MAX = 30

onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")
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


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	# movement
	var crouch = Input.get_action_strength("move_crouch")
	var sprint = Input.get_action_strength("move_sprint")
	var motion_target = Vector2(Input.get_action_strength("move_r") - Input.get_action_strength("move_l"), 
								Input.get_action_strength("move_bw") - Input.get_action_strength("move_fw"))
	motion_target.x += motion_target.x*sprint
	motion_target.y += motion_target.y*sprint
	motion = motion.linear_interpolate(motion_target, MOTION_INTERPOLATE_SPEED * delta)
	var camera_x = camera_rot.global_transform.basis.x
	var camera_z = camera_rot.global_transform.basis.z
	var target = camera_x * motion.x + camera_z * motion.y
	if target.length() > 0.001:
		var q_from = orientation.basis.get_rotation_quat()
		var q_to = Transform().looking_at(target, Vector3.UP).basis.get_rotation_quat()
#       Interpolate current rotation with desired one.
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
	
	# crouch
	var motion_length = motion.length()/2
	animation_tree.set("parameters/stand_crouch_blend/blend_amount", crouch_motion)
	if crouch:
		crouch_motion+=CROUCH_INTERPOLATE_SPEED*delta
		animation_tree.set("parameters/crouch_move_blend/blend_position", motion_length)
	else:
		# apply movement blend
		crouch_motion-=CROUCH_INTERPOLATE_SPEED*delta
		animation_tree.set("parameters/move_blend/blend_position", motion_length)
	crouch_motion = clamp(crouch_motion,0,1)
	# jump
	if is_on_floor() and Input.is_action_just_pressed("move_j"):
		velocity.y = JUMP_SPEED
		var is_wall_infront = front_ray_cast.is_colliding()
		print(is_wall_infront)
		# select jump animation
		animation_tree.set("parameters/jump_selector/blend_position", is_wall_infront)
		# play jump animation
		animation_tree.set("parameters/jump_blend/active", 1.0)
	
	if not is_on_floor() and ledge_ray_cast.is_colliding():
		is_hanging = true
	else:
		is_hanging = false
		
	print(is_hanging)
	
	# process movement
	root_motion = animation_tree.get_root_motion_transform()
	orientation *= root_motion
	
	var h_velocity = orientation.origin / delta
	#todo: need to optimize this
	if !is_hanging:
		velocity.x = h_velocity.x
		velocity.z = h_velocity.z
		velocity += gravity * delta
		velocity = move_and_slide(velocity, Vector3.UP)
	
#	make player rotate to moving direction	
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
