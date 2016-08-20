/*!
 * \brief Holds a bunch of defines to give semantic names to all the framebuffer attachments
 */

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

#define COLOR_SAMPLE(coord, lod)        texture2DLod(gcolor, coord, lod)
#define DEPTH_SAMPLE(coord, lod)        texture2DLod(gdepthtex, coord, lod)
#define NORMAL_SAMPLE(coord, lod)       texture2DLod(gnormal, coord, lod)
#define MATERIAL_SAMPLE(coord, lod)     texture2DLod(gaux2, coord, lod)
#define SKY_PARAMS_SAMPLE(coord, lod)   texture2DLod(gaux3, coord, lod)
#define LIGHT_SAMPLE(coord, lod)        texture2DLod(composite, coord, lod)
#define GI_SAMPLE(coord, lod)           texture2DLod(gaux4, coord, lod)
#define SKY_SAMPLE(coord, lod)          texture2DLod(gdepth, coord, lod)
#define VL_SAMPLE(coord, lod)           texture2DLod(gaux1, coord, lod)

#define COLOR_SAMPLE(coord)             COLOR_SAMPLE(coord, 0)
#define DEPTH_SAMPLE(coord)             DEPTH_SAMPLE(coord, 0)
#define NORMAL_SAMPLE(coord)            NORMAL_SAMPLE(coord, 0)
#define MATERIAL_SAMPLE(coord)          MATERIAL_SAMPLE(coord, 0)
#define SKY_PARAMS_SAMPLE(coord)        SKY_PARAMS_SAMPLE(coord, 0)
#define LIGHT_SAMPLE(coord)             LIGHT_SAMPLE(coord, 0)
#define GI_SAMPLE(coord)                GI_SAMPLE(coord, 0)
#define SKY_SAMPLE(coord)               SKY_SAMPLE(coord, 0)
#define VL_SAMPLE(coord)                VL_SAMPLE(coord, 0)

#define COLOR_OUT                       gl_FragData[0]
#define SKY_OUT                         gl_FragData[1]
#define NORMAL_OUT                      gl_FragData[2]
#define LIGHT_OUT                       gl_FragData[3]
#define VL_OUT                          gl_FragData[4]
#define MATERIAL_OUT                    gl_FragData[5]
#define SKY_PARAMS_OUT                  gl_FragData[6]
#define GI_OUT                          gl_FragData[7]
