#version 120

attribute vec4 mv_Entity;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;
varying vec3 pos;

varying float depth;

varying vec3 normal;
varying mat3 normalMatrix;
varying float windSpeed;
varying float isWater;

void main() {
    // The water should wave in the breeze. Based on the wind speed, smaller
    // and choppier waves will appear. First, simple Gerstner displacement
    
    // passthrough variables
    color = gl_Color;
    
    uv = gl_MultiTexCoord0.st;
    uvLight = (glTextureMatrix[1] * glMultiTexCoord1).st;
    
    // Get the worldspace position of the current vertex
    vec4 position_model = glModelViewMatrix * gl_Vertex;
    vec4 position_view = gBufferModelViewInverse * position;
    vec3 position_world = viewPos.xyz + cameraPosition;
    
    
}