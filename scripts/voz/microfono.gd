extends Node
## Micrófono (autoload "Microfono"). Lee la entrada de audio, o una voz de prueba
## en debug, decide si el jugador está hablando y entrega paquetes ya comprimidos.
## No sabe nada de roles ni de red: quien lo usa decide si transmite.
##
## Solo enciende el dispositivo mientras alguien lo pide (pedir/soltar): el jugador
## en partida, o el medidor del menú de opciones.

signal paquete_listo(paquete: PackedByteArray)
signal hablando_cambiado(hablando: bool)

enum Modo { ABIERTO, PULSAR }

## Modo abierto: volumen mínimo y probabilidad de voz (RNNoise) para contar como habla.
const UMBRAL_NIVEL := 0.03
const UMBRAL_VOZ := 0.4
## Sigue "hablando" un rato tras callarse, para no cortar finales de palabra.
const TIEMPO_GRACIA := 0.5
## Argumento de línea de comandos para arrancar con la voz de prueba (debug).
const ARGUMENTO_VOZ_PRUEBA := "--voz-prueba"

var modo := Modo.PULSAR
var ganancia := 1.0:
	set(valor):
		ganancia = valor
		if _codec_listo:
			_codec.poner_ganancia(ganancia)
## Solo en debug: usa la voz sintética en lugar del micrófono.
var voz_prueba := false:
	set(valor):
		voz_prueba = valor and OS.is_debug_build()
		_reiniciar_entrada()
## Si es false, se mide el nivel (para el menú) pero no se emiten paquetes.
var transmitir := false
## Volumen actual suavizado (0..1), para medidores e indicadores.
var nivel := 0.0
var hablando := false

var _codec := CodecVoz.new()
var _codec_listo := false
var _pedidos := {}
var _encendido := false
var _ultimo_habla := -INF
var _voz_sintetica: VozPrueba
## Muestras de voz de prueba que "deberían" haber llegado según el tiempo.
var _deuda_muestras := 0.0
var _error_dispositivo := OK
## El que pedimos. AudioServer.input_device tarda en reflejar el cambio
## (se aplica al abrir la entrada), así que no sirve para comparar.
var _dispositivo := "Default"


func _ready() -> void:
	# Queda en el log (user://logs/godot.log): ayuda a diagnosticar "no se oye nada".
	print("Voz: %s · micrófonos: %s" % ["disponible (TwoVoIP)" if disponible() else "NO disponible: falta la extensión TwoVoIP",
		", ".join(dispositivos())])
	if ARGUMENTO_VOZ_PRUEBA in OS.get_cmdline_user_args():
		voz_prueba = true


func disponible() -> bool:
	return CodecVoz.disponible()


## Error al abrir el micrófono (OK si no hubo), para mostrarlo en opciones.
func error_dispositivo() -> Error:
	return _error_dispositivo


func dispositivos() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func dispositivo_actual() -> String:
	return _dispositivo


func poner_dispositivo(nombre: String) -> void:
	if nombre == _dispositivo:
		return
	_dispositivo = nombre
	AudioServer.input_device = nombre
	_reiniciar_entrada()


## Alguien necesita el micrófono (p. ej. "jugador", "opciones").
func pedir(quien: StringName) -> void:
	_pedidos[quien] = true
	_actualizar_encendido()


func soltar(quien: StringName) -> void:
	_pedidos.erase(quien)
	_actualizar_encendido()


func _actualizar_encendido() -> void:
	var debe := not _pedidos.is_empty() and disponible()
	if debe == _encendido:
		return
	_encendido = debe
	if _encendido:
		_encender()
	else:
		_apagar()


func _encender() -> void:
	_error_dispositivo = OK
	var mezcla := AudioServer.get_mix_rate() if voz_prueba else AudioServer.get_input_mix_rate()
	if voz_prueba:
		_voz_sintetica = VozPrueba.new()
		_deuda_muestras = 0.0
	elif not _tiene_permiso():
		# Android: se pidió el permiso; al responder se vuelve a intentar.
		_error_dispositivo = ERR_UNAUTHORIZED
	else:
		_error_dispositivo = AudioServer.set_input_device_active(true)
		if _error_dispositivo != OK:
			push_warning("No se pudo abrir el micrófono: %s" % error_string(_error_dispositivo))
	_codec_listo = _codec.iniciar_codificador(mezcla) == OK
	if _codec_listo:
		_codec.poner_ganancia(ganancia)


func _apagar() -> void:
	if not voz_prueba:
		AudioServer.set_input_device_active(false)
	_codec_listo = false
	nivel = 0.0
	_poner_hablando(false)


## En Android grabar audio necesita permiso. Si todavía no lo hay, lo pide
## (el teléfono muestra el diálogo) y devuelve false; al aceptarlo se reintenta.
func _tiene_permiso() -> bool:
	if OS.get_name() != "Android":
		return true
	if not get_tree().on_request_permissions_result.is_connected(_al_responder_permiso):
		get_tree().on_request_permissions_result.connect(_al_responder_permiso)
	return OS.request_permission("android.permission.RECORD_AUDIO")


func _al_responder_permiso(permiso: String, concedido: bool) -> void:
	if permiso.ends_with("RECORD_AUDIO") and concedido:
		_reiniciar_entrada()


## Al cambiar de dispositivo o de fuente, se cierra y se vuelve a abrir.
func _reiniciar_entrada() -> void:
	if _encendido:
		_apagar()
		_encender()


func _process(delta: float) -> void:
	if not _encendido or not _codec_listo:
		return
	var por_trozo := _codec.muestras_de_entrada()
	if voz_prueba:
		_deuda_muestras += delta * AudioServer.get_mix_rate()
		while _deuda_muestras >= por_trozo:
			_deuda_muestras -= por_trozo
			_procesar_trozo(_voz_sintetica.generar(por_trozo, AudioServer.get_mix_rate()))
	else:
		while AudioServer.get_input_frames_available() >= por_trozo:
			_procesar_trozo(AudioServer.get_input_frames(por_trozo))
	nivel = lerpf(nivel, 0.0, minf(delta * 6.0, 1.0))


func _procesar_trozo(muestras: PackedVector2Array) -> void:
	if not _codec.procesar(muestras):
		return
	var pico := _codec.nivel()
	nivel = maxf(nivel, pico)
	var ahora := Time.get_ticks_msec() / 1000.0
	# La voz de prueba habla sola, como si fuera micrófono abierto.
	if modo == Modo.PULSAR and not voz_prueba:
		_poner_hablando(Input.is_action_pressed("hablar"))
	else:
		# La voz de prueba no siempre convence a RNNoise; basta con el volumen.
		var parece_voz := voz_prueba or _codec.probabilidad_voz() >= UMBRAL_VOZ
		if pico >= UMBRAL_NIVEL and parece_voz:
			_ultimo_habla = ahora
		_poner_hablando(ahora - _ultimo_habla <= TIEMPO_GRACIA)
	if hablando and transmitir:
		paquete_listo.emit(_codec.codificar())


func _poner_hablando(valor: bool) -> void:
	if valor == hablando:
		return
	hablando = valor
	if hablando and _codec_listo:
		_codec.reiniciar_codificador()
	hablando_cambiado.emit(hablando)
