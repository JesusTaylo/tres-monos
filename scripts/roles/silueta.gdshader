// Siluetas del Ciego: las superficies se iluminan cerca de los ruidos recientes.
// Todas las gemelas de silueta comparten este material; siluetas.gd llena los arreglos.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

const int MAX_RUIDOS = 16;

// xyz = posición del ruido, w = radio actual.
uniform vec4 ruidos[MAX_RUIDOS];
// Brillo actual de cada ruido (ya desvanecido); 0 = espacio libre.
uniform float fuerzas[MAX_RUIDOS];
uniform vec3 color : source_color = vec3(0.65, 0.8, 1.0);
// Cuánto brillo tienen las caras de frente frente a los bordes.
uniform float brillo_frente : hint_range(0.0, 1.0) = 0.6;
// Ganancia general del brillo.
uniform float ganancia : hint_range(0.0, 4.0) = 2.5;

varying vec3 posicion_mundo;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float luz = 0.0;
	for (int i = 0; i < MAX_RUIDOS; i++) {
		if (fuerzas[i] <= 0.0) {
			continue;
		}
		float distancia = distance(posicion_mundo, ruidos[i].xyz);
		float caida = 1.0 - clamp(distancia / max(ruidos[i].w, 0.001), 0.0, 1.0);
		luz += fuerzas[i] * smoothstep(0.0, 1.0, caida);
	}
	// Los bordes brillan más que las caras de frente: se lee como silueta.
	float borde = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color * min(luz * ganancia, 1.0) * mix(brillo_frente, 1.0, borde);
}
