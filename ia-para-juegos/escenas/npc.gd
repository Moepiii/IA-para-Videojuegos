extends CharacterBody2D

const SPEED = 100.0

# Variable para guardar el objetivo
var mi_objetivo: Vector2 = Vector2.ZERO

# Nos aseguramos de que la posición inicial sea nuestro "objetivo"
# para que no se mueva solo.
func _ready():
	mi_objetivo = global_position

# Esta es la NUEVA función de movimiento
func test_mover_a(punto_objetivo: Vector2):
	print("¡TEST! Recibida orden a: ", punto_objetivo)
	mi_objetivo = punto_objetivo

# Bucle de física
func _physics_process(_delta):
	
	# Si estamos a menos de 5 píxeles, nos detenemos.
	if global_position.distance_to(mi_objetivo) < 5.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Si no, calculamos la dirección y nos movemos
	var direccion = global_position.direction_to(mi_objetivo)
	velocity = direccion * SPEED
	move_and_slide()
