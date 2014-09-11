#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

varying float smoothness_in;
varying float reflectivity_in;

varying float isEmissive;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    smoothness_in = 0.75;
    reflectivity_in = 0.75;

	if(    mc_Entity.x ==   1.0 //stone
            || mc_Entity.x ==  14.0 //gold ore
            || mc_Entity.x ==  15.0 //iron ore
            || mc_Entity.x ==  16.0 //coal ore
            || mc_Entity.x ==  21.0 //lapiz lazuli ore
            || mc_Entity.x ==  56.0 //diamond ore
            || mc_Entity.x ==  73.0 //redstone ore
            || mc_Entity.x == 129.0 //emerald ore
            || mc_Entity.x ==  23.0 //dispenser
            || mc_Entity.x ==  29.0 //sticky piston
            || mc_Entity.x ==  44.0 //slabs
            || mc_Entity.x ==  48.0 //moss stone
            || mc_Entity.x ==  69.0 //lever
            || mc_Entity.x ==  70.0 //stone pressure plate
            || mc_Entity.x ==  77.0 //button
            || mc_Entity.x ==  93.0 //redstone repeater
            || mc_Entity.x ==  98.0 //monster egg
      ) {
        smoothness_in = 0.6;
        reflectivity_in = 0.5;
    } else if( mc_Entity.x ==  98.0 //stone bircks
            ) {
        smoothness_in = 0.8;
        reflectivity_in = 0.5;
    } else if( mc_Entity.x ==   4.0 //cobblestone
            || mc_Entity.x ==  61.0 //furnace
            || mc_Entity.x ==  62.0 //lit furnace
            || mc_Entity.x ==  67.0 //stone stairs
            ) {
        smoothness_in = 0.55;
        reflectivity_in = 0.5;
    } else if( mc_Entity.x ==   2.0 //grass
            || mc_Entity.x ==   3.0 //dirt
            || mc_Entity.x ==   5.0 //wood planks
            || mc_Entity.x ==  17.0 //wood
            || mc_Entity.x ==  32.0 //dead brush
            || mc_Entity.x == 110.0 //mycelium
            || mc_Entity.x == 162.0 //other wood ugh
            || mc_Entity.x ==  19.0 //sponge
            || mc_Entity.x ==  47.0 //bookshelf
            || mc_Entity.x ==  50.0 //torch
            || mc_Entity.x ==  53.0 //wood stairs
            || mc_Entity.x ==  54.0 //chest
            || mc_Entity.x ==  55.0 //redstone wire
            || mc_Entity.x ==  58.0 //crafting table
            || mc_Entity.x ==  60.0 //farmland
            || mc_Entity.x ==  64.0 //wooden door
            || mc_Entity.x ==  65.0 //ladder
            || mc_Entity.x ==  66.0 //rails
            || mc_Entity.x ==  72.0 //wood pressure plate
            || mc_Entity.x ==  85.0 //fence
            || mc_Entity.x == 131.0 //tripwire hook
            || mc_Entity.x == 132.0 //tripwire
      ) {
        smoothness_in = 0.5;
        reflectivity_in = 0.9;
    } else if( mc_Entity.x ==   7.0 //bedrock
	        || mc_Entity.x ==   6.0 //saplgin
            || mc_Entity.x ==  18.0 //leaves
            || mc_Entity.x ==  31.0 //grass
            || mc_Entity.x ==  37.0 //dandelion
            || mc_Entity.x ==  38.0 //poppy
            || mc_Entity.x ==  39.0 //brown mushroom
            || mc_Entity.x ==  40.0 //red muchroom
            || mc_Entity.x ==  81.0 //cactus
            || mc_Entity.x ==  83.0 //sugar cane
            || mc_Entity.x ==  86.0 //pumpkin
            || mc_Entity.x ==  99.0 //huge brown muchroom
            || mc_Entity.x == 100.0 //huge red muchroom
            || mc_Entity.x == 103.0 //melon
            || mc_Entity.x == 106.0 //vines
            || mc_Entity.x == 111.0 //lily pad
            || mc_Entity.x == 127.0 //cocoai
            || mc_Entity.x == 161.0 //other leaves ugh
            || mc_Entity.x == 175.0 //double plant
            || mc_Entity.x ==  30.0 //cobweb
            || mc_Entity.x ==  59.0 //wheat
            || mc_Entity.x == 141.0 //carrot
            || mc_Entity.x == 142.0 //wot's taters?
            ) {
        smoothness_in = 0.75;
        reflectivity_in = 0.8;
    } else if( mc_Entity.x ==  12.0 //sand
            || mc_Entity.x ==  78.0 //snow
            || mc_Entity.x ==  80.0 //snow block
            ) {
        smoothness_in = 0.55;
        reflectivity_in = 0.9;
    } else if( mc_Entity.x ==  13.0 //gravel
            ) {
        smoothness_in = 0.7;
        reflectivity_in = 0.5;
    } else if( mc_Entity.x ==  24.0 //sandstone
            || mc_Entity.x ==  82.0 //clay block
            || mc_Entity.x == 159.0 //stained clay
            || mc_Entity.x == 172.0 //hardened clay
            || mc_Entity.x ==  52.0 //monster spawner
            || mc_Entity.x ==  71.0 //iron door
            || mc_Entity.x == 101.0 //iron bars
            || mc_Entity.x == 118.0 //cauldron
            || mc_Entity.x == 120.0 //end portal
            || mc_Entity.x == 128.0 //sandstone stairs
            || mc_Entity.x == 140.0 //flower pot
            || mc_Entity.x ==  49.0 //obsidian
            ) {
        smoothness_in = 0.75;
        reflectivity_in = 0.9;
    } else if( mc_Entity.x ==  79.0 //ice
            ) {
        smoothness_in = 0.95;
        reflectivity_in = 1.0;
    } else if( mc_Entity.x ==  35.0 //wool
            || mc_Entity.x ==  46.0 //TNT
            ) {
        smoothness_in = 0.5;
        reflectivity_in = 0.2;
    } else if( mc_Entity.x ==  41.0 //gold block
            || mc_Entity.x ==   8.0 //water
            || mc_Entity.x == 102.0 //glass pane
            ) {
        smoothness_in = 1.0;
        reflectivity_in = 1.0;
    }

    isEmissive = 0.0;

    if(        mc_Entity.x ==  62.0 //furnace
            || mc_Entity.x ==  50.0 //torch
            || mc_Entity.x ==  55.0 //redstone wire
            || mc_Entity.x ==  10.0 //lava
            || mc_Entity.x ==  11.0 //also lava
            || mc_Entity.x ==  51.0 //fire
            || mc_Entity.x ==  74.0 //lit redstone ore
            || mc_Entity.x ==  76.0 //lit redstone torch
            || mc_Entity.x ==  59.0 //glowstone
            || mc_Entity.x == 138.0 //beacon
            || mc_Entity.x == 152.0 //redstone block
            || mc_Entity.x == 124.0 //lit redstone lamp
      ) {
        isEmissive = 1.0;
    }

    gl_Position = ftransform();

    normal = normalize( gl_NormalMatrix * gl_Normal );

    vec3 tangent = vec3( 0 );
    vec3 binormal = vec3( 0 );
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if( gl_Normal.x > 0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.x < -0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.y > 0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
    } else if( gl_Normal.y < -0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
    } else if( gl_Normal.z > 0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.z < -0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    }

    tbnMatrix = mat3( tangent.x, tangent.y, tangent.z,
                      binormal.x, binormal.y, binormal.z,
                      normal.x, normal.y, normal.z );
}
