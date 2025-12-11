extends Habitacion # Hereda de tu script base

# Lista de nodos que están apagados y queremos encender
@export var luces_a_encender: Array[TacticalWaypoint]

func _ready():
	super._ready()
	if GameManager:
		GameManager.monedas_cambiadas.connect(_on_monedas_cambiadas)

func _on_monedas_cambiadas(total):
	# AL LLEGAR A 3 MONEDAS -> SE HACE LA LUZ
	if total == 3:
		print("💡 ¡Luces encendidas! El camino es seguro.")
		for luz in luces_a_encender:
			if luz:
				# 1. Cambiar la lógica
				luz.es_iluminado = true
				
				# 2. Feedback visual (Cambiar de Negro a Amarillo/Blanco)
				luz.queue_redraw()
