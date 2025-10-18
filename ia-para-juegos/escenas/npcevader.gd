extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES GENERALES
# ----------------------------------------------------------------------
@export var max_acceleration: float = 100.0
@export var max_speed: float = 250.0

# ----------------------------------------------------------------------
# PROPIEDADES DE EVADE Y AVOIDANCE (AJUSTADAS)
# ----------------------------------------------------------------------
@export_group("Comportamiento")
@export var max_prediction: float = 1.0       # Max tiempo para predecir 
@export var avoid_distance: float = 40.0      # Distancia para evadir pared
@export var lookahead_distance: float = 100.0 # AUMENTADO para detección más rápida
@export var raycast_node_path: NodePath       # Path al nodo RayCast2D hijo

# ----------------------------------------------------------------------
# PROPIEDADES DE LOOK WHERE YOU'RE GOING 
# ----------------------------------------------------------------------
@export_group("Angular Properties")
@export var max_angular_acceleration: float = 5.0
@export var max_rotation: float = 3.0             
@export var target_radius: float = 0.005          
@export var slow_radius: float = 0.5              
@export var time_to_target: float = 0.1           

# ----------------------------------------------------------------------
# VARIABLES INTERNAS
# ----------------------------------------------------------------------
var target_pursuer: CharacterBody2D = null # El objetivo del cual huir
var raycast: RayCast2D = null
var current_rotation_speed: float = 0.0
var is_active: bool = false # Variable de estado

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var pursuers = get_tree().get_nodes_in_group("pursuer")
	if pursuers.size() > 0:
		target_pursuer = pursuers[0]
		print(" Evadidor listo. Huyendo de: Pursuer.")
	else:
		print(" ERROR: El objetivo Pursuer no tiene la etiqueta 'pursuer'.")
		
	raycast = get_node_or_null(raycast_node_path)
	if not raycast:
		print(" ERROR: RayCast2D no encontrado. ¡Asigna el Path correctamente!")
	
	print("Evadidor: Esperando tecla R para activar/desactivar la evasión.")

func _input(event):
	if event is InputEventKey and event.keycode == KEY_R and event.is_pressed():
		is_active = !is_active
		if is_active:
			print("Evadidor activado (Huyendo de Pursuer).")
		else:
			print("Evadidor desactivado.")

# ----------------------------------------------------------------------
# FUNCIONES DE ALGORITMOS
# ----------------------------------------------------------------------

func get_seek_steering(target_position: Vector2) -> Vector2:
	var direction = target_position - global_position
	if direction.length_squared() == 0.0: return Vector2.ZERO
	return direction.normalized() * max_acceleration

func get_evade_steering(target: CharacterBody2D) -> Vector2:
	var direction = target.global_position - global_position
	var distance = direction.length()
	
	var speed = velocity.length()
	var prediction_time = max_prediction
	if speed > 0:
		prediction_time = min(max_prediction, distance / speed)
		
	var target_position = target.global_position + target.velocity * prediction_time
	var evade_direction = global_position - target_position
	
	if evade_direction.length_squared() == 0.0: return Vector2.ZERO
	
	return evade_direction.normalized() * max_acceleration

func get_avoidance_steering() -> Vector2:
	if not raycast or not raycast.is_colliding():
		return Vector2.ZERO

	var collision_point = raycast.get_collision_point()
	var collision_normal = raycast.get_collision_normal()
	
	var avoidance_target = collision_point + collision_normal * avoid_distance
	
	var linear_acceleration = get_seek_steering(avoidance_target)
	
	var braking_force = -velocity.normalized() * max_acceleration * 0.8
	
	return (linear_acceleration + braking_force).limit_length(max_acceleration)

func map_to_range(angle: float) -> float:
	return fposmod(angle + PI, 2 * PI) - PI

func get_look_where_youre_going_steering() -> float:
	var current_velocity = velocity
	if current_velocity.length_squared() < 1: 
		current_rotation_speed = 0.0 
		return 0.0

	var target_orientation_raw = current_velocity.angle()
	var target_orientation_compensated = target_orientation_raw + PI/2 
	
	var rotation_difference = map_to_range(target_orientation_compensated - rotation)
	
	if abs(rotation_difference) < target_radius: 
		current_rotation_speed = 0.0 
		return 0.0

	var target_rotation: float
	if abs(rotation_difference) > slow_radius:
		target_rotation = max_rotation 
	else:
		target_rotation = max_rotation * abs(rotation_difference) / slow_radius

	target_rotation *= rotation_difference / abs(rotation_difference)
	
	var angular_acceleration = target_rotation - current_rotation_speed
	angular_acceleration /= time_to_target
	
	if abs(angular_acceleration) > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration

	return angular_acceleration

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL (PRIORIDAD JERÁRQUICA)
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_active or not is_instance_valid(target_pursuer) or not raycast: 
		velocity = velocity.move_toward(Vector2.ZERO, max_acceleration * delta)
		move_and_slide()
		return
	
	# 1. Calcular la dirección de sondeo )
	var ray_direction = velocity.normalized()
	
	# Si está quieto, usamos la dirección frontal del NPC (rotación) como valor por defecto.
	if velocity.length_squared() < 1.0:
		ray_direction = Vector2.UP.rotated(rotation)
	
	# 2. Actualizar RayCast para apuntar en la dirección de la TRAYECTORIA REAL
	raycast.target_position = ray_direction * lookahead_distance

	var linear_acceleration = Vector2.ZERO
	
	# --- PRIORIDAD 1: OBSTACLE AVOIDANCE (PAREDES) ---
	linear_acceleration = get_avoidance_steering()
	
	if linear_acceleration == Vector2.ZERO:
		# --- PRIORIDAD 2: EVADE (OBJETIVO) ---
		linear_acceleration = get_evade_steering(target_pursuer)

	# --- INTEGRACIÓN DINÁMICA ---
	
	var final_linear_accel = linear_acceleration.limit_length(max_acceleration)
	velocity += final_linear_accel * delta
	velocity = velocity.limit_length(max_speed)
	
	var angular_acceleration = get_look_where_youre_going_steering()
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
