#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform int entityHurt;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;

void main() {
    vec4 final_color = texture2D(texture, uv) * color;
    final_color.bg -= min(float(entityHurt) * 0.1, 1.0);
    gl_FragData[0] = final_color;
    gl_FragData[5] = vec4(0, uvLight.r, 0, 0.5);
    gl_FragData[6] = vec4(uvLight.g, 0, 0, 0);
    gl_FragData[7] = vec4(normalize(normal) * 0.5 + 0.5, 1);
}
