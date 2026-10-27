class_name Sonidos
## Efectos de sonido del juego, sintetizados al vuelo (aún no hay assets de
## audio): clics, crujidos y sonidos ridículos. Se generan una vez y se reusan.
##
## Regla por rol: igual que con la voz, el Mudo y el Sordo no oyen; los efectos
## solo suenan para el Ciego (y para todos si no hay roles, en un nivel suelto).
## Quien emite el sonido lo pide en todos los peers; cada uno decide si lo oye.

const FRECUENCIA_MUESTREO := 22050
const BUS := &"Efectos"
## Unidad de distancia del altavoz 3D: a esta distancia suena a volumen pleno.
const UNIDAD := 4.0

## nombre -> AudioStreamWAV ya generado.
static var _cache := {}


## ¿El jugador local oye los efectos?
static func puede_oir() -> bool:
	var rol := Lobby.mi_rol()
	return rol == -1 or rol == Roles.Rol.CIEGO


## Reproduce un efecto en una posición del mundo. `arbol` es cualquier nodo de la escena.
static func reproducir(arbol: Node, nombre: String, posicion: Vector3, volumen_db: float = 0.0) -> void:
	if not puede_oir() or not arbol.is_inside_tree():
		return
	var escena := arbol.get_tree().current_scene
	if escena == null:
		return
	var altavoz := AudioStreamPlayer3D.new()
	altavoz.stream = _sonido(nombre)
	altavoz.volume_db = volumen_db
	altavoz.unit_size = UNIDAD
	altavoz.bus = BUS
	altavoz.finished.connect(altavoz.queue_free)
	escena.add_child(altavoz)
	altavoz.global_position = posicion
	altavoz.play()


static func _sonido(nombre: String) -> AudioStreamWAV:
	if not _cache.has(nombre):
		_cache[nombre] = _generar(nombre)
	return _cache[nombre]


static func _generar(nombre: String) -> AudioStreamWAV:
	match nombre:
		"clic":
			return _crear(0.06, func(t: float, _f: float) -> float:
				return (randf_range(-1, 1) * 0.6 + sin(TAU * 1800.0 * t)) * exp(-t * 90.0))
		"tic":
			return _crear(0.025, func(t: float, _f: float) -> float:
				return sin(TAU * 3200.0 * t) * exp(-t * 220.0) * 0.35)
		"crujido":
			return _crear(0.45, func(t: float, f: float) -> float:
				var ruido := randf_range(-1, 1) * exp(-t * 9.0)
				return ruido * (0.6 + 0.4 * sin(TAU * 70.0 * t)) * (1.0 - f * 0.3))
		"pedorreta":
			# Sierra que baja de tono con vibrato: el sonido más ridículo posible.
			return _crear(0.7, func(t: float, f: float) -> float:
				var tono := lerpf(260.0, 70.0, f) * (1.0 + 0.08 * sin(TAU * 28.0 * t))
				var sierra := fmod(t * tono, 1.0) * 2.0 - 1.0
				return sierra * 0.55 * minf(t * 40.0, 1.0) * (1.0 - f))
		"silbido_caida":
			# Silbato que baja (caída de dibujos animados).
			return _crear(0.9, func(t: float, f: float) -> float:
				var fase := TAU * (1300.0 * t - 450.0 * t * t)
				return sin(fase) * 0.4 * minf(t * 20.0, 1.0) * (1.0 - f * f))
		"exito":
			# Dos notas que suben.
			return _crear(0.6, func(t: float, _f: float) -> float:
				var nota := 660.0 if t < 0.15 else 990.0
				var desde_nota := t if t < 0.15 else t - 0.15
				return sin(TAU * nota * t) * 0.45 * exp(-desde_nota * 5.0))
	push_warning("Sonido desconocido: %s" % nombre)
	return _crear(0.01, func(_t: float, _f: float) -> float: return 0.0)


## Genera PCM de 16 bits mono. `onda(t, fraccion)` devuelve la muestra en -1..1.
static func _crear(duracion: float, onda: Callable) -> AudioStreamWAV:
	var cantidad := int(duracion * FRECUENCIA_MUESTREO)
	var datos := PackedByteArray()
	datos.resize(cantidad * 2)
	for i in cantidad:
		var t := float(i) / FRECUENCIA_MUESTREO
		var muestra: float = clampf(onda.call(t, float(i) / cantidad), -1.0, 1.0)
		datos.encode_s16(i * 2, int(muestra * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = FRECUENCIA_MUESTREO
	wav.stereo = false
	wav.data = datos
	return wav
