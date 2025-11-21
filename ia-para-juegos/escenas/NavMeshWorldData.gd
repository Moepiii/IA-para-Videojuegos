extends Node
class_name NavMeshWorldData

# --- REFERENCIA ---
# Arrastra tu NavigationRegion2D aquí en el Inspector
@export var navigation_region: NavigationRegion2D

# --- TUS DATOS DE MUNDO (Separados por capas para la entrega) ---
var capa_suelo: PackedVector2Array         # El borde exterior
var capa_obstaculos: Array[PackedVector2Array] = [] # Los agujeros (paredes)

func _ready():
	# Esperamos un frame para asegurar que el mapa esté listo
	await get_tree().process_frame
	leer_mapa_manual()

func leer_mapa_manual():
	capa_obstaculos.clear()
	
	# Obtenemos el dibujo que hiciste a mano
	var nav_poly = navigation_region.navigation_polygon
	
	if nav_poly == null:
		print("Error: No hay dibujo de navegación.")
		return

	# En Godot, el dibujo se guarda como una lista de contornos (Outlines).
	# El dibujo más grande siempre es el suelo (Outer Boundary).
	# Los dibujos de adentro son los agujeros (Obstáculos).
	
	var cantidad_contornos = nav_poly.get_outline_count()
	
	if cantidad_contornos > 0:
		# 1. CAPA SUELO: Siempre es el contorno 0 (el contorno exterior)
		capa_suelo = nav_poly.get_outline(0)
		
		# 2. CAPA OBSTÁCULOS: Son todos los demás (los agujeros)
		for i in range(1, cantidad_contornos):
			var obstaculo = nav_poly.get_outline(i)
			capa_obstaculos.append(obstaculo)
			
	print("--- WORLD REPRESENTATION GENERADA ---")
	print("Datos de Suelo (Vértices): ", capa_suelo.size())
	print("Datos de Obstáculos (Cantidad de paredes): ", capa_obstaculos.size())

# Función extra: Para que los NPCs sepan si chocan sin usar físicas
# (Esto demuestra uso de la representación)
func es_pared(punto: Vector2) -> bool:
	# Primero revisamos si estamos dentro de algún obstáculo (agujero)
	for obstaculo in capa_obstaculos:
		if Geometry2D.is_point_in_polygon(punto, obstaculo):
			return true
	
	# Opcional: Revisar si estamos FUERA del suelo
	if not Geometry2D.is_point_in_polygon(punto, capa_suelo):
		return true # Estar fuera del mapa cuenta como pared
		
	return false
