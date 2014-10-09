#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

varying float smoothness_in;
varying float metalness_in;

varying float isEmissive;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    smoothness_in = 0.75;
    metalness_in = 0.0;

    //process all non-metals first, they're the most common

    //smooth stone, brick
    /*if(        mc_Entity.x ==   1.0 //stone
            || mc_Entity.x ==  13.0 //gravel
            || mc_Entity.x ==  23.0 //dispenser
            || mc_Entity.x ==  29.0 //sticky piston
            || mc_Entity.x ==  33.0 //piston
            || mc_Entity.x ==  43.0 //double stone slab
            || mc_Entity.x ==  44.0 //stone slab
            || mc_Entity.x ==  45.0 //brick block
            || mc_Entity.x ==  61.0 //furnace
            || mc_Entity.x ==  62.0 //lit furnace
            || mc_Entity.x ==  70.0 //stone pressure plate
            || mc_Entity.x ==  77.0 //stone button
            || mc_Entity.x ==  93.0 //redstone repeater
            || mc_Entity.x ==  94.0 //lit restone repeater
            || mc_Entity.x ==  97.0 //monster egg
            || mc_Entity.x ==  98.0 //stone brick
            || mc_Entity.x == 180.0 //brick stairs
            || mc_Entity.x == 109.0 //stone brick stairs
            || mc_Entity.x == 149.0 //redstone comparator
            || mc_Entity.x == 150.0 //lit comparator
            || mc_Entity.x ==  14.0 //gold ore
            || mc_Entity.x ==  15.0 //iron ore
            || mc_Entity.x ==  16.0 //coal ore
            || mc_Entity.x ==  73.0 //redstone ore
            || mc_Entity.x ==  74.0 //lit redstone ore
            || mc_Entity.x == 129.0 //emerald ore
            || mc_Entity.x == 158.0 //dropper
        ) {
        smoothness_in = 0.5;

    //dirt
    } else if( mc_Entity.x ==   2.0 //grassy dirt
            || mc_Entity.x ==   3.0 //grassless dirt
            || mc_Entity.x ==  60.0 //farmland
            || mc_Entity.x ==  88.0 //soul sand
            || mc_Entity.x ==  46.0 //tnt
            || mc_Entity.x ==  83.0 //clay
            || mc_Entity.x == 110.0 //mycelium
            || mc_Entity.x == 140.0 //flower pot
            || mc_Entity.x == 159.0 //stianed hardened clay
            || mc_Entity.x == 172.0 //hardened clay

        ) {
        smoothness_in = 0.1;

    //cobblestone
    } else if( mc_Entity.x ==   4.0 //cobblestone
            || mc_Entity.x ==  48.0 //mossy cobblestone
            || mc_Entity.x ==  67.0 //stone stairs
            || mc_Entity.x ==  69.0 //lever
            || mc_Entity.x == 117.0 //brewing stand
            || mc_Entity.x == 139.0 //cobblestone wall
        ) {
        smoothness_in = 0.4;

    //wood
    } else if( mc_Entity.x ==   5.0 //wooden planks
            || mc_Entity.x ==   6.0 //sapling
            || mc_Entity.x ==  17.0 //log
            || mc_Entity.x ==  19.0 //sponge
            || mc_Entity.x ==  34.0 //piston head
            || mc_Entity.x ==  47.0 //bookshelf
            || mc_Entity.x ==  50.0 //torch
            || mc_Entity.x ==  35.0 //oak stairs
            || mc_Entity.x ==  54.0 //chest
            || mc_Entity.x ==  58.0 //crafting table
            || mc_Entity.x ==  63.0 //sign
            || mc_Entity.x ==  64.0 //oak door
            || mc_Entity.x ==  65.0 //ladder
            || mc_Entity.x ==  68.0 //wall sign (why is this different?)
            || mc_Entity.x ==  72.0 //wooden pressure plate
            || mc_Entity.x ==  75.0 //unlit restone torch
            || mc_Entity.x ==  76.0 //lit redstone torch
            || mc_Entity.x ==  85.0 //fence
            || mc_Entity.x ==  96.0 //trapdoor
            || mc_Entity.x == 107.0 //fence gate
            || mc_Entity.x == 125.0 //double wooden slab
            || mc_Entity.x == 126.0 //wooden slab
            || mc_Entity.x == 131.0 //tripwire hook
            || mc_Entity.x == 134.0 //spruce stairs
            || mc_Entity.x == 135.0 //birch stairs
            || mc_Entity.x == 136.0 //jungle wood stairs
            || mc_Entity.x == 143.0 //wooden button
            || mc_Entity.x == 146.0 //trapped chest
            || mc_Entity.x == 162.0 //log2 (ew)
            || mc_Entity.x == 163.0 //acacia stairs
            || mc_Entity.x == 164.0 //dark oak stairs
            || mc_Entity.x == 173.0 //block of coal (from my stocking)
            || mc_Entity.x == 183.0 //spruce fence gate
            || mc_Entity.x == 184.0 //birch fence gate
            || mc_Entity.x == 185.0 //jungle fence gate
            || mc_Entity.x == 186.0 //dark oak fence gate
            || mc_Entity.x == 187.0 //acacia fence gate
            || mc_Entity.x == 188.0 //spruce fence gate
            || mc_Entity.x == 189.0 //birch fence gate
            || mc_Entity.x == 190.0 //jungle_fence
            || mc_Entity.x == 191.0 //dark oak fence
            || mc_Entity.x == 192.0 //acacia fence
            || mc_Entity.x == 193.0 //spruce door
            || mc_Entity.x == 194.0 //birch door
            || mc_Entity.x == 195.0 //jungle door
            || mc_Entity.x == 196.0 //acacia door
            || mc_Entity.x == 197.0 //dark oak door
        ) {
        smoothness_in = 0.05;

    //shiny
    } else if( mc_Entity.x ==   7.0 //bedrock
            || mc_Entity.x ==   8.0 //flowing water
            || mc_Entity.x ==   9.0 //water
            || mc_Entity.x ==  20.0 //glass
            || mc_Entity.x ==  22.0 //lapiz block
            || mc_Entity.x ==  25.0 //note block
            || mc_Entity.x ==  41.0 //gold block
            || mc_Entity.x ==  49.0 //obsidian
            || mc_Entity.x ==  57.0 //diamond block
            || mc_Entity.x ==  79.0 //ice
            || mc_Entity.x ==  84.0 //jukobox
            || mc_Entity.x ==  95.0 //stained glass
            || mc_Entity.x == 102.0 //glas pane
            || mc_Entity.x == 116.0 //enchanting table
            || mc_Entity.x == 122.0 //dragon egg
            || mc_Entity.x == 130.0 //ender chest
            || mc_Entity.x == 133.0 //emerald block
            || mc_Entity.x == 137.0 //command block
            || mc_Entity.x == 138.0 //beacon
            || mc_Entity.x == 147.0 //light pressure plate
            || mc_Entity.x == 152.0 //redstone block
            || mc_Entity.x == 155.0 //quartx block
            || mc_Entity.x == 156.0 //quartz stairs
            || mc_Entity.x == 160.0 //stained glass pane
            || mc_Entity.x == 165.0 //slime
            || mc_Entity.x == 169.0 //sea lantern
            || mc_Entity.x == 174.0 //packed ice
        ) {
        smoothness_in = 1.0;

    //sand, cloth
    } else if( mc_Entity.x ==  12.0 //sand
            || mc_Entity.x ==  24.0 //sandstone
            || mc_Entity.x ==  26.0 //bed
            || mc_Entity.x ==  35.0 //wool
            || mc_Entity.x ==  78.0 //snow layer
            || mc_Entity.x ==  80.0 //snow block
            || mc_Entity.x == 128.0 //sandstone stairs
            || mc_Entity.x == 179.0 //red sandstone
            || mc_Entity.x == 180.0 //red sandstone stairs
            || mc_Entity.x == 181.0 //double sandstone slab
            || mc_Entity.x == 182.0 //stone slab
        ) {
        smoothness_in = 0.2;

    //ores, iron
    } else if( mc_Entity.x ==  21.0 //lapis ore
            || mc_Entity.x ==  27.0 //golden rail
            || mc_Entity.x ==  28.0 //detector rail
            || mc_Entity.x ==  42.0 //iron block
            || mc_Entity.x ==  52.0 //mob spawner
            || mc_Entity.x ==  56.0 //diamond ore
            || mc_Entity.x ==  66.0 //rail
            || mc_Entity.x ==  71.0 //iron door
            || mc_Entity.x == 101.0 //iron bars
            || mc_Entity.x == 118.0 //cauldron
            || mc_Entity.x == 145.0 //anvil
            || mc_Entity.x == 148.0 //heavy pressure plate
            || mc_Entity.x == 154.0 //hopper
            || mc_Entity.x == 167.0 //iron trapdoor
        ) {
        smoothness_in = 0.9;
    
    //leaves
    } else if( mc_Entity.x ==  18.0 //leaves
            || mc_Entity.x ==  31.0 //tall grass
            || mc_Entity.x ==  32.0 //dead grass
            || mc_Entity.x ==  37.0 //dandelion
            || mc_Entity.x ==  38.0 //poppy
            || mc_Entity.x ==  39.0 //brown mushroom
            || mc_Entity.x ==  40.0 //red mushroom
            || mc_Entity.x ==  59.0 //wheat
            || mc_Entity.x ==  81.0 //cactus
            || mc_Entity.x ==  86.0 //pumpkin
            || mc_Entity.x ==  91.0 //lit pumpkin
            || mc_Entity.x ==  92.0 //cakes are leaves, right?
            || mc_Entity.x ==  99.0 //brown mushroom block
            || mc_Entity.x == 100.0 //reg mushroom block
            || mc_Entity.x == 103.0 //melon
            || mc_Entity.x == 104.0 //pumpkin stem
            || mc_Entity.x == 105.0 //melon stem
            || mc_Entity.x == 106.0 //vine
            || mc_Entity.x == 111.0 //lily pad
            || mc_Entity.x == 115.0 //nether wort
        ) {
        smoothness_in = 0.4;
    }

    //process the semi-metals (they are part metal and part not). They're not very common
    if(        mc_Entity.x ==  14.0 //gold ore
            || mc_Entity.x ==  15.0 //iron ore
            || mc_Entity.x ==  27.0 //gold rails
            || mc_Entity.x ==  28.0 //detector rails
            || mc_Entity.x ==  66.0 //rails
            || mc_Entity.x == 157.0 //activator rails
      ) {
        metalness_in = 0.5;
    } else if( mc_Entity.x ==  41.0 //gold block 
            || mc_Entity.x ==  71.0 //iron door
            || mc_Entity.x == 101.0 //iron bars
            || mc_Entity.x == 118.0 //cauldron
            || mc_Entity.x == 145.0 //anvil
            || mc_Entity.x == 148.0 //heavy pressure plate
            ) {
        metalness_in = 1.0;
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
            || mc_Entity.x ==  94.0 //lit repeater
            || mc_Entity.x == 138.0 //beacon
            || mc_Entity.x == 150.0 //lit comparator
            || mc_Entity.x == 152.0 //redstone block
            || mc_Entity.x == 124.0 //lit redstone lamp
            || mc_Entity.x == 169.0 //sea lantern
      ) {
        isEmissive = 1.0;
    }*/

    gl_Position = ftransform();

    normal = normalize( gl_NormalMatrix * gl_Normal );
    
    mat3 mvp3x3 = mat3( gl_ModelViewMatrix );

    vec3 tangent = vec3( 0 );
    vec3 binormal = vec3( 0 );
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if( gl_Normal.x > 0.5 ) {
        tangent  = normalize( mvp3x3 * vec3( 0,  0, 1 ) );
        binormal = normalize( mvp3x3 * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.x < -0.5 ) {
        tangent  = normalize( mvp3x3 * vec3( 0,  0, 1 ) );
        binormal = normalize( mvp3x3 * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.y > 0.5 ) {
        tangent  = normalize( mvp3x3 * vec3( 1,  0, 0 ) );
        binormal = normalize( mvp3x3 * vec3( 0,  0, 1 ) );
    } else if( gl_Normal.y < -0.5 ) {
        tangent  = normalize( mvp3x3 * vec3( 1,  0, 0 ) );
        binormal = normalize( mvp3x3 * vec3( 0,  0, 1 ) );
    } else if( gl_Normal.z > 0.5 ) {
        tangent  = normalize( mvp3x3 * vec3( 1,  0, 0 ) );
        binormal = normalize( mvp3x3 * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.z < -0.5 ) {
        tangent  = normalize( mvp3x3 * vec3( 1,  0, 0 ) );
        binormal = normalize( mvp3x3 * vec3( 0, -1, 0 ) );
    }

    tbnMatrix = mat3( tangent.x, tangent.y, tangent.z,
                      binormal.x, binormal.y, binormal.z,
                      normal.x, normal.y, normal.z );
}
