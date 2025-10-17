// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).

@group(${bindGroup_scene}) @binding(0) var<uniform> camUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput, @builtin(position) fragCoord: vec4f) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5) 
    {
        discard;
    }

    const numClustersX = ${clusterCountX};
    const numClustersY = ${clusterCountY};
    const numClustersZ = ${clusterCountZ};
    
    let clusterIdxX = u32(f32(fragCoord.x) / f32(camUniforms.resolution.x) * f32(numClustersX));
    let clusterIdxY = u32(f32(fragCoord.y) / f32(camUniforms.resolution.y) * f32(numClustersY));

    // Calculate Z using log depth formula
    let viewSpacePos = camUniforms.view * vec4f(in.pos, 1.0);
    let viewDepth = viewSpacePos.z;
    let logDepth = log(-viewDepth / camUniforms.near) / log(camUniforms.far / camUniforms.near);

    let clusterIdxZ = clamp(u32(logDepth * numClustersZ), 0, u32(numClustersZ) - 1u);
    
    // Only check lights that are in this cluster
    let clusterIndex = u32(clusterIdxX + (clusterIdxY * numClustersX) + clusterIdxZ * (numClustersX * numClustersY));
    let numLights = u32(clusterSet.clusters[clusterIndex].numLights);

    const AMBIENT_LIGHT = 0.08;
    var totalLightContrib = vec3f(AMBIENT_LIGHT);
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        
        let mainLightIndex = clusterSet.clusters[clusterIndex].lights[lightIdx];
        let light = lightSet.lights[mainLightIndex];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
