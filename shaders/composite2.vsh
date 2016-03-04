#version 120

#define SKY_DESATURATION 0.0f

varying vec4 texcoord;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float sunAngle;

varying vec3 lightVector;
varying vec3 upVector;

varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;


float CubicSmooth(in float x) {
	return x * x * (3.0f - 2.0f * x);
}

float clamp01(float x) {
	return clamp(x, 0.0, 1.0);
}


void main() {
	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	if (sunAngle < 0.5f) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}

	vec3 sunVector = normalize(sunPosition);

	upVector = normalize(upPosition);

	float LdotUp = dot(upVector, sunVector);
	float LdotDown = dot(-upVector, sunVector);

	timeNoon = 1.0 - pow(1.0 - clamp01(LdotUp), 3.2);
	timeSunriseSunset = 1.0 - timeNoon;
	timeMidnight = CubicSmooth(CubicSmooth(clamp01(LdotDown * 20.0f + 0.4)));
	timeMidnight = 1.0 - pow(1.0 - timeMidnight, 2.0);
	timeSunriseSunset *= 1.0 - timeMidnight;
	timeNoon *= 1.0 - timeMidnight;

	timeSkyDark = 0.0f;

	float horizonTime = CubicSmooth(clamp01((1.0 - abs(LdotUp)) * 7.0f - 6.0f));

	const float rayleigh = 0.02f;

	//colors for shadows/sunlight and sky
	vec3 sunrise_sun;
	sunrise_sun.r = 1.00;
	sunrise_sun.g = 0.58;
	sunrise_sun.b = 0.00;
	sunrise_sun *= 0.65f;

	vec3 sunrise_amb;
	sunrise_amb.r = 0.30 ;
	sunrise_amb.g = 0.595;
	sunrise_amb.b = 0.70 ;
 	sunrise_amb *= 1.0f;

	vec3 noon_sun;
	noon_sun.r = mix(1.00, 1.00, rayleigh);
	noon_sun.g = mix(1.00, 0.75, rayleigh);
	noon_sun.b = mix(1.00, 0.00, rayleigh);

	vec3 noon_amb;
	noon_amb.r = 0.00 ;
	noon_amb.g = 0.3  ;
	noon_amb.b = 0.999;

	vec3 midnight_sun;
	midnight_sun.r = 1.0;
	midnight_sun.g = 1.0;
	midnight_sun.b = 1.0;

	vec3 midnight_amb;
	midnight_amb.r = 0.0 ;
	midnight_amb.g = 0.23;
	midnight_amb.b = 0.99;

	colorSunlight = sunrise_sun * timeSunriseSunset  +  noon_sun * timeNoon  +  midnight_sun * timeMidnight;

	sunrise_amb = vec3(0.19f, 0.35f, 0.7f) * 0.15f;
	noon_amb    = vec3(0.11f, 0.24f, 0.99f);
	midnight_amb = vec3(0.005f, 0.01f, 0.02f) * 0.025f;

	colorSkylight = sunrise_amb * timeSunriseSunset  +  noon_amb * timeNoon  +  midnight_amb * timeMidnight;

	vec3 colorSkylight_rain = vec3(2.0, 2.0, 2.38) * 0.25f * (1.0f - timeMidnight * 0.9995f); //rain
	colorSkylight = mix(colorSkylight, colorSkylight_rain, rainStrength); //rain

	//Saturate sunlight colors
	colorSunlight = pow(colorSunlight, vec3(2.9f));
	colorSunlight *= 1.0f - horizonTime;

	//Make sunlight darker when not day time
	colorSunlight = mix(colorSunlight, colorSunlight * 0.5f, timeSunriseSunset);
	colorSunlight = mix(colorSunlight, colorSunlight * 1.0f, timeNoon);
	colorSunlight = mix(colorSunlight, colorSunlight * 0.00020f, timeMidnight);

	float colorSunlightLum = colorSunlight.r + colorSunlight.g + colorSunlight.b;
	colorSunlightLum /= 3.0f;

	colorSunlight = mix(colorSunlight, vec3(colorSunlightLum), vec3(rainStrength));
}
