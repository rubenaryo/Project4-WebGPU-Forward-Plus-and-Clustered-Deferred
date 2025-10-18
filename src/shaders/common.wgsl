// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

// 2: you may want to create a ClusterSet struct similar to LightSet
struct Cluster
{
    numLights: u32,
    lights: array<u32, ${maxLightsPerCluster}>
}

struct ClusterSet
{
    count: u32,
    clusters: array<Cluster>
}

struct CameraUniforms {
    // 1.3: add an entry for the view proj mat (of type mat4x4f)
    view: mat4x4f,
    viewProj: mat4x4f,
    invProj: mat4x4f,
    resolution: vec2f,
    near: f32,
    far: f32
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32, radius: f32) -> f32 {
    return clamp(1.f - pow(distance / radius, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f, radius: f32) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight, radius);
}