@tool
extends Node

# --- INSTRUCCIONES ---
# 1. Adjunta este script a cualquier nodo en tu escena (ej. un Node2D).
# 2. En el Inspector, arrastra tu nodo TileMap ("Adelante") al campo "Tile Map Node".
# 3. Marca la casilla "Run Script" para ejecutar la lógica.
# 4. Revisa tu TileSet: las baldosas de suelo ahora deberían tener navegación.
# 5. Puedes borrar este nodo, el TileSet ya ha sido modificado.
# ---------------------

@export var tile_map_node: TileMap

@export var run_script: bool = false:
	set(value):
		if value == true:
			_generar_navegacion()
			run_script = false # Resetea el botón



# Variable para el toggle de regiones
@export var region_representation_node : Node2D

# Variables para el control del NPC
@onready var npc = $NPC

#
# --- ¡CAMBIO CRÍTICO! ---
# Ya no buscamos "NavigationRegion2D".
# Buscamos tu TileMap "Adelante" (que está dentro de "TileMapLayer")
#
@onready var tile_map_adelante = $TileMapLayer/Adelante


# Esta función se llama para cada entrada (mouse, teclado)
func _unhandled_input(event):
	
	# 1. Lógica para el Toggle de Visibilidad (tu código original)
	if event.is_action_pressed("ui_accept"): 
		if region_representation_node:
			region_representation_node.visible = not region_representation_node.visible

	# 2. Lógica para Mover el NPC con Clic
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			
			# ¡CAMBIO! Comprobamos si tenemos el NPC y el TILEMAP
			if npc and tile_map_adelante:
				
				# ¡CAMBIO! Obtenemos el "mapa" de navegación DESDE el TileMap.
				# (Usamos 0 porque generador_nav.gd usa la capa 0)
				var nav_map = tile_map_adelante.get_navigation_map(0)
				
				# Obtiene la posición del clic
				var click_pos = event.global_position
				
				# Pide al servidor de navegación el punto VÁLIDO más cercano
				var punto_valido = NavigationServer2D.map_get_closest_point(nav_map, click_pos)
				
				# Le da al NPC un objetivo que SÍ existe en la malla
				npc.mover_a(punto_valido)

func _generar_navegacion():
	if not tile_map_node:
		print("ERROR: No se ha asignado un nodo TileMap.")
		return
		
	var tile_set: TileSet = tile_map_node.tile_set
	if not tile_set:
		print("ERROR: El nodo TileMap no tiene un TileSet.")
		return

	print("Iniciando generación de navegación para el TileSet...")

	# --- 1. Definir el polígono de navegación (un cuadrado completo) ---
	# Usamos el tamaño del tile para hacer un cuadrado perfecto
	var tile_size = tile_set.tile_size
	var half_size = tile_size / 2.0
	
	var floor_polygon = PackedVector2Array([
		half_size * Vector2(-1, -1), # Esquina superior izquierda
		half_size * Vector2(1, -1),  # Esquina superior derecha
		half_size * Vector2(1, 1),   # Esquina inferior derecha
		half_size * Vector2(-1, 1)   # Esquina inferior izquierda
	])

	# --- 2. Crear la capa de navegación en el TileSet (si no existe) ---
	var nav_layer_id = 0 # Usaremos la capa 0
	if not tile_set.has_navigation_layer(nav_layer_id):
		tile_set.add_navigation_layer(nav_layer_id)
		print("Capa de navegación 0 creada.")
	
	# Habilitamos la capa
	tile_set.set_navigation_layer_enabled(nav_layer_id, true)
	print("Capa de navegación 0 habilitada.")

	# --- 3. Revisar cada baldosa (tile) en la paleta (TileSet) ---
	var modified_count = 0
	for i in tile_set.get_source_count():
		var source: TileSetSource = tile_set.get_source(i)
		
		# Solo nos interesan las "paletas" de atlas (imágenes)
		if source is TileSetAtlasSource:
			var atlas_source: TileSetAtlasSource = source
			
			# Iteramos sobre cada tile en esta paleta
			#
			# --- LÍNEA CORREGIDA ---
			# Usamos get_tiles_ids() (que devuelve Coordenadas Vector2i)
			# en lugar de get_tiles_count() (que devolvía un int)
			#
			for tile_coords in atlas_source.get_tiles_ids():
				# Obtenemos los datos de esta baldosa específica
				#
				# --- LÍNEA CORREGIDA ---
				# Pasamos explícitamente el segundo argumento "0" 
				# (para "alternative_tile")
				#
				var tile_data: TileData = atlas_source.get_tile_data(tile_coords, 0)
				
				# Contamos cuántas capas de física tiene
				var physics_layers_count = tile_data.get_physics_layer_count()
				
				if physics_layers_count > 0:
					# Es una PARED (tiene física)
					# Nos aseguramos de que NO tenga navegación
					if tile_data.get_navigation_polygon(nav_layer_id) != null:
						tile_data.set_navigation_polygon(nav_layer_id, null)
						modified_count += 1
						
				else:
					# Es SUELO (no tiene física)
					# Nos aseguramos de que SÍ tenga navegación
					if tile_data.get_navigation_polygon(nav_layer_id) == null:
						tile_data.set_navigation_polygon(nav_layer_id, floor_polygon)
						modified_count += 1

	print("¡Proceso completado! %s baldosas fueron modificadas." % modified_count)
	print("Por favor, guarda tu escena (Ctrl+S) para guardar los cambios en el TileSet.")
