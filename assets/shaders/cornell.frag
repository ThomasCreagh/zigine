#version 330 core

in vec3 color;
in vec3 worldPosition;
in vec3 worldNormal;
in vec4 lightSpacePosition;

out vec3 finalColor;

uniform vec3 lightPosition;
uniform vec3 lightIntensity;
uniform sampler2D shadowMap;

float calculateShadow(vec4 lightSpace) {
    if (lightSpace.w <= 0.0) {
        return 1.0;
    }
    vec3 ndc = lightSpace.xyz / lightSpace.w;
    vec3 shadowCoords = ndc * 0.5 + 0.5;
    vec2 uv = shadowCoords.xy;
    float depth = shadowCoords.z;
    if (depth > 1.0) {
        return 1.0;
    }
    float existingDepth = texture(shadowMap, uv).r;
    if (depth >= existingDepth + 1e-3) {
        return 0.2;
    }
    return 1.0;
}

void main()
{
    //finalColor = color;
    //finalColor = worldNormal * 0.5 + 0.5;
    //finalColor = vec3(texture(shadowMap, gl_FragCoord.xy / vec2(1920.0, 1080.0)).r);

    vec3 N = normalize(worldNormal);
    vec3 toLight = lightPosition - worldPosition;
    float r = length(toLight);
    vec3 L = normalize(toLight);
    float cosine = max(dot(N, L), 0.0);
    float shadow = calculateShadow(lightSpacePosition);
    vec3 litColour = shadow * color * lightIntensity * cosine / (r * r);
    vec3 toneMap = litColour / (1.0 + litColour);
    vec3 gamma = pow(toneMap, vec3(1.0 / 2.2));
    finalColor = gamma;
}

