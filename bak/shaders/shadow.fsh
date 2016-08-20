#version 120

uniform sampler2D tex;

varying vec4 color;
varying vec2 uv;
varying vec3 normal;
varying float isTransparent;

void main() {
    vec4 frag_color = texture2D(tex, uv) * color;
    gl_FragData[0] = frag_color;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, isTransparent);
}
