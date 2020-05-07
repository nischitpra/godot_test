extends KinematicBody

const GRAVITY := -5
const JUMP_SPEED := 2
const SPEED := 1
const SPRINT_SPEED := 2
const ACCELERATION := 5
const DE_ACCELERATION := 10
const MOUSE_SENSITIVITY := 0.1

var move_direction := Vector3.ZERO
var input_direction := Vector3.ZERO
var velocity := Vector3.ZERO
var is_sprinting := false

onready var pivot := $pivot
onready var gun := $gun
onready var camera := $pivot/Camera
onready var animation_tree := $characterAnimations/AnimationTree

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	if event is InputEventMouseMotion:
		var rotationY = deg2rad(-event.relative.x*MOUSE_SENSITIVITY)
		var rotationX = deg2rad(event.relative.y*MOUSE_SENSITIVITY)
		rotate_y(rotationY)
		pivot.rotate_x(rotationX)
		gun.rotate_x(rotationX)
		var clampedRotationX =  clamp(pivot.rotation.x,deg2rad(-35),deg2rad(45))		
		pivot.rotation.x = clampedRotationX
		gun.rotation.x = clampedRotationX


func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)


func _process_input(_delta):
	_resetVariables()
	var camera_transform = camera.get_global_transform()
# player strafing
	if Input.is_action_pressed("move_fw"):
		input_direction.z += 1
	if Input.is_action_pressed("move_bw"):
		input_direction.z += -1
	if Input.is_action_pressed("move_l"):
		input_direction.x += -1
	if Input.is_action_pressed("move_r"):
		input_direction.x += 1
	input_direction = input_direction.normalized()
	move_direction += -camera_transform.basis.z*input_direction.z
	move_direction += camera_transform.basis.x*input_direction.x
	
# for springing
	is_sprinting = true if Input.is_action_pressed("move_sprint") else false 
	
# for jumping
#	if Input.is_action_just_pressed("move_j") and is_on_floor():
	if Input.is_action_just_pressed("move_j"):
		velocity.y = JUMP_SPEED
		animation_tree.set("parameters/jump_blend/active", 1.0)


func _process_movement(delta):
	velocity.y += delta * GRAVITY
	
	var speed = SPRINT_SPEED if is_sprinting else SPEED
	var new_pos = move_direction * speed
	var acc = DE_ACCELERATION
	var hv = velocity
	hv.y = 0
	# if movement is in the current velocity direction then accelerate
	if(move_direction.dot(hv)>0):
		acc = ACCELERATION
	
	hv = hv.linear_interpolate(new_pos, acc*delta)
	
	velocity.x = hv.x
	velocity.z = hv.z
	
	velocity = move_and_slide(velocity,Vector3.UP,true)
	
	var anim_blend_amount = velocity.length() / speed
	# play animation
	animation_tree.set("parameters/move_blend/blend_amount", anim_blend_amount)


func _resetVariables():
	input_direction.x=0
	input_direction.y=0
	input_direction.z=0
	move_direction.x = 0
	move_direction.y = 0
	move_direction.z = 0
