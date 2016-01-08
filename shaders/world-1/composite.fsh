#version 120
#extension GL_ARB_shader_texture_lod : enable

/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/

#define TORCH_COLOR 0.8,0.6,0.3		//RGB - Red, Green, Blue

#define TORCH_ATTEN 2.0					//how much the torch light will be attenuated (decrease if you want the torches to cover a bigger area)
#define TORCH_INTENSITY 1.0

#define HANDLIGHT_AMOUNT 0.5

#define MIN_LIGHT = 0.2;


const int 		RGBA16 					= 1;
const int 		RGBA8 					= 1;
const int 		gcolorFormat 		= RGBA16;
const int 		gnormalFormat 	= RGBA16;
const int 		gaux1Format 		= RGBA8;
const int 		gaux3Format 		= RGBA8;

const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;

const float 	ambientOcclusionLevel 	= 0.5f;

/* DRAWBUFFERS:02 */

uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;

varying vec4 texcoord;

varying vec3 upVec;

varying float handItemLight;
varying float eyeAdapt;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform float frameTimeCounter;

varying vec3 colorTorchlight;


vec4 aux = texture2D(gaux1, texcoord.st);
float sky_lightmap = pow(aux.r, 1.1);

float handlight = handItemLight*0.5*1.0;
const float speed = 2.5;
float light_jitter = 1.0 - sin(frameTimeCounter * 1.4 * speed + cos(frameTimeCounter * 1.9 * speed)) * 0.028;			//little light variations
float torch_lightmap = pow(aux.b * light_jitter, 4.0) * 0.75;
float torch_lightmap2 = pow(aux.b, 4.0 * 6) * 0.75 * 100;

vec3 specular = texture2D(gaux3,texcoord.xy).rgb;
float specmap = specular.r * (1.0 - specular.b) + specular.g + specular.b * 0.85;



vec3 CalculateBloom(in int LOD, in vec2 offset) {

	float scale = pow(2.0f, float(LOD));

	float padding = 0.02f;

	if (	texcoord.s - offset.s + padding < 1.0f / scale + (padding * 2.0f)
		&&  texcoord.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)
		&&  texcoord.s - offset.s + padding > 0.0f
		&&  texcoord.t - offset.t + padding > 0.0f) {

		vec3 bloom = vec3(0.0f);
		float allWeights = 0.0f;

		for (int i = 0; i < 6; i++) {
			for (int j = 0; j < 6; j++) {

				float weight = 1.0f - distance(vec2(i, j), vec2(2.5f)) * 0.72;
					  weight = clamp(weight, 0.0f, 1.0f);
					  weight = 1.0f - cos(weight * 3.1415 * 0.5f);
					  weight = pow(weight, 2.0f);
				vec2 coord = vec2(i - 2.5, j - 2.5);
					 coord.x /= viewWidth;
					 coord.y /= viewHeight;


				vec2 finalCoord = (texcoord.st + coord.st - offset.st) * scale;

				if (weight > 0.0f)
				{
					bloom += pow(clamp(texture2D(gcolor, finalCoord, 0).rgb, vec3(0.0f), vec3(1.0f)), vec3(2.2f)) * weight;
					allWeights += 1.0f * weight;
				}
			}
		}

		bloom /= allWeights;

		return bloom;

	} else {
		return vec3(0.0f);
	}

}

float diffuseorennayar(vec3 pos, vec3 lvector, vec3 normal, float spec, float roughness) {

    vec3 v = normalize(pos);
	vec3 l = normalize(lvector);
	vec3 n = normalize(normal);

	float vdotn = dot(v,n);
	float ldotn = dot(l,n);
	float cos_theta_r = vdotn;
	float cos_theta_i = ldotn;
	float cos_phi_diff = dot(normalize(v-n*vdotn),normalize(l-n*ldotn));
	float cos_alpha = min(cos_theta_i,cos_theta_r); // alpha=max(theta_i,theta_r);
	float cos_beta = max(cos_theta_i,cos_theta_r); // beta=min(theta_i,theta_r)

	float r2 = roughness*roughness;
	float a = 1.0-0.5*r2/(r2+0.33);
	float b_term;

	if(cos_phi_diff>=0.0) {
		float b = 0.45*r2/(r2+0.09);
		b_term = b*sqrt((1.0-cos_alpha*cos_alpha)*(1.0-cos_beta*cos_beta))/cos_beta*cos_phi_diff;
		b_term = b*sin(cos_alpha)*tan(cos_beta)*cos_phi_diff;
	}
	else b_term = 0.0;

	return clamp(cos_theta_i*(a+b_term),0.0,1.0);
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec2 newtc = texcoord.xy;

	float pixeldepth = texture2D(depthtex0,texcoord.xy).x;

	vec4 fragposition = gbufferProjectionInverse * vec4(newtc.s * 2.0f - 1.0f, newtc.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

		 float iswater = float(aux.g > 0.04 && aux.g < 0.07);
		 float hand = float(aux.g > 0.75 && aux.g < 0.85);

		 float roughness = mix(1.0-(pow(specular.g,2.0))+specular.b+specular.g*0.5,0.05,iswater);
		 if (specular.r+specular.g+specular.b > 1.0/255.0) {
			 } else if (iswater > 0.09) {
				 } else {
					 roughness = 0.0;
				 }

 	 	 vec3 finalComposite = texture2D(gcolor, texcoord.st).rgb;
		 vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
		 
		 float NdotUp = dot(normal,upVec);

		 vec3 torchcolor = normalize(vec3(TORCH_COLOR))*0.3*TORCH_INTENSITY;

		 float handlightDistance = 13.0f;

		 handlight = (handItemLight*10.0*HANDLIGHT_AMOUNT)*hand;
		 handlight += (handItemLight*1.0*HANDLIGHT_AMOUNT);
		 
		 float visibility = clamp(pow(sky_lightmap, 1.0), 0.0, 1.0);
		 float bouncefactor = sqrt((NdotUp*0.4+0.61))*0.66;
		 
		 vec3 bounceSunlight = 3.2*vec3(1)*visibility*visibility*visibility;
		 vec3 sky_light = pow(vec3(1),vec3(1.0))*visibility*bouncefactor;

		 float handLight = (handlight*1.0)/pow(length(fragposition.xyz),1.0)*diffuseorennayar(fragposition.xyz, -fragposition.xyz, normal, specmap, roughness+0.01);
		 vec3 Torchlight_lightmap = (torch_lightmap+handlight*2.0*pow(max(handlightDistance-length(fragposition.xyz),0.0)/handlightDistance,4.0)*max(dot(-fragposition.xyz,normal),0.0)) *  torchcolor ;
		 
		 finalComposite *= ((sky_light) * 4.5 + Torchlight_lightmap/2) * 10;

	gl_FragData[0] = vec4(finalComposite, 1.0);

}
