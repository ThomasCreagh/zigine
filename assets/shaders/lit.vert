#version 330 core

// same as max_joints in Mesh.zig
const int MAX_JOINTS = 128;

layout(location = 0) in vec3 vertexPosition;
layout(location = 2) in vec3 vertexNormal;
layout(location = 3) in vec2 vertexUV;
layout(location = 4) in uvec4 vertexJoints;
layout(location = 5) in vec4 vertexWeights;

out vec2 uv;
out vec3 worldPosition;
out vec3 worldNormal;
out vec4 lightSpacePosition;

uniform mat4 MVP;
uniform mat4 model;
uniform mat4 lightVP;

uniform bool hasSkin;
uniform mat4 jointMatrices[MAX_JOINTS];

mat4 skinMatrix() {
    if (!hasSkin) {
        return mat4(1.0);
    }
    return vertexWeights.x * jointMatrices[vertexJoints.x] +
           vertexWeights.y * jointMatrices[vertexJoints.y] +
           vertexWeights.z * jointMatrices[vertexJoints.z] +
           vertexWeights.w * jointMatrices[vertexJoints.w];
}

void main() {
    mat4 skin = skinMatrix();
    vec4 position = skin * vec4(vertexPosition, 1);
    vec3 normal = mat3(skin) * vertexNormal;

    gl_Position =  MVP * position;

    uv = vertexUV;

    vec4 world = model * position;
    worldPosition = world.xyz;
    worldNormal = mat3(transpose(inverse(model))) * normal;

    lightSpacePosition = lightVP * world;
}
