extends Node2D
@onready var npc_scene = preload("res://escenas/meteorito.tscn")
@onready var ruta = $Ruta

# Nueva variable para asegurarnos de que solo se pueda activar una vez.
var npcs_creados = false

# La función _ready ahora está vacía, porque no queremos que pase nada al empezar.
func _ready():
	pass

# Esta función se llama automáticamente cada vez que se detecta una entrada (teclado, ratón, etc.).
func _unhandled_input(event):
	# 1. Si los NPCs ya fueron creados, salimos de la función para no hacer nada más.
	if npcs_creados:
		return

	# 2. Comprobamos si el evento es una tecla que se ha PRESIONADO y si esa tecla es la 'U'.
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		# 3. Marcamos la variable como 'true' para que no se pueda volver a activar.
		npcs_creados = true
		
		# 4. Llamamos a la función que contiene toda la lógica de creación.
		crear_npcs()

# Hemos movido todo el código que antes estaba en _ready() a esta nueva función.
# Esta es la única función que necesitas cambiar.
# Reemplaza esta función en tu script principal.
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
			# --- APARECER EN EL CENTRO (Los primeros 2 NPCs) ---
			npc.global_position = centro_figura
			
			# === INICIO DE LA CORRECCIÓN ===
			# Si es el segundo NPC del centro (i=1), lo movemos un poquito.
			if i == 1:
				npc.global_position += Vector2(15, 15) # Un pequeño desplazamiento
			# === FIN DE LA CORRECCIÓN ===
			
		elif i < 3:
			# --- APARECER DENTRO (El 3er NPC) ---
			var pos_x = randf_range(rect_limite.position.x, rect_limite.end.x)
			var pos_y = randf_range(rect_limite.position.y, rect_limite.end.y)
			npc.global_position = Vector2(pos_x, pos_y)
			
		else:
			# --- APARECER FUERA (Los últimos 2 NPCs) ---
			var direccion_aleatoria = Vector2.RIGHT.rotated(randf() * TAU)
			var distancia_exterior = (rect_limite.size.x + rect_limite.size.y) / 2.5
			npc.global_position = centro_figura + direccion_aleatoria * distancia_exterior
			
		add_child(npc)

	print("¡5 NPCs creados!")

	print("¡NPCs creados! 2 en el centro, 1 dentro y 2 fuera.")
