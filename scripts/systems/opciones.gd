extends Node
## Opciones del jugador (autoload "Opciones"): las aplica y las guarda en
## user://opciones.cfg. La voz de prueba no se guarda: es por instancia (debug).

signal cambiadas

const ARCHIVO := "user://opciones.cfg"
const SECCION := "audio"

var dispositivo_entrada := "Default"
## Ganancia del micrófono (1 = sin cambio).
var volumen_entrada := 1.0
## Volumen de la voz que se oye, lineal 0..1 (se aplica al bus "Voz").
var volumen_salida := 1.0
var modo_microfono: int = Microfono.Modo.PULSAR


func _ready() -> void:
	cargar()


func cargar() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(ARCHIVO) == OK:
		dispositivo_entrada = archivo.get_value(SECCION, "dispositivo_entrada", dispositivo_entrada)
		volumen_entrada = archivo.get_value(SECCION, "volumen_entrada", volumen_entrada)
		volumen_salida = archivo.get_value(SECCION, "volumen_salida", volumen_salida)
		modo_microfono = archivo.get_value(SECCION, "modo_microfono", modo_microfono)
	# Si el micrófono guardado ya no está conectado, se usa el predeterminado.
	if not dispositivo_entrada in Microfono.dispositivos():
		dispositivo_entrada = "Default"
	aplicar()


func guardar() -> void:
	var archivo := ConfigFile.new()
	archivo.set_value(SECCION, "dispositivo_entrada", dispositivo_entrada)
	archivo.set_value(SECCION, "volumen_entrada", volumen_entrada)
	archivo.set_value(SECCION, "volumen_salida", volumen_salida)
	archivo.set_value(SECCION, "modo_microfono", modo_microfono)
	var error := archivo.save(ARCHIVO)
	if error != OK:
		push_warning("No se pudieron guardar las opciones: %s" % error_string(error))


func aplicar() -> void:
	Microfono.poner_dispositivo(dispositivo_entrada)
	Microfono.ganancia = volumen_entrada
	Microfono.modo = modo_microfono
	var bus := AudioServer.get_bus_index("Voz")
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen_salida, 0.0001)))
	cambiadas.emit()


## Cambia una opción, la aplica y la guarda.
func poner(nombre: StringName, valor: Variant) -> void:
	set(nombre, valor)
	aplicar()
	guardar()
