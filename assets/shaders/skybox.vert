#version 330 core
layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexUV;

uniform mat4 VP;
out vec2 uv;

void main() {
    vec4 pos = VP * vec4(vertexPosition, 1.0);
    gl_Position = pos.xyww; // z/w == 1.0 -> always at the far plane
    uv = vertexUV;
}
