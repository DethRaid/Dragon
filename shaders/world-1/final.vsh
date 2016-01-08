#version 120

#define OVERDRAW 1.0f

varying vec4 texcoord;




void main() {
  gl_Position = ftransform();


  texcoord = gl_MultiTexCoord0;

  texcoord = texcoord * 2.0f - 1.0f;
  texcoord /= OVERDRAW;
  texcoord = texcoord * 0.5f + 0.5f;
}
