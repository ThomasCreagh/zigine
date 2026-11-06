#version 330 core

// Input
layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexColor;
layout(location = 2) in vec3 vertexNormal;

// Output data, to be interpolated for each fragment
out vec3 color;
out vec3 worldPosition;
out vec3 worldNormal;
out vec4 lightSpacePosition;

uniform mat4 MVP;
uniform mat4 model;
uniform mat4 lightVP;

void main() {
    // Transform vertex
    gl_Position =  MVP * vec4(vertexPosition, 1);

    // Pass vertex color to the fragment shader
    color = vertexColor;

    // World-space geometry
    vec4 world = model * vec4(vertexPosition, 1);
    worldPosition = world.xyz;
    worldNormal = mat3(transpose(inverse(model))) * vertexNormal;

    // Position as seen from the light, for the shadow map lookup
    lightSpacePosition = lightVP * world;
}
