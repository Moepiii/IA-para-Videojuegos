extends CharacterBody2D

@export var speed: float = 20.0
var path_follow: PathFollow2D

func _ready():

	start_following_path()

func start_following_path():
	
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

	
	var offset_cercano = ruta.curve.get_closest_offset(global_position)
	path_follow.progress = offset_cercano


func _physics_process(delta):

	if path_follow:
		path_follow.progress += speed * delta
		var target_pos = path_follow.global_position
		var direction = (target_pos - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
