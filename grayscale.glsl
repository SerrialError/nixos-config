#version 330

in vec2 texcoord;
uniform sampler2D tex;
uniform float opacity;

/* Provide declaration from picom's shader API */
vec4 default_post_processing(vec4 c);

/* entry point expected by newer picom versions */
vec4 window_shader() {
    /* If the shader gets texcoords as pixels, we may need textureSize; try this standard approach */
    vec2 texsize = textureSize(tex, 0);
    /* sample the texture using texcoord / texsize (some setups expect normalized coords) */
    vec4 color = texture(tex, texcoord / texsize, 0);

    /* luma formula (slightly different weights usually recommended) */
    float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

    /* preserve opacity from picom */
    vec4 outc = vec4(vec3(gray) * opacity, color.a * opacity);

    /* call picom's default post-processing (masks, rounded corners, etc.) */
    return default_post_processing(outc);
}
