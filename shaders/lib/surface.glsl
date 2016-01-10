#ifndef SURFACE
#define SURFACE

#ifdef SURFACE
float doNothing_surface;
#endif

struct DiffuseAttributesStruct {			//Diffuse surface shading attributes
	float roughness;			//Roughness of surface. More roughness will use Oren Nayar reflectance.
	float translucency; 		//How translucent the surface is. Translucency represents how much energy will be transfered through the surface
	vec3  translucencyColor; 	//Color that will be multiplied with sunlight for backsides of translucent materials.
};

struct SpecularAttributesStruct {			//Specular surface shading attributes
	float specularity;			//How reflective a surface is
	float extraSpecularity;		//Additional reflectance for specular reflections from sun only
	float glossiness;			//How smooth or rough a specular surface is
	float metallic;				//from 0 - 1. 0 representing non-metallic, 1 representing fully metallic.
	float gain;					//Adjust specularity further
	float base;					//Reflectance when the camera is facing directly at the surface normal. 0 allows only the fresnel effect to add specularity
	float fresnelPower; 		//Curve of fresnel effect. Higher values mean the surface has to be viewed at more extreme angles to see reflectance
};

struct SkyStruct { 				//All sky shading attributes
	vec3 	albedo;				//Diffuse texture aka "color texture" of the sky
	vec3 	tintColor; 			//Color that will be multiplied with the sky to tint it
	vec3 	sunglow;			//Color that will be added to the sky simulating scattered light arond the sun/moon
	vec3 	sunSpot; 			//Actual sun surface
};

struct WaterStruct {
	vec3 albedo;
};

struct MaskStruct {

	float matIDs;

	float sky;
	float land;
	float grass;
	float leaves;
	float ice;
	float hand;
	float translucent;
	float glow;
	float sunspot;
	float goldBlock;
	float ironBlock;
	float diamondBlock;
	float emeraldBlock;
	float sand;
	float sandstone;
	float stone;
	float cobblestone;
	float wool;
	float clouds;

	float torch;
	float lava;
	float glowstone;
	float fire;

	float water;

	float volumeCloud;

};

struct CloudsStruct {
	vec3 albedo;
};

struct AOStruct {
	float skylight;
	float scatteredUpLight;
	float bouncedSunlight;
	float scatteredSunlight;
	float constant;
};

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct Plane {
	vec3 normal;
	vec3 origin;
};

struct SurfaceStruct { 			//Surface shading properties, attributes, and functions

	//Attributes that change how shading is applied to each pixel
	DiffuseAttributesStruct  diffuse;			//Contains all diffuse surface attributes
	SpecularAttributesStruct specular;			//Contains all specular surface attributes

	SkyStruct 	    sky;			//Sky shading attributes and properties
	WaterStruct 	water;			//Water shading attributes and properties
	MaskStruct 		mask;			//Material ID Masks
	CloudsStruct 	clouds;
	AOStruct 		ao;				//ambient occlusion

	//Properties that are required for lighting calculation
	vec3 	albedo;					//Diffuse texture aka "color texture"
	vec3 	normal;					//Screen-space surface normals
	float 	depth;					//Scene depth
	float   linearDepth; 			//Linear depth

	vec4	screenSpacePosition;	//Vector representing the screen-space position of the surface
	vec4	screenSpacePosition1;	//Vector representing the screen-space position of the surface
	vec4	screenSpacePositionSolid;	//Vector representing the screen-space position of the surface
	vec3 	viewVector; 			//Vector representing the viewing direction
	vec3 	lightVector; 			//Vector representing sunlight direction
	Ray 	viewRay;
	vec3 	worldLightVector;
	vec3  	upVector;				//Vector representing "up" direction
	float 	NdotL; 					//dot(normal, lightVector). used for direct lighting calculation
	//vec3 	debug;

	float 	shadow;
	float 	cloudShadow;

	float 	cloudAlpha;
} surface;

#endif
