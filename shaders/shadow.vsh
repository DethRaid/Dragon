#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec2 uv;
varying vec3 normal;
varying float isTransparent;

float getIsTransparent(in float materialId) {
    if(materialId == 160.0) {   // stained glass pane
        return 1.0;
    }
    if(materialId == 95.0) {    // stained glass
        return 1.0;
    }
    if(materialId == 30.0) {    // ice
        return 1.0;
    }
    return 0.0;
}

void main() {
    gl_Position = ftransform();

    uv = gl_MultiTexCoord0.st;
    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    isTransparent = getIsTransparent(mc_Entity.x);
}
