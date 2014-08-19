#version 120

const int   shadowMapResolution = 2048;
const bool  shadowHardwareFiltering = false;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;

uniform sampler2D shadow;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;


varying vec2 coord;

varying vec3 lightVector;
varying vec3 lightColor;

struct Pixel {
    vec4 position;
    vec3 color;
    vec3 normal;
    float reflectivity;
    float smoothness;
    bool isWater;
    
    bool skipLighting;
    
    vec3 directLighting;
    vec3 torchLighting;
    vec3 ambientLighting;
};

struct World {
    vec3 lightDirection;
    vec3 lightColor;
};

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////
//Credit to Sonic Ether for depth, normal, and positions

float getDepth(  vec2 coord ) {	
    return texture2D( gdepthtex, coord ).r;
}

vec4 getScreenSpacePosition() {	
	float depth = getDepth( coord );
	vec4 fragposition = gbufferProjectionInverse * vec4( coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0 );
		 fragposition /= fragposition.w;
	return fragposition;
}

vec4 getWorldSpacePosition() {
	vec4 pos = getScreenSpacePosition();
	pos = gbufferModelViewInverse * pos;
	pos.xyz += cameraPosition.xyz;
	return pos;
}

vec3 getColor() {
    return texture2D( gcolor, coord ).rgb;
}

vec3 getNormal() {
    vec3 normal = normalize( texture2D( gnormal, coord ).xyz * 2.0 - 1.0 );
    normal.x *= -1;
    return normal;
}

float getReflectivity() {
    return texture2D( gnormal, coord ).a;
}

bool getSky() {
    return texture2D( gnormal, coord ).r > 0.5;
}

bool getWater() {
    return texture2D( gnormal, coord ).b > 0.5;
}

float getSmoothness() {
    return texture2D( gnormal, coord ).a;
}

///////////////////////////////////////////////////////////////////////////////
//                              Lighting Functions                           //
///////////////////////////////////////////////////////////////////////////////

//from SEUS v8
vec3 calcShadowCoordinate( in Pixel pixel ) {
    vec4 shadowCoord = pixel.position;
    shadowCoord.xyz -= cameraPosition;
    shadowCoord = shadowModelView * shadowCoord;
    shadowCoord = shadowProjection * shadowCoord;
    shadowCoord /= shadowCoord.w;
    
    shadowCoord.st = shadowCoord.st * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]
    float dFrag = (1 + shadowCoord.z) * 0.5 + 0.005;
    
    return vec3( shadowCoord.st, dFrag );
}

void calcShadowing( inout Pixel pixel ) {
    vec3 shadowCoord = calcShadowCoordinate( pixel );
    float shadowDepth = texture2D( shadow, shadowCoord.st ).r;
    if( shadowCoord.z - shadowDepth > 0.0065 ) {
        pixel.directLighting = vec3( 0 );
    }
}

void calcDirectLighting( inout Pixel pixel ) { 
    vec3 normal = normalize( texture2D( gnormal, coord ).xyz * 2.0 - 1.0 );
    float ndotl = dot( lightVector, normal );
    ndotl = clamp( ndotl, 0, 1 );
    pixel.directLighting = lightColor * ndotl;
    if( ndotl > 0.1 ) {
        calcShadowing( pixel );
    }
}

//calcualtes the lighting from the torches
void calcTorchLighting( inout Pixel pixel ) {
    vec3 torchColor = vec3( 1, 0.9, 0.5 );
    pixel.torchLighting = torchColor * texture2D( gdepth, coord ).g;
}

void calcAmbientLighting( inout Pixel pixel ) {
    pixel.ambientLighting = vec3( 0.15, 0.17, 0.2 );
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

void fillPixelStruct( inout Pixel pixel ) {
    pixel.position =        getWorldSpacePosition();
    pixel.normal =          getNormal();
    pixel.color =           getColor();
    pixel.reflectivity =    getReflectivity();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    getSky();
    pixel.isWater =         getWater();
}

void calcSSAO( inout Pixel pixel ) {
    //So basically, I guess we check if x random rays are behind something???
    float ssaoFac = 1.0;
    pixel.directLighting *= ssaoFac;
    pixel.torchLighting *= ssaoFac;
}

vec3 calcLitColor( in Pixel pixel ) {
    vec3 color = pixel.color * pixel.directLighting + 
                 pixel.color * pixel.torchLighting + 
                 pixel.color * pixel.ambientLighting;
    return color / 2;
}

void main() {
    Pixel pixel;
    
    fillPixelStruct( pixel );
    
    calcDirectLighting( pixel );
    calcTorchLighting( pixel );
    calcAmbientLighting( pixel );
    
    calcSSAO( pixel );
    
    vec3 litColor = calcLitColor( pixel );

    gl_FragData[3] = vec4( litColor, 1 );
}
