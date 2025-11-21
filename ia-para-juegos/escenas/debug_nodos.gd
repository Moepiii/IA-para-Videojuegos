extends Node2D

# Escribe aquí el nombre EXACTO de tu nodo de navegación
@onready var region_navegacion = $"../RegionNavegacion"


func _draw():
	# 1. Revisa si encontramos la región de navegación
	if not region_navegacion:
		print("DebugNodos: ¡No se encontró el nodo 'RegionNavegacion'!")
		return
	
	# 2. Revisa si esa región tiene un polígono
	var nav_poly = region_navegacion.navpoly
	if not nav_poly:
		print("DebugNodos: La región no tiene un 'navpoly'.")
		return

	# --- SECCIÓN CORREGIDA ---
	
	# 3. Obtenemos los vértices (puntos)
	var vertices = nav_poly.get_vertices()
	# 4. Obtenemos la CANTIDAD de triángulos
	var polygon_count = nav_poly.get_polygon_count()
	
	# 5. Revisamos si están vacíos
	if vertices.is_empty() or polygon_count == 0:
		print("DebugNodos: ¡El polígono está VACÍO! Asegúrate de presionar 'Procesar'.")
		return

	# 6. Si todo está bien, dibujamos los triángulos
	var color = Color.YELLOW # Un color brillante
	
	# Iteramos por cada triángulo, uno por uno
	for i in range(polygon_count):
		# Obtenemos los 3 índices del triángulo actual (ej. [0, 1, 2])
		var polygon_indices = nav_poly.get_polygon(i)
		
		# Obtenemos las posiciones 2D de los 3 puntos del triángulo
		var p1 = vertices[polygon_indices[0]]
		var p2 = vertices[polygon_indices[1]]
		var p3 = vertices[polygon_indices[2]]
		
		# Dibujamos las 3 líneas que forman el triángulo
		draw_line(p1, p2, color)
		draw_line(p2, p3, color)
		draw_line(p3, p1, color)
