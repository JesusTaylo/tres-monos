class_name Confeti
## Explosión de confeti barata (CPUParticles3D, sin luces ni sombras).
## Se crea, dispara una vez y se borra sola. Va en la capa MUNDO: el Ciego no
## la ve (para él hay que emitir un NoiseEvent aparte).

const CANTIDAD := 70
const DURACION := 1.6
const COLORES := [Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.8, 1), Color(0.5, 1, 0.4),
	Color(1, 0.5, 1)]

static var _malla: QuadMesh


static func explotar(arbol: Node, posicion: Vector3) -> void:
	var escena := arbol.get_tree().current_scene if arbol.is_inside_tree() else null
	if escena == null:
		return
	var particulas := CPUParticles3D.new()
	particulas.mesh = _crear_malla()
	particulas.amount = CANTIDAD
	particulas.lifetime = DURACION
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.direction = Vector3.UP
	particulas.spread = 70.0
	particulas.initial_velocity_min = 3.0
	particulas.initial_velocity_max = 6.5
	particulas.gravity = Vector3(0, -7.0, 0)
	particulas.damping_min = 1.5
	particulas.damping_max = 3.0
	particulas.angular_velocity_min = -540.0
	particulas.angular_velocity_max = 540.0
	particulas.scale_amount_min = 0.6
	particulas.scale_amount_max = 1.2
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array(range(COLORES.size()).map(
		func(i: int) -> float: return float(i) / (COLORES.size() - 1)))
	degradado.colors = PackedColorArray(COLORES)
	# Cada papelito toma un color al azar del degradado.
	particulas.color_initial_ramp = degradado
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particulas.layers = Capas.MUNDO
	particulas.finished.connect(particulas.queue_free)
	escena.add_child(particulas)
	particulas.global_position = posicion
	# Con one_shot puesto antes de entrar al árbol no arranca solo: hay que reiniciarlo.
	particulas.restart()


static func _crear_malla() -> QuadMesh:
	if _malla == null:
		_malla = QuadMesh.new()
		_malla.size = Vector2(0.07, 0.05)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_malla.material = material
	return _malla
