#version 330 core
out vec4 fragColor;

in vec2 texCoordOut;

uniform sampler2D ourTexture;

void main() {
    vec4 color = texture(ourTexture, texCoordOut);
    float linear = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    fragColor = vec4(linear, linear, linear, 1.0);
}
