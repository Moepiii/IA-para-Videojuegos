@tool
extends Marker2D
class_name TacticalWaypoint

# --- CUALIDADES TÁCTICAS (Se actualizan en vivo) ---
@export_group("Propiedades Tácticas")

@export var tiene_cobertura: bool = false:
	set(valor):
		tiene_cobertura = valor
		queue_redraw() # ¡Fuerza el repintado inmediato!

@export var es_iluminado: bool = true:
	set(valor):
		es_iluminado = valor
		queue_redraw()

@export var es_punto_alto: bool = false:
	set(valor):
		es_punto_alto = valor
		queue_redraw()

# --- DIBUJO DE DEBUG EN EL EDITOR ---
func _draw():
	# Solo dibujamos estas ayudas visuales en el editor
	if Engine.is_editor_hint():
		var color = Color.WHITE
		var radio = 8.0
		
		if tiene_cobertura: 
			# AZUL CUADRADO = Cobertura
			color = Color.BLUE
			draw_rect(Rect2(-radio, -radio, radio*2, radio*2), color, false, 2.0)
			
		elif not es_iluminado: 
			# NEGRO CÍRCULO = Sombra / Oscuridad
			color = Color.BLACK 
			draw_circle(Vector2.ZERO, radio, color)
			
		elif es_punto_alto: 
			# ROJO TRIÁNGULO = Punto Alto
			color = Color.RED
			var puntos = PackedVector2Array([
				Vector2(0, -radio), 
				Vector2(-radio, radio), 
				Vector2(radio, radio)
			])
			draw_colored_polygon(puntos, color)
			
		else:
			# BLANCO CÍRCULO = Punto Normal
			draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
