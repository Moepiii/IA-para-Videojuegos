@tool
extends Marker2D
class_name TacticalWaypoint

# --- REQUERIMIENTO: 3 CUALIDADES TÁCTICAS ESTÁTICAS ---
@export_group("Propiedades Tácticas")
@export var tiene_cobertura: bool = false   # T1: Bueno para el Cobarde
@export var es_iluminado: bool = true       # T2: Bueno para el Guardia, Malo para Stalker
@export var es_punto_alto: bool = false     # T3: Ventaja táctica (ej. francotirador/vigía)

# Para debug visual (Requerimiento: "verse explícitamente")
func _draw():
	if Engine.is_editor_hint():
		# Dibujamos un círculo con color según sus propiedades
		var color = Color.WHITE
		if tiene_cobertura: color = Color.BLUE
		elif not es_iluminado: color = Color.BLACK # Sombra
		elif es_punto_alto: color = Color.RED
		
		draw_circle(Vector2.ZERO, 8.0, color)
