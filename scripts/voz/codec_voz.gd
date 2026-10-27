class_name CodecVoz
extends RefCounted
## Códec de voz: el ÚNICO archivo que conoce la implementación (TwoVoIP / Opus).
## Para cambiar de códec, reemplazar este archivo manteniendo sus métodos públicos.
##
## Las clases de la extensión se crean con ClassDB para no nombrarlas en el código:
## si la extensión falta, el resto del juego compila igual y solo se queda sin voz.

const FRECUENCIA := 48000
## 20 ms por paquete.
const MUESTRAS_POR_PAQUETE := 960
const BITRATE := 16000
const COMPLEJIDAD := 5
# Constantes de TwovoipOpusEncoder (v6.5).
const _DENOISER_RNNOISE := 2
const _AGC_DESACTIVADO := 0

var _codificador: Object


static func disponible() -> bool:
	return ClassDB.class_exists("TwovoipOpusEncoder") and ClassDB.class_exists("AudioStreamOpus")


# --- Codificar (lado de quien habla) ---

## Prepara el codificador para audio que entra a `mezcla_entrada` Hz.
## Usa RNNoise para quitar ruido de fondo (ventilador, teclado).
func iniciar_codificador(mezcla_entrada: float) -> Error:
	if not disponible():
		return ERR_UNAVAILABLE
	_codificador = ClassDB.instantiate("TwovoipOpusEncoder")
	var error: Error = _codificador.initialize(mezcla_entrada, FRECUENCIA, 1, _DENOISER_RNNOISE,
		_AGC_DESACTIVADO, MUESTRAS_POR_PAQUETE)
	if error != OK:
		return error
	if not _codificador.create_opus_encoder(BITRATE, COMPLEJIDAD, true):
		return ERR_CANT_CREATE
	return OK


## Cuántas muestras de entrada hay que pasarle a procesar() cada vez.
func muestras_de_entrada() -> int:
	return _codificador.get_required_input_chunk_size()


## Procesa un trozo de entrada (exactamente muestras_de_entrada() muestras).
## Después se pueden leer nivel() y probabilidad_voz(), y llamar a codificar().
func procesar(muestras: PackedVector2Array) -> bool:
	return _codificador.process_chunk(muestras) >= 0


## Comprime el último trozo procesado en un paquete para enviar.
func codificar() -> PackedByteArray:
	return _codificador.encode_chunk(PackedByteArray())


## Volumen pico del último trozo (0..1), ya con la ganancia aplicada.
func nivel() -> float:
	return _codificador.get_peak()


## Qué tan probable es que el último trozo sea voz y no ruido (0..1).
func probabilidad_voz() -> float:
	return _codificador.get_speech_probability()


func poner_ganancia(ganancia: float) -> void:
	_codificador.set_gain(ganancia)


## Llamar al empezar a hablar, para que no arrastre estado de la frase anterior.
func reiniciar_codificador() -> void:
	_codificador.reset_opus_encoder()


# --- Decodificar (lado de quien escucha) ---

## Flujo de audio para un AudioStreamPlayer/AudioStreamPlayer3D.
static func crear_flujo() -> AudioStream:
	var flujo: AudioStream = ClassDB.instantiate("AudioStreamOpus")
	flujo.opus_sample_rate = FRECUENCIA
	flujo.opus_channels = 1
	return flujo


## Agrega un paquete recibido a la reproducción (player.get_stream_playback()).
static func empujar(reproduccion: AudioStreamPlayback, paquete: PackedByteArray) -> void:
	reproduccion.push_opus_packet(paquete, 0, 0)


## La reproducción empieza en pausa. Esto la suelta (cuando ya hay suficiente en cola).
static func reanudar(reproduccion: AudioStreamPlayback) -> void:
	reproduccion.mark_end_opus_stream(true)


## Pone una marca al final de lo encolado: al llegar ahí se pausa y espera más audio.
## Sirve para volver a acumular colchón entre una frase y la siguiente.
static func pausar_al_final(reproduccion: AudioStreamPlayback) -> void:
	reproduccion.mark_end_opus_stream(false)


## Muestras decodificadas esperando a sonar.
static func en_cola(reproduccion: AudioStreamPlayback) -> int:
	return reproduccion.queue_length_frames()


## Pico de volumen de lo que está sonando (0..1).
static func nivel_salida(reproduccion: AudioStreamPlayback) -> float:
	return reproduccion.get_chunk_max()
