#version 330 core

in vec3 color;
in vec3 worldPosition;
in vec3 worldNormal;

out vec3 finalColor;

uniform vec3 lightPosition;
uniform vec3 lightIntensity;

void main()
{
        // finalColor = color;
        finalColor = worldNormal * 0.5 + 0.5;
        // TODO: lighting, tone mapping, gamma correction
}
