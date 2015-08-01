#version 120

////////////////////////////////////////////////////ADJUSTABLE VARIABLES//////////////////

#define NORMAL_MAP_MAX_ANGLE 1.0f   		//The higher the value, the more extreme per-pixel normal mapping (bump mapping) will be.
#define TILE_RESOLUTION 128

#define PARALLAX

#define SPECULARITY

//#define OLD_SPECULAR					// Old specular from 1st SEUS complete, works best for our custom specular maps for ChromaHills
#define NEW_SPECULAR					// New specular from SEUS 10.1 and 10.2 preview

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////

/* DRAWBUFFERS:0123 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform float wetness;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;
varying mat3 tbnMatrix;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldNormal;

varying float materialIDs;

varying float distance;
varying float idCheck;

varying float smoothness_in;
varying float metalness_in;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

const float bump_distance = 78.0f;
const float fademult = 0.1f;

vec4 cubic(float x) {
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord) {
	int resolution = 64;

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec2 OffsetCoord(in vec2 coord, in vec2 offset, in int level) {
	int tileResolution = TILE_RESOLUTION;
	ivec2 atlasTiles = ivec2(32, 16);
	ivec2 atlasResolution = tileResolution * atlasTiles;

	coord *= atlasResolution;

	vec2 offsetCoord = coord + mod(offset.xy * atlasResolution, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x) {
		offsetCoord.x -= tileResolution;
	} else if (offsetCoord.x < minCoord.x) {
		offsetCoord.x += tileResolution;
	}

	if (offsetCoord.y > maxCoord.y) {
		offsetCoord.y -= tileResolution;
	} else if (offsetCoord.y < minCoord.y) {
		offsetCoord.y += tileResolution;
	}

	offsetCoord /= atlasResolution;

	return offsetCoord;
}

vec3 Get3DNoise(in vec3 pos) {
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
		 f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f, 37.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f, 37.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / 64.0f;
	vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	vec3 xy1 = texture2D(noisetex, coord).xyz;
	vec3 xy2 = texture2D(noisetex, coord2).xyz;
	return mix(xy1, xy2, vec3(f.z));
}

vec3 Get3DNoiseNormal(in vec3 pos) {
	float center = Get3DNoise(pos + vec3( 0.0f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float left 	 = Get3DNoise(pos + vec3( 0.1f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float up     = Get3DNoise(pos + vec3( 0.0f, 0.1f, 0.0f)).x * 2.0f - 1.0f;

	vec3 noiseNormal;
		 noiseNormal.x = center - left;
		 noiseNormal.y = center - up;

		 noiseNormal.x *= 0.2f;
		 noiseNormal.y *= 0.2f;

		 noiseNormal.b = sqrt(1.0f - noiseNormal.x * noiseNormal.x - noiseNormal.g * noiseNormal.g);
		 noiseNormal.b = 0.0f;

	return noiseNormal.xyz;
}

vec3 CalculateRainBump(in vec3 pos) {
	pos.y += frameTimeCounter * 3.0f;
	pos.xz *= 1.0f;

	pos.y += Get3DNoise(pos.xyz * vec3(1.0f, 0.0f, 1.0f)).y * 2.0f;


	vec3 p = pos;
	vec3 noiseNormal = Get3DNoiseNormal(p);	p.y += 0.25f;
		 noiseNormal += Get3DNoiseNormal(p); p.y += 0.5f;
		 noiseNormal += Get3DNoiseNormal(p); p.y += 0.75f;
		 noiseNormal += Get3DNoiseNormal(p);
		 noiseNormal /= 4.0f;

	return Get3DNoiseNormal(pos).xyz;
}

float GetModulatedRainSpecular(in vec3 pos) {
	pos.xz *= 1.0f;
	pos.y *= 0.2f;

	vec3 p = pos;

	float n = Get3DNoise(p).y;
		  n += Get3DNoise(p / 2.0f).x * 2.0f;
		  n += Get3DNoise(p / 4.0f).x * 4.0f;

		  n /= 7.0f;

	return n;
}

vec4 GetTexture(in sampler2D tex, in vec2 coord) {
    if( coord.x < 0.0f || coord.x > 1.0f || coord.y < 0.0f || coord.y > 1.0f ) {
        return vec4( 0.0 );
    }
	#ifdef PARALLAX
		vec4 t = vec4(0.0f);
		if (distance < 10.0f) {
			t = texture2DLod(tex, coord, 0);
		} else {
			t = texture2D(tex, coord);
		}
		return t;
	#else
		return texture2D(tex, coord);
	#endif
}

vec2 CalculateParallaxCoord(in vec2 coord, in vec3 viewVector) {
	vec2 parallaxCoord = coord.st;
	const int maxSteps = 112;
	vec3 stepSize = vec3(0.002f, 0.002f, 0.2f);

	float parallaxDepth = 1.0f;

    // perform a stronger parallax mapping for leaves
	if (materialIDs > 2.5f && materialIDs < 3.5f) {
		parallaxDepth = 2.0f;
    }

	stepSize.xy *= parallaxDepth;


	float heightmap = GetTexture(normals, coord.st).a;

	vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

	if (heightmap < 1.0f) {
		vec3 step = viewVector * stepSize;
		float distAngleWeight = ((distance * 0.6f) * (2.1f - viewVector.z)) / 16.0;
		step *= distAngleWeight;
		step *= 2.0f;

		float sampleHeight = heightmap;

		for (int i = 0; sampleHeight < pCoord.z && i < 240; ++i) {
		    pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 1.0 * distAngleWeight / (-viewVector.z + 0.05)), 0.0, 1.0));
			pCoord.z += step.z;
			sampleHeight = GetTexture(normals, OffsetCoord(coord.st, pCoord.st, 0)).a;
        }
        parallaxCoord.xy = OffsetCoord(coord.st, pCoord.st, 0);
	}

	return parallaxCoord;
}

void main() {
	vec4 modelView = (gl_ModelViewMatrix * vertexPos);

	vec3 viewVector = normalize(tbnMatrix * modelView.xyz);
		 viewVector.x /= 2.0f;
		 viewVector = normalize(viewVector);

	vec2 parallaxCoord = texcoord.st;
	#ifdef PARALLAX
		if (distance < 50.0f)
		 parallaxCoord = CalculateParallaxCoord(texcoord.st, viewVector);
	#endif

	float height = GetTexture(normals, parallaxCoord).a;

	// R: smoothness
	// G: 
	// B: Metalness
	vec4 spec = GetTexture(specular, parallaxCoord.st);
	vec4 specs = texture2D(specular, parallaxCoord.st);

	float wet = GetModulatedRainSpecular(worldPosition.xyz);

#ifdef OLD_SPECULAR
	float wetAngle = dot(worldNormal, vec3(0.0f, 1.0f, 0.0f)) * 0.5f + 0.5f;

	if (abs(materialIDs - 20.0f) < 0.1f || abs(materialIDs - 21.0f) < 0.1f) {
	} else {
		 specs.g += max(0.0f, clamp((wet * 1.0f + 0.2f), 0.0f, 1.0f) - (1.0f - wetness) * 1.0f);
		 specs.r += max(0.0f, (wet) - (1.0f - wetness) * 1.0f) * wetness;
	}
#endif

#ifdef NEW_SPECULAR
	float wetAngle = dot(worldNormal, vec3(0.0f, 1.0f, 0.0f)) * 0.5f + 0.5f;
	wet *= wetAngle;

	if (abs(materialIDs - 20.0f) < 0.1f || abs(materialIDs - 21.0f) < 0.1f) {
		spec.g = 0.0f;
	} else {
		wet = clamp(wet * 1.5f - 0.2f, 0.0f, 1.0f);
		spec.g *= max(0.0f, clamp((wet * 1.0f + 0.2f), 0.0f, 1.0f) - (1.0f - wetness) * 1.0f);
		spec.r += max(0.0f, (wet) - (1.0f - wetness) * 1.0f) * wetness;
	}
#endif

	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);

	//Separate lightmap types
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	lightmap.b = pow(lightmap.b, 1.0f);
	lightmap.r = pow(lightmap.r, 3.0f);

	float wetfactor = clamp(lightmap.b * 1.05f - 0.9f, 0.0f, 0.1f) / 0.1f;
	 	  wetfactor *= wetness;

	 spec.g *= wetfactor;

#ifdef OLD_SPECULAR
	 specs.g *= wetfactor;
#endif

	vec4 frag2;

	if (distance < bump_distance) {
		vec3 bump = GetTexture(normals, parallaxCoord.st).rgb * 2.0f - 1.0f;

		float bumpmult = clamp(bump_distance * fademult - distance * fademult, 0.0f, 1.0f) * NORMAL_MAP_MAX_ANGLE;
	    bumpmult *= 1.0f - (clamp(spec.g * 1.0f - 0.0f, 0.0f, 1.0f) * 0.97f);

		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

		frag2 = vec4(bump * tbnMatrix * 0.5 + 0.5, 1.0);
	} else {
		frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);
	}

	//Diffuse
	vec4 albedo = GetTexture(texture, parallaxCoord.st) * color;
	vec3 upVector = normalize(upPosition);
	float darkFactor = clamp(spec.g, 0.0f, 0.2f) / 0.2f;

	albedo.rgb = pow(albedo.rgb, vec3(mix(1.0f, 1.25f, darkFactor)));

	float mats_1 = materialIDs;
		  mats_1 += 0.1f;

	gl_FragData[0] = albedo;

	//Depth
	gl_FragData[1] = vec4(mats_1/255.0f, lightmap.r, lightmap.b, 1.0f);

	//normal
	gl_FragData[2] = frag2;

#ifdef SPECULARITY
	//specularity
	#ifdef NEW_SPECULAR
	// R: metalness
	// G: smoothness
	gl_FragData[3] = vec4(spec.b, spec.r + wetfactor, 0.0f, 1.0f);
	#endif
	#ifdef OLD_SPECULAR
	gl_FragData[4] = vec4(specs.r + specs.g, specs.b, 0.0f, 1.0f);
	#endif
#endif
}
