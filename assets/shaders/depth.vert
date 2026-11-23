#version 330 core

// same as max_joints in Mesh.zig
const int MAX_JOINTS = 64;

layout(location = 0) in vec3 vertexPosition;
layout(location = 4) in uvec4 vertexJoints;
layout(location = 5) in vec4 vertexWeights;

uniform mat4 MVP;

uniform bool hasSkin;
uniform mat4 jointMatrices[MAX_JOINTS];

// same as lit.vert
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
    gl_Position = MVP * skinMatrix() * vec4(vertexPosition, 1);
}
