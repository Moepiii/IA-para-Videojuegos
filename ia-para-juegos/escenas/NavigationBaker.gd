# Archivo: NavigationBaker.gd (Adjunto al NavigationRegion2D)
extends NavigationRegion2D

# ⚠️ AJUSTA ESTE VALOR: Radio del personaje (ej: 16 si mide 32x32)
const AGENT_RADIUS = 16.0 

func _ready():
	# 1. Asegurarse de que el recurso NavigationMesh exista.
	# 'navigation_mesh' es la propiedad que el compilador no reconoce.
	if not navigation_mesh:
		navigation_mesh = NavigationMesh.new()
		
	# 2. Configuramos el Agente (el radio).
	navigation_mesh.agent_radius = AGENT_RADIUS
	
	# 3. Hornear (Bake) la malla.
	# 'bake_navigation_mesh()' es el método que el compilador no reconoce.
	bake_navigation_mesh() 
	
	print("Malla de navegación horneada por script correctamente. ¡Vamos con las regiones!")
