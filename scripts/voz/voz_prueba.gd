class_name VozPrueba
extends RefCounted
## Voz de prueba sintética para debug: un "bla-bla" con sílabas, vocales y pausas
## entre frases, para probar la voz con varias instancias en una PC sin micrófonos.
##
## Para que sea barato en GDScript, por cada sílaba se arma una tabla con UN ciclo
## de la onda (armónicos pesados por los formantes de la vocal) y luego solo se
## recorre la tabla a la altura de la voz.

const TAMANO_TABLA := 256
const ARMONICOS := 24
const SILABAS_POR_SEGUNDO := 4.0
const SEGUNDOS_HABLANDO := 2.5
const SEGUNDOS_PAUSA := 1.2
const VOLUMEN := 0.35
## Formantes (F1, F2) aproximados de a, e, i, o, u.
const VOCALES := [Vector2(800, 1200), Vector2(500, 1800), Vector2(300, 2300),
	Vector2(500, 900), Vector2(320, 800)]

var _tabla := PackedFloat32Array()
var _fase := 0.0
var _tiempo := 0.0
var _silaba_actual := -1
var _altura := 140.0
var _azar := RandomNumberGenerator.new()


func _init(semilla: int = 0) -> void:
	_azar.seed = semilla if semilla != 0 else randi()
	_tabla.resize(TAMANO_TABLA)
	# Cada instancia con una voz un poco distinta.
	_altura = _azar.randf_range(110.0, 190.0)


## Devuelve `cantidad` muestras estéreo a `mezcla` Hz.
func generar(cantidad: int, mezcla: float) -> PackedVector2Array:
	var salida := PackedVector2Array()
	salida.resize(cantidad)
	var paso_tiempo := 1.0 / mezcla
	var ciclo_frase := SEGUNDOS_HABLANDO + SEGUNDOS_PAUSA
	for i in cantidad:
		var en_frase := fmod(_tiempo, ciclo_frase)
		var valor := 0.0
		if en_frase < SEGUNDOS_HABLANDO:
			var silaba := int(_tiempo * SILABAS_POR_SEGUNDO)
			if silaba != _silaba_actual:
				_silaba_actual = silaba
				_armar_tabla(VOCALES[_azar.randi() % VOCALES.size()])
			# Envolvente de sílaba: sube rápido, baja despacio.
			var t_silaba := fmod(_tiempo * SILABAS_POR_SEGUNDO, 1.0)
			var envolvente := minf(t_silaba * 8.0, 1.0) * (1.0 - t_silaba)
			# Entonación: sube y baja un poco a lo largo de la frase.
			var altura := _altura * (1.0 + 0.12 * sin(en_frase * 2.3))
			_fase = fmod(_fase + altura * paso_tiempo, 1.0)
			valor = _tabla[int(_fase * TAMANO_TABLA)] * envolvente * VOLUMEN
		salida[i] = Vector2(valor, valor)
		_tiempo += paso_tiempo
	return salida


func _armar_tabla(formantes: Vector2) -> void:
	var maximo := 0.0
	for j in TAMANO_TABLA:
		var angulo := TAU * j / TAMANO_TABLA
		var suma := 0.0
		for h in range(1, ARMONICOS + 1):
			var frecuencia := _altura * h
			var peso := _resonancia(frecuencia, formantes.x) + 0.6 * _resonancia(frecuencia, formantes.y)
			suma += peso * sin(angulo * h) / h
		_tabla[j] = suma
		maximo = maxf(maximo, absf(suma))
	if maximo > 0.0:
		for j in TAMANO_TABLA:
			_tabla[j] /= maximo


func _resonancia(frecuencia: float, formante: float) -> float:
	var distancia := (frecuencia - formante) / 150.0
	return 1.0 / (1.0 + distancia * distancia)
