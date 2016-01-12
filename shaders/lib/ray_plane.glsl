#ifndef RAY_PLANE
#define RAY_PLANE

#ifdef RAY_PLANE
float doNothing_rayPlane;
#endif

/*
 * Has code for casting rays against a plane.
 *
 * This code is used pretty much exclusively by clouds.
 */

 struct Intersection {
 	vec3 pos;
 	float distance;
 	float angle;
 };

 Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane) {
 	float rayPlaneAngle = dot(ray.dir, plane.normal);

 	float planeRayDist = 100000000.0f;
 	vec3 intersectionPos = ray.dir * planeRayDist;

 	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f) {
 		planeRayDist = dot((plane.origin), plane.normal) / rayPlaneAngle;
 		intersectionPos = ray.dir * planeRayDist;
 		intersectionPos = -intersectionPos;

 		intersectionPos += cameraPosition.xyz;
 	}

 	Intersection i;

 	i.pos = intersectionPos;
 	i.distance = planeRayDist;
 	i.angle = rayPlaneAngle;

 	return i;
 }

 Intersection 	RayPlaneIntersection(in Ray ray, in Plane plane) {
 	float rayPlaneAngle = dot(ray.dir, plane.normal);

 	float planeRayDist = 100000000.0f;
 	vec3 intersectionPos = ray.dir * planeRayDist;

 	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f) {
 		planeRayDist = dot((plane.origin - ray.origin), plane.normal) / rayPlaneAngle;
 		intersectionPos = ray.origin + ray.dir * planeRayDist;
 	}

 	Intersection i;

 	i.pos = intersectionPos;
 	i.distance = planeRayDist;
 	i.angle = rayPlaneAngle;

 	return i;
 }

#endif
