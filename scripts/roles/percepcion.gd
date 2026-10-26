extends Node
## Percepción por rol (componente del jugador): decide qué capas ve la cámara
## del jugador local y con qué entorno. Solo actúa en el jugador propio.
## Se actualiza sola si los roles cambian (rotación al terminar la ronda).

## Qué capas ve cada rol.
const MASCARAS := {
	Roles.Rol.MUDO: Capas.MUNDO | Capas.OBJETIVO | Capas.JUGADORES,
	Roles.Rol.SORDO: Capas.MUNDO | Capas.JUGADORES,
	Roles.Rol.CIEGO: Capas.SILUETAS,
}
## Sin rol (p. ej. al abrir el nivel suelto para probar) se ve todo.
const MASCARA_SIN_ROL := Capas.MUNDO | Capas.OBJETIVO | Capas.JUGADORES
## Niebla ligera del Sordo: ve el entorno, pero le cuesta más lo lejano.
const DENSIDAD_NIEBLA_SORDO := 0.06

@export var camara: Camera3D


func _ready() -> void:
	if not is_multiplayer_authority():
		return
	Lobby.estado_cambiado.connect(_aplicar)
	_aplicar()


func _aplicar() -> void:
	var rol := Lobby.mi_rol()
	camara.cull_mask = MASCARAS.get(rol, MASCARA_SIN_ROL)
	match rol:
		Roles.Rol.SORDO:
			camara.environment = _entorno_sordo()
		Roles.Rol.CIEGO:
			camara.environment = _entorno_ciego()
		_:
			# null = usa el WorldEnvironment del nivel.
			camara.environment = null


## El entorno del nivel, con niebla.
func _entorno_sordo() -> Environment:
	var base := camara.get_world_3d().environment
	var entorno: Environment = base.duplicate() if base else Environment.new()
	entorno.fog_enabled = true
	entorno.fog_density = DENSIDAD_NIEBLA_SORDO
	entorno.fog_light_color = entorno.background_color
	return entorno


## Negro total: sin fondo ni luz ambiental; las siluetas usan material sin sombreado.
func _entorno_ciego() -> Environment:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color.BLACK
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.BLACK
	return entorno
