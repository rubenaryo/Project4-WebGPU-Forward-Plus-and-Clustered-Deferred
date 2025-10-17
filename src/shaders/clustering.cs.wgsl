@group(${bindGroup_scene}) @binding(0) var<uniform> camUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

fn clipToView(clip : vec4f) -> vec4f
{
    let invProj = camUniforms.invProj;

    var view = invProj * clip;
    view = view / view.w;
    
    return view;
}

fn pixelToView(pixel: vec4f) -> vec4f
{
    let uv = (pixel.xy / camUniforms.resolution);
    let clip = vec4f(vec2f(uv.x, 1.0 - uv.y), pixel.z, pixel.w) * vec4f(2.0) - vec4f(1.0);
    return clipToView(clip);
}

fn lightIntersection(clusterMin: vec3f, clusterMax: vec3f, lightPosView: vec3f) -> bool
{
    // If the bounding region for the cluster has any contribution from the light, return true
    let lightRadius = ${lightRadius};

    let boundaryPoint = clamp(lightPosView, clusterMin, clusterMax);

    let lightToBoundary = lightPosView - boundaryPoint;
    let sqDist = f32(dot(lightToBoundary, lightToBoundary));
    
    // If the distance from the light to the closest point is less than the radius, this light affects the AABB.
    return sqDist < f32(lightRadius * lightRadius);
}

@compute
@workgroup_size(${clusterWorkgroupDimX}, ${clusterWorkgroupDimY}, ${clusterWorkgroupDimZ})
fn main(@builtin(global_invocation_id) globalIdx: vec3u)
{
    const numClustersX = ${clusterCountX};
    const numClustersY = ${clusterCountY};
    const numClustersZ = ${clusterCountZ};

    if (globalIdx.x >= numClustersX || globalIdx.y >= numClustersY || globalIdx.z >= numClustersZ)
    {
        return;
    }

    // 3D -> 1D index
    let clusterIndex = globalIdx.x + (globalIdx.y * numClustersX) + globalIdx.z * (numClustersX * numClustersY);

    let resolution = camUniforms.resolution;
    let tileSizeX = resolution.x / numClustersX;
    let tileSizeY = resolution.y / numClustersY;

    // In Pixel Space
    let clusterMinX = f32(globalIdx.x) * tileSizeX;
    let clusterMaxX = f32(globalIdx.x+1) * tileSizeX;

    let clusterMinY = f32(globalIdx.y) * tileSizeY;
    let clusterMaxY = f32(globalIdx.y+1) * tileSizeY;

    let clusterMinXMinY_pixel = vec4f(clusterMinX, clusterMinY, -1.0, 1.0);
    let clusterMaxXMaxY_pixel = vec4f(clusterMaxX, clusterMaxY, -1.0, 1.0);

    // Convert to View space
    let clusterMin_view = pixelToView(clusterMinXMinY_pixel).xyz;
    let clusterMax_view = pixelToView(clusterMaxXMaxY_pixel).xyz;

    // Compute z bounds by log depth
    let near = camUniforms.near;
    let far = camUniforms.far;
    let clusterNear = -near * pow(far/near, f32(globalIdx.z)   / numClustersZ);
    let clusterFar  = -near * pow(far/near, f32(globalIdx.z+1) / numClustersZ);

    let minPointNear = clusterMin_view * (clusterNear / clusterMin_view.z);
    let minPointFar  = clusterMin_view * (clusterFar  / clusterMin_view.z);
    let maxPointNear = clusterMax_view * (clusterNear / clusterMax_view.z);
    let maxPointFar  = clusterMax_view * (clusterFar  / clusterMax_view.z);

    let clusterMin = min(min(minPointNear, minPointFar),min(maxPointNear, maxPointFar));
    let clusterMax = max(max(minPointNear, minPointFar),max(maxPointNear, maxPointFar));

    // Iterate over all the lights and determine if they would affect this cluster
    clusterSet.clusters[clusterIndex].numLights = 0u;
    var numLightsInCluster = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights && numLightsInCluster < ${maxLightsPerCluster}; lightIdx++) 
    {
        let light = lightSet.lights[lightIdx];
        let lightPosView = camUniforms.view * vec4(light.pos, 1.0);

        if (lightIntersection(clusterMin, clusterMax, lightPosView.xyz))
        {
            // This light affects the cluster
            clusterSet.clusters[clusterIndex].lights[numLightsInCluster] = lightIdx;
            numLightsInCluster++;
        }
    }
    clusterSet.clusters[clusterIndex].numLights = numLightsInCluster;
}
