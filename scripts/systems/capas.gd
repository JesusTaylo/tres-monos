class_name Capas
## Máscaras de las capas de render (VisualInstance3D.layers / Camera3D.cull_mask).
## Deben coincidir con los nombres de capas en project.godot.

const MUNDO := 1 << 0
## Lo que importa en el puzzle; solo lo ve el Mudo.
const OBJETIVO := 1 << 1
const JUGADORES := 1 << 2
## Siluetas temporales que generan los ruidos; lo único que ve el Ciego.
const SILUETAS := 1 << 3
