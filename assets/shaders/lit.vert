#version 330 core

// Input
layout(location = 0) in vec3 vertexPosition;
layout(location = 2) in vec3 vertexNormal;
layout(location = 3) in vec2 vertexUV;

// Output data, to be interpolated for each fragment
out vec2 uv;
out vec3 worldPosition;
out vec3 worldNormal;
out vec4 lightSpacePosition;

uniform mat4 MVP;
uniform mat4 model;
uniform mat4 lightVP;

void main() {
    // Transform vertex
    gl_Position =  MVP * vec4(vertexPosition, 1);

    // Pass texture coordinates to the fragment shader
    uv = vertexUV;

    // World-space geometry
    vec4 world = model * vec4(vertexPosition, 1);
    worldPosition = world.xyz;
    worldNormal = mat3(transpose(inverse(model))) * vertexNormal;

    // Position as seen from the light, for the shadow map lookup
    lightSpacePosition = lightVP * world;
}
