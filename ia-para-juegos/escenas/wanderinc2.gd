extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES DINÁMICAS Y WANDER
# ----------------------------------------------------------------------

@export var max_acceleration: float = 50.0    # Aceleración lineal constante hacia adelante
@export var max_speed: float = 50.0          # Velocidad lineal máxima

@export var max_angular_acceleration: float = 2.0 # Aceleración angular máxima (fuerza de rotación aleatoria)
@export var max_rotation: float = 1.5            # Velocidad de rotación máxima (límite de giro)

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var current_rotation_speed: float = 0.0 
enum State { STOPPED, WANDERING } 
var current_state = State.STOPPED

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	randomize() 
	print("Dynamic Wander: STOPPED. Presiona 8 para activar.")

func _input(event):
	# tecla 8
	if event is InputEventKey and event.keycode == KEY_8 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.WANDERING
			print("Dynamic Wander activado.")
		else:
			current_state = State.STOPPED
			print("Dynamic Wander desactivado.")

# ----------------------------------------------------------------------
# LÓGICA DE WANDER Y AUXILIAR
# ----------------------------------------------------------------------

func random_binomial() -> float:
	return randf() - randf()

# Simula la función getSteering() dinámica (devuelve aceleraciones)
func get_dynamic_wander_steering() -> Dictionary:
	
	var linear_accel = Vector2.ZERO
	var angular_accel = 0.0
	
	# 1. Aceleración lineal: siempre adelante
	
	var direction_vector = Vector2.UP.rotated(rotation)
	linear_accel = direction_vector * max_acceleration
	
	# 2. Aceleración angular: rotación aleatoria suave (SteeringOutput.angular)
	angular_accel = random_binomial() * max_angular_acceleration

	return {"linear": linear_accel, "angular": angular_accel}

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	
	var steering_output = {"linear": Vector2.ZERO, "angular": 0.0}
	
	if current_state == State.WANDERING:
		steering_output = get_dynamic_wander_steering()
	else:
		# Frenar: aceleración opuesta a la velocidad lineal
		steering_output.linear = velocity.normalized() * -max_acceleration
		# Frenar la rotación: aceleración opuesta a la rotación actual
		steering_output.angular = -current_rotation_speed / 0.1 

	#  DINÁMICA 
	
	# 1. Integración de Velocidad Lineal
	var linear_acceleration = steering_output.linear
	if linear_acceleration.length_squared() > max_acceleration * max_acceleration:
		linear_acceleration = linear_acceleration.normalized() * max_acceleration
	
	velocity += linear_acceleration * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# 2. Integración de Rotación Angular
	var angular_acceleration = steering_output.angular
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
