extends Node2D
@onready var npc_scene = preload("res://escenas/meteorito.tscn")
@onready var ruta = $Ruta


var npcs_creados = false


func _ready():
	pass

func _unhandled_input(event):

	if npcs_creados:
		return


	if event is InputEventKey and event.pressed and event.keycode == KEY_U:

		npcs_creados = true
		
	
		crear_npcs()


func crear_npcs():
	var forma = ruta.curve.get_baked_points()
	if not forma or forma.size() < 2:
		print("Error: La ruta no tiene puntos suficientes.")
		return

	var rect_limite = Rect2(forma[0], Vector2.ZERO)
	for punto in forma:
		rect_limite = rect_limite.expand(punto)

	var centro_figura = rect_limite.get_center()

	for i in range(5):
		var npc = npc_scene.instantiate()
		
		if i < 2:
			
			npc.global_position = centro_figura
			
			
			
			if i == 1:
				npc.global_position += Vector2(15, 15) 
			
		elif i < 3:
			
			var pos_x = randf_range(rect_limite.position.x, rect_limite.end.x)
			var pos_y = randf_range(rect_limite.position.y, rect_limite.end.y)
			npc.global_position = Vector2(pos_x, pos_y)
			
		else:
			var direccion_aleatoria = Vector2.RIGHT.rotated(randf() * TAU)
			var distancia_exterior = (rect_limite.size.x + rect_limite.size.y) / 2.5
			npc.global_position = centro_figura + direccion_aleatoria * distancia_exterior
			
		add_child(npc)

	print("¡5 NPCs creados!")

	print("¡NPCs creados! 2 en el centro, 1 dentro y 2 fuera.")
