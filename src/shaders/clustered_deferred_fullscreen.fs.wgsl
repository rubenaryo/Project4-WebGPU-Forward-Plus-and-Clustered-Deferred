@group(0) @binding(0) var<uniform> camUniforms: CameraUniforms;

@group(1) @binding(0) var<storage, read> lightSet: LightSet;
@group(1) @binding(1) var<storage, read> clusterSet: ClusterSet;
@group(1) @binding(2) var albedoTexture: texture_2d<f32>;
@group(1) @binding(3) var positionTexture: texture_2d<f32>;
@group(1) @binding(4) var normalTexture: texture_2d<f32>;
@group(1) @binding(5) var textureSampler: sampler;

struct FragmentInput
{
    @builtin(position) pos : vec4<f32>,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let uv = in.pos.xy / camUniforms.resolution.xy;
    let albedo = textureSample(albedoTexture, textureSampler, uv);
    let position = textureSample(positionTexture, textureSampler, uv);
    var normal = textureSample(normalTexture, textureSampler, uv);

    normal *= 2.0;
    normal -= vec4f(1.0);
    normal.w = 0.0;

    const numClustersX = ${clusterCountX};
    const numClustersY = ${clusterCountY};
    const numClustersZ = ${clusterCountZ};
    
    let clusterIdxX = u32(in.pos.x / f32(camUniforms.resolution.x) * f32(numClustersX));
    let clusterIdxY = u32(in.pos.y / f32(camUniforms.resolution.y) * f32(numClustersY));

    // Calculate Z using log depth formula
    let viewSpacePos = camUniforms.view * vec4f(position.xyz, 1.0);
    let viewDepth = viewSpacePos.z;
    let logDepth = log(-viewDepth / camUniforms.near) / log(camUniforms.far / camUniforms.near);

    let clusterIdxZ = clamp(u32(logDepth * numClustersZ), 0u, u32(numClustersZ - 1u));
    
    // Only check lights that are in this cluster
    let clusterIndex = u32(clusterIdxX + (clusterIdxY * numClustersX) + clusterIdxZ * (numClustersX * numClustersY));
    let numLights = u32(clusterSet.clusters[clusterIndex].numLights);

    const AMBIENT_LIGHT = 0.00;
    var totalLightContrib = vec3f(AMBIENT_LIGHT);
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        
        let mainLightIndex = clusterSet.clusters[clusterIndex].lights[lightIdx];
        let light = lightSet.lights[mainLightIndex];
        totalLightContrib += calculateLightContrib(light, position.xyz, normalize(normal.xyz));
    }

    var finalColor = albedo.rgb * totalLightContrib;
    return vec4f(finalColor, 1.0);
}