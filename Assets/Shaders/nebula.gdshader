shader_type canvas_item;

uniform sampler2D noise_texture; // A Perlin noise texture
uniform vec2 speed1 = vec2(0.02, 0.01); // Speed of first layer
uniform vec2 speed2 = vec2(-0.015, 0.02); // Speed of second layer
uniform vec4 color1 = vec4(0.2, 0.4, 1.0, 1); // Blueish nebula color
uniform vec4 color2 = vec4(0.5, 0.2, 0.7, 1); // Purple-pink nebula color
uniform float contrast = 20.0; // Contrast adjustment
uniform float brightness = 1; // Brightness adjustment

const vec2 TARGET_RES = vec2(320.0, 180.0); // Target resolution

void fragment() {
	vec2 screen_texel_size = SCREEN_PIXEL_SIZE; // Size of one screen pixel in UV space
    vec2 pixel_size = screen_texel_size * TARGET_RES; // Adjusted pixelation scale

    // Snap UVs to match the target resolution
    vec2 pixel_uv = floor(UV * pixel_size) / pixel_size;

    vec2 uv1 = pixel_uv + TIME * speed1;
    vec2 uv2 = pixel_uv + TIME * speed2;
	
    //vec2 uv1 = UV + TIME * speed1;
    //vec2 uv2 = UV + TIME * speed2;
    
    float noise1 = texture(noise_texture, uv1).r;
    float noise2 = texture(noise_texture, uv2).r;
    
    // Adjust contrast and brightness
    noise1 = pow(noise1, contrast) * brightness;
    noise2 = pow(noise2, contrast) * brightness;
	
	float binary_noise = step(0.5, noise2);  // 0 or 1
    
    vec4 layer1 = color1 * noise1;
    vec4 layer2 = color2 * noise2;

    // Blend the two layers additively
    COLOR = layer1 + layer2;
}
