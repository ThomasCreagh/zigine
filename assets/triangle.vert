#version 330 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 colours;

out vec3 fragColours;

uniform mat4 mvp;

void main() {
	gl_Position = mvp * vec4(vertexPosition, 1.0);
	fragColours = colours;
}
