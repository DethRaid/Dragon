#version 120

/* DRAWBUFFERS:012 */

uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D gdepth;

varying vec4 texcoord;


void main() {


  gl_FragData[0] = texture2D(gcolor, texcoord.st);
  gl_FragData[1] = texture2D(gnormal, texcoord.st);
  gl_FragData[2] = texture2D(gdepth, texcoord.st);
}
