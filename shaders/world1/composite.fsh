#version 120

const int 		R8 						= 0;
const int 		RG8 					= 0;
const int 		RGB8 					= 1;
const int 		RGB16 					= 2;
const int 		gcolorFormat 			= RGB16;
const int 		gdepthFormat 			= RGB8;
const int 		gnormalFormat 			= RGB16;
const int 		compositeFormat 		= RGB8;

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
