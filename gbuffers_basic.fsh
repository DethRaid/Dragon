#version 120

varying vec4 color;

void main() {
    gl_FragData[0] = color;
	gl_FragData[1] = vec4( 0.0, 0.0, 0.0, gl_FragCoord.z );
	gl_FragData[4] = vec4( 0.0, 1.0, 0.0, 1.0 );
    gl_FragData[5] = vec4( 0.0, 0.0, 1.0, 1.0 );
    gl_FragData[6] = vec4( 0.0, 0.0, 0.0, 1.0 );
}
