# path_following_system.gd
extends Node2D

@export var npc_scene: PackedScene
@export var npc_count: int = 5

@export_group("Path Shape")
@export var path_size: float = 400.0
@export var path_center: Vector2 = Vector2(576, 324)

# Un nodo para mantener ordenados los NPCs
@onready var npc_container: Node2D = Node2D.new()
@onready var path_node: Path2D = $Path2D
@onready var line_node: Line2D = $Line2D


func _ready():
	add_child(npc_container) # Añadimos el contenedor a la escena
	randomize()
	_generate_square_path()
	_draw_path()
	_spawn_npcs()

# La función _process ya no es necesaria aquí

func _generate_square_path():
	var curve = Curve2D.new()
	var half_size = path_size / 2.0
	
	var top_left = path_center + Vector2(-half_size, -half_size)
	var top_right = path_center + Vector2(half_size, -half_size)
	var bottom_right = path_center + Vector2(half_size, half_size)
	var bottom_left = path_center + Vector2(-half_size, half_size)
	
	curve.add_point(top_left)
	curve.add_point(top_right)
	curve.add_point(bottom_right)
	curve.add_point(bottom_left)
	curve.add_point(top_left)
	
	path_node.curve = curve

func _draw_path():
	line_node.points = path_node.curve.get_baked_points()
	line_node.width = 4.0
	line_node.default_color = Color.CYAN
	line_node.antialiased = true

func _spawn_npcs():
	var spawn_radius = path_size / 2.0
	
	for i in range(npc_count):
		var npc_instance = npc_scene.instantiate()
		
		var spawn_inside = randf() > 0.5
		var random_distance
		if spawn_inside:
			random_distance = randf_range(50.0, spawn_radius * 0.8)
		else:
			random_distance = randf_range(spawn_radius * 1.5, spawn_radius * 2.5)
		
		var random_angle = randf() * TAU
		var spawn_position = path_center + Vector2.RIGHT.rotated(random_angle) * random_distance
		
		npc_instance.global_position = spawn_position
		
		# --- LÍNEA CLAVE ---
		# Le pasamos la información de la ruta al NPC
		npc_instance.set_path_node(path_node)
		
		npc_container.add_child(npc_instance)
