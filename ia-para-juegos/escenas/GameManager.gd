extends Node

# Señal para avisar a la interfaz (HUD) que el número cambió
signal monedas_cambiadas(nueva_cantidad)

var total_monedas: int = 0

func sumar_moneda():
	total_monedas += 1
	print("💰 Monedas: ", total_monedas)
	# Avisar a todos los interesados (como el HUD)
	monedas_cambiadas.emit(total_monedas)
