extends CharacterBody2D

@export var speed = 800
@export var acceleration = 1800
@export var rotation_speed = 5.0 # Velocidad de rotación para control manual (radianes)

# --- Parámetros del Wandering ---
@export var max_wander_speed = 300.0   # Velocidad de movimiento al deambular
@export var max_wander_rotation = 2.1 # Rotación máxima aleatoria (en radianes por frame)

var target_direction = Vector2.ZERO
var is_wandering = false # Estado para activar/desactivar el deambular

func _ready():
	# Inicializa el generador de números aleatorios
	randomize()
	

# -------------------------------------------------------------------
## Implementación de randomBinomial()
# -------------------------------------------------------------------

# Retorna un número aleatorio entre -1 y 1. Es más probable que el valor
# esté cerca de 0, lo que reduce la probabilidad de cambios bruscos de dirección.
func random_binomial() -> float:
	return randf() - randf()

# -------------------------------------------------------------------

func _physics_process(delta):
	# --- 1. Manejo del Estado (Wandering) ---
	if Input.is_action_just_pressed("ui_acceptt"): 
		is_wandering = !is_wandering # Alternar el estado
		if is_wandering:
			print("Wandering activado!")
		else:
			print("Wandering desactivado. Volviendo a control manual.")
	
	# --- 2. Ejecutar el Comportamiento ---
	if is_wandering:
		wandering_process(delta)
	else:
		manual_control_process(delta)
	
	# --- 3. Aplicar Movimiento ---
	move_and_slide()

# -------------------------------------------------------------------
## Algoritmo Wandering (Deambulación)
# -------------------------------------------------------------------

func wandering_process(delta):
	
	# 1. Aplicar Rotación Aleatoria (usando random_binomial)
	var wander_factor = random_binomial()
	var wander_rotation = wander_factor * max_wander_rotation * delta
	
	# Aplicamos el cambio de rotación al ángulo actual
	rotation += wander_rotation
	
	# 2. Calcular y Aplicar Velocidad
	
	# Vector2.from_angle(rotation) obtiene la dirección en Godot (derecha en 0 grados).
	# Usamos '- deg_to_rad(90)' si tu sprite apunta hacia arriba (Vector2(0, -1)) en rotación 0
	# y quieres que avance en esa dirección, corrigiendo la rotación base de Godot.
	var current_direction = Vector2.from_angle(rotation - deg_to_rad(90))
	
	var target_velocity = current_direction * max_wander_speed

	# Suaviza la transición de velocidad
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

# -------------------------------------------------------------------
## Control Manual
# -------------------------------------------------------------------

func manual_control_process(delta):
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		target_direction = input_dir
	else:
		target_direction = Vector2.ZERO

	if target_direction != Vector2.ZERO:
		# Rotación (Aseguramos que la rotación manual también apunte correctamente)
		# Multiplicar por -1 y restar 90 grados es común si el sprite apunta hacia arriba.
		var target_angle = (target_direction * -1).angle() - deg_to_rad(90)
		rotation = lerp_angle(rotation, target_angle, rotation_speed * delta)

		# Movimiento
		velocity = velocity.move_toward(target_direction * speed, acceleration * delta)
	else:
		# Freno/Desaceleración
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
