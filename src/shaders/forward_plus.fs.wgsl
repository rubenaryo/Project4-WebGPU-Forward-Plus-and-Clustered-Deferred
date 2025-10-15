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
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    let pixelR = f32(fragCoord.x/camUniforms.resolution.x);
    let pixelG = f32(fragCoord.y/camUniforms.resolution.y);
    var pixelColor = vec4(pixelR, pixelG, 1.0, 1.0);
    
    const numClustersX = ${clusterCountX};
    const numClustersY = ${clusterCountY};
    const numClustersZ = ${clusterCountZ};

    let viewSpacePos = camUniforms.viewProj * vec4f(in.pos, 1.0);
    var clipSpacePos = viewSpacePos / viewSpacePos.w; // [-1, 1]

    // Convert to [0, numClustersX/Y/Z]
    clipSpacePos += vec4f(1.0, 1.0, 1.0, 0.0); // [0, 2]
    clipSpacePos *= vec4f(0.5, 0.5, 0.5, 1.0); // [0, 1]
    clipSpacePos *= vec4f(f32(numClustersX), f32(numClustersY), f32(numClustersZ), 1.0);
    
    let clusterIdxX = floor(clipSpacePos.x);
    let clusterIdxY = floor(clipSpacePos.y);
    let clusterIdxZ = 0.0;

    let tileSizeX = camUniforms.resolution.x / numClustersX;
    let tileSizeY = camUniforms.resolution.y / numClustersY;
    
    let clusterIndex = u32(clusterIdxX + (clusterIdxY * numClustersX) + clusterIdxZ * (numClustersX * numClustersY));

    let clusterColor3f = clusterSet.clusters[clusterIndex].color;

    var clusterColor = vec4(clusterColor3f.x, clusterColor3f.y, clusterColor3f.z, 1.0);
    return clusterColor;

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
