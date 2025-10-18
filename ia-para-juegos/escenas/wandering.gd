extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES CINEMÁTICAS Y WANDER
# ----------------------------------------------------------------------

@export var max_speed: float = 30.0          # Velocidad lineal constante
@export var max_rotation: float = 3        # Máxima velocidad de rotación (rad/s)
@export var time_to_target: float = 0.1       # Para frenar cuando está STOPPED

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
	# Inicializar el generador de números aleatorios para randomBinomial()
	randomize() 
	print("Kinematic Wander: STOPPED. Presiona 7 para activar.")

func _input(event):
	#  tecla 4
	if event is InputEventKey and event.keycode == KEY_7 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.WANDERING
			print("Kinematic Wander activado.")
		else:
			current_state = State.STOPPED
			print("Kinematic Wander desactivado.")

# ----------------------------------------------------------------------
# LÓGICA DE WANDER Y AUXILIAR
# ----------------------------------------------------------------------

# Implementación de randomBinomial: random() - random()
func random_binomial() -> float:
	return randf() - randf()

# Simula la función getSteering() de KinematicWander
func get_kinematic_wander_output():
	
	# 1. Obtener la velocidad desde la orientación (El personaje va hacia donde mira)

	
	# Obtenemos la orientación de movimiento 
	var direction_vector = Vector2.UP.rotated(rotation)

	# El resultado de la velocidad es a máxima velocidad en la dirección actual
	velocity = direction_vector * max_speed

	# 2. Cambiar nuestra orientación aleatoriamente (modifica la rotación del Kinematic)
	current_rotation_speed = random_binomial() * max_rotation

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	
	if current_state == State.WANDERING:
		# Aplicar la lógica de Wander, que establece velocity y current_rotation_speed
		get_kinematic_wander_output()
		
		# Integrar la rotación
		rotation += current_rotation_speed * delta
		
	else:
		# STOPPED: Frenar suavemente
		var deceleration_rate = max_speed / time_to_target 
		velocity = velocity.move_toward(Vector2.ZERO, deceleration_rate * delta)
		
		# Frenar la rotación para que no siga girando si está parado
		current_rotation_speed = 0.0

	move_and_slide()
