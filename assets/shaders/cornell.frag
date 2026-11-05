#version 330 core

in vec3 color;
in vec3 worldPosition;
in vec3 worldNormal;

out vec3 finalColor;

uniform vec3 lightPosition;
uniform vec3 lightIntensity;

void main()
{
    //finalColor = color;
    //finalColor = worldNormal * 0.5 + 0.5;

    vec3 N = normalize(worldNormal);
    vec3 toLight = lightPosition - worldPosition;
    float r = length(toLight);
    vec3 L = normalize(toLight);
    float cosine = max(dot(N, L), 0.0);
    vec3 litColour = color * lightIntensity * cosine / (r * r);
    vec3 toneMap = litColour / (1.0 + litColour);
    vec3 gamma = pow(toneMap, vec3(1.0 / 2.2));
    finalColor = gamma;
}
