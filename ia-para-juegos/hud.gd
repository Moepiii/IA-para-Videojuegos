extends CanvasLayer

@onready var label_monedas = $Label # Asegúrate que tu nodo hijo se llame Label

func _ready():
	# Actualizar texto al inicio (por si reinicias nivel y ya tenías monedas)
	actualizar_marcador(GameManager.total_monedas)
	
	# CONECTARSE AL CEREBRO GLOBAL
	# "Oye GameManager, cuando cambien las monedas, avísame a mí"
	GameManager.monedas_cambiadas.connect(actualizar_marcador)

func actualizar_marcador(cantidad):
	label_monedas.text = "Monedas: " + str(cantidad)
