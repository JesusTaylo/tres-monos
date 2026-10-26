extends Node
## Siluetas del Ciego (un nodo por nivel).
## A cada malla visible del nivel (mundo y jugadores, nunca el objetivo) le
## crea una gemela en la capa SILUETAS con un material compartido. Al llegar
## un NoiseEvent, el shader ilumina lo cercano a la fuente y se desvanece.
## Solo la cámara del Ciego ve esa capa; en los demás las gemelas no se dibujan.

const SHADER := preload("res://scripts/roles/silueta.gdshader")
## Debe coincidir con MAX_RUIDOS del shader.
const MAX_RUIDOS := 16
## Segundos que tarda una silueta en desvanecerse.
const DURACION := 1.6
## Segundos que tarda el ruido en expandirse hasta su radio (efecto de onda).
const EXPANSION := 0.2
## Capas que generan silueta. El objetivo queda fuera a propósito.
const CAPAS_CON_SILUETA := Capas.MUNDO | Capas.JUGADORES

var _material := ShaderMaterial.new()
## Ruidos activos: {evento: NoiseEvent, edad: float}.
var _activos: Array[Dictionary] = []
var _nivel: Node


func _ready() -> void:
	_material.shader = SHADER
	_nivel = owner if owner else get_parent()
	Ruido.ruido_recibido.connect(_al_recibir_ruido)
	# Lo que ya existe en el nivel y lo que aparezca después (jugadores).
	for nodo in _nivel.find_children("*", "GeometryInstance3D", true, false):
		_crear_gemela(nodo)
	get_tree().node_added.connect(_al_agregarse_nodo)
	_actualizar_shader()


func _process(delta: float) -> void:
	if _activos.is_empty():
		return
	for ruido in _activos:
		ruido.edad += delta
	_activos = _activos.filter(func(ruido: Dictionary) -> bool: return ruido.edad < DURACION)
	_actualizar_shader()


func _al_recibir_ruido(evento: NoiseEvent) -> void:
	_activos.append({"evento": evento, "edad": 0.0})
	# Si hay demasiados, se descartan los más viejos.
	while _activos.size() > MAX_RUIDOS:
		_activos.pop_front()


func _actualizar_shader() -> void:
	var posiciones: Array[Vector4] = []
	var fuerzas := PackedFloat32Array()
	posiciones.resize(MAX_RUIDOS)
	fuerzas.resize(MAX_RUIDOS)
	for i in _activos.size():
		var evento: NoiseEvent = _activos[i].evento
		var edad: float = _activos[i].edad
		var radio := evento.radio * minf(edad / EXPANSION, 1.0)
		var restante := 1.0 - edad / DURACION
		posiciones[i] = Vector4(evento.posicion.x, evento.posicion.y, evento.posicion.z, radio)
		fuerzas[i] = evento.intensidad * restante * restante
	_material.set_shader_parameter("ruidos", posiciones)
	_material.set_shader_parameter("fuerzas", fuerzas)


func _al_agregarse_nodo(nodo: Node) -> void:
	if nodo is GeometryInstance3D and _nivel.is_ancestor_of(nodo):
		_crear_gemela.call_deferred(nodo)


func _crear_gemela(nodo: GeometryInstance3D) -> void:
	if not is_instance_valid(nodo) or (nodo.layers & CAPAS_CON_SILUETA) == 0 \
			or (nodo.layers & Capas.OBJETIVO) != 0:
		return
	if nodo is MeshInstance3D and nodo.mesh:
		_agregar_gemela(nodo, nodo.mesh, Transform3D.IDENTITY)
	elif nodo is CSGShape3D and nodo.is_root_shape():
		# La malla de un CSG se arma un frame después.
		await get_tree().process_frame
		if not is_instance_valid(nodo):
			return
		var mallas: Array = nodo.get_meshes()
		if mallas.size() >= 2:
			_agregar_gemela(nodo, mallas[1], mallas[0])


## La gemela es hija del original: hereda su movimiento y su visibilidad.
func _agregar_gemela(original: Node3D, malla: Mesh, transformacion: Transform3D) -> void:
	var gemela := MeshInstance3D.new()
	gemela.name = "silueta"
	gemela.mesh = malla
	gemela.transform = transformacion
	gemela.layers = Capas.SILUETAS
	gemela.material_override = _material
	gemela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	original.add_child(gemela)
