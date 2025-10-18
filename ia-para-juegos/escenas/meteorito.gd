extends CharacterBody2D

@export var speed: float = 20.0
var path_follow: PathFollow2D

func _ready():
	# Esta función ahora es igual para todos los NPCs.
	# Su única misión es encontrar la ruta y empezar a seguirla.
	start_following_path()

func start_following_path():
	# Evita errores si ya está siguiendo la ruta.
	if path_follow: return

	# Busca el nodo de la ruta en la escena.
	var ruta = get_parent().get_node_or_null("Ruta")
	if not ruta:
		print("Error: No se encontró el nodo 'Ruta'.")
		return

	# Prepara el PathFollow2D para este NPC.
	var plantilla = ruta.get_node("Seguidor")
	path_follow = plantilla.duplicate()
	ruta.add_child(path_follow)

	# --- LÓGICA CLAVE ---
	# En lugar de un punto aleatorio, le decimos que empiece en el
	# punto de la curva más cercano a la posición actual del NPC.
	# 'curve.get_closest_offset()' nos da la distancia a lo largo de la curva.
	var offset_cercano = ruta.curve.get_closest_offset(global_position)
	path_follow.progress = offset_cercano
	# --- FIN LÓGICA CLAVE ---

func _physics_process(delta):
	# Esta parte no cambia. Si tiene una ruta, la sigue.
	if path_follow:
		path_follow.progress += speed * delta
		var target_pos = path_follow.global_position
		var direction = (target_pos - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
