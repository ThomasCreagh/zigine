#version 330 core

in vec2 uv;
in vec3 worldPosition;
in vec3 worldNormal;
in vec4 lightSpacePosition;

out vec3 finalColor;

uniform vec3 lightPosition;
uniform vec3 lightIntensity;
uniform sampler2D shadowMap;
uniform bool hasLight;
uniform bool hasShadow;

uniform vec3 diffuseColour;
uniform sampler2D diffuseTexture;
uniform bool hasDiffuseTexture;

float calculateShadow(vec4 lightSpace) {
    if (lightSpace.w <= 0.0) {
        return 1.0;
    }
    vec3 ndc = lightSpace.xyz / lightSpace.w;
    vec3 shadowCoords = ndc * 0.5 + 0.5;
    vec2 shadowUV = shadowCoords.xy;
    float depth = shadowCoords.z;
    if (depth > 1.0) {
        return 1.0;
    }
    float existingDepth = texture(shadowMap, shadowUV).r;
    if (depth >= existingDepth + 1e-3) {
        return 0.2;
    }
    return 1.0;
}

void main()
{
    vec3 albedo = diffuseColour;
    if (hasDiffuseTexture) {
        albedo *= texture(diffuseTexture, uv).rgb;
    }

    if (!hasLight) {
        finalColor = albedo;
        return;
    }

    vec3 N = normalize(worldNormal);
    vec3 toLight = lightPosition - worldPosition;
    float r = length(toLight);
    vec3 L = normalize(toLight);
    float cosine = max(dot(N, L), 0.0);
    float shadow = hasShadow ? calculateShadow(lightSpacePosition) : 1.0;
    vec3 litColour = shadow * albedo * lightIntensity * cosine / (r * r);
    vec3 toneMap = litColour / (1.0 + litColour);
    vec3 gamma = pow(toneMap, vec3(1.0 / 2.2));
    finalColor = gamma;
}
