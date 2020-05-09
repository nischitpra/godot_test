extends KinematicBody

const MOTION_INTERPOLATE_SPEED = 10
const JUMP_SPEED = 6

const CAMERA_MOUSE_ROTATION_SPEED = 0.001
const CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
const CAMERA_X_ROT_MIN = -40
const CAMERA_X_ROT_MAX = 30

onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")
onready var animation_tree = $"Character Model/Player Model/AnimationTree"
onready var camera_base := $CameraBase
onready var camera_rot := $CameraBase/CameraRot
onready var camera := $CameraBase/CameraRot/SpringArm/Camera
onready var character_model := $"Character Model"

var camera_x_rot := 0.0
var aiming := false

var orientation = Transform()
var root_motion = Transform()
var velocity = Vector3()
var motion = Vector2()


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	var motion_target = Vector2(Input.get_action_strength("move_r") - Input.get_action_strength("move_l"), 
								Input.get_action_strength("move_bw") - Input.get_action_strength("move_fw"))
	motion = motion.linear_interpolate(motion_target, MOTION_INTERPOLATE_SPEED * delta)
	
	# jump
	if is_on_floor() and Input.is_action_just_pressed("move_j"):
		velocity.y = JUMP_SPEED
		animation_tree.set("parameters/jump_blend/active", 1.0)
	
	root_motion = animation_tree.get_root_motion_transform()
	orientation *= root_motion
	
	var h_velocity = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	
	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.
	
	character_model.global_transform.basis = orientation.basis


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
