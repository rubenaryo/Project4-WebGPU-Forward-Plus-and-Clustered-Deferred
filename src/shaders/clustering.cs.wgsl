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

fn lightIntersection(clusterMin: vec3f, clusterMax: vec3f, lightPosView: vec3f) -> bool
{
    // If the bounding region for the cluster has any contribution from the light, return true
    let lightRadius = ${lightRadius};

    let boundaryPoint = clamp(lightPosView, clusterMin, clusterMax);
    let toBoundaryPoint = boundaryPoint - lightPosView;
    let sqDist = dot(toBoundaryPoint, toBoundaryPoint);
    
    // If the distance from the light to the closest point is less than the radius, this light affects the AABB.
    return sqDist <= f32(lightRadius * lightRadius);
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
    //let clusterIndex = globalIdx.x * numClustersX * numClustersY + globalIdx.y * numClustersX + globalIdx.z;
    //let clusterIndex = globalIdx.z + globalIdx.y * numClustersZ + globalIdx.x * numClustersY * numClustersZ;
    let clusterIndex = globalIdx.x + (globalIdx.y * numClustersX) + globalIdx.z * (numClustersX * numClustersY);

    let near = camUniforms.near;
    let far = camUniforms.far;

    let resolution = camUniforms.resolution;
    let tileSizeX = resolution.x / numClustersX;
    let tileSizeY = resolution.y / numClustersY;
    let tileSizeZ = (far - near) / numClustersZ;

    // In Screen Space
    let clusterMinX = f32(globalIdx.x) * tileSizeX;
    let clusterMaxX = f32(globalIdx.x+1) * tileSizeX;

    let clusterMinY = f32(globalIdx.y) * tileSizeY;
    let clusterMaxY = f32(globalIdx.y+1) * tileSizeY;

    // Compute z bounds by log depth
    let logDepthMin = f32(globalIdx.z) * tileSizeZ;
    let logDepthMax = f32(globalIdx.z+1) * tileSizeZ;

    let clusterMinZ = near * pow(far/near, logDepthMin);
    let clusterMaxZ = near * pow(far/near, logDepthMax);

    // Convert to View Space
    let clusterMin = camUniforms.invViewProj * vec4(clusterMinX, clusterMinY, clusterMinZ, 1.0);
    let clusterMax = camUniforms.invViewProj * vec4(clusterMaxX, clusterMaxY, clusterMaxZ, 1.0);

    var numLightsInCluster = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights && numLightsInCluster < 512; lightIdx++) 
    {
        let light = lightSet.lights[lightIdx];
        let lightPosView = camUniforms.viewProj * vec4(light.pos, 1.0);

        if (lightIntersection(clusterMin.xyz, clusterMax.xyz, lightPosView.xyz))
        {
            // This light affects the cluster
            clusterSet.clusters[clusterIndex].lights[numLightsInCluster] = lightIdx;
            numLightsInCluster++;
        }
    }
    clusterSet.clusters[clusterIndex].numLights = numLightsInCluster;

    //clusterSet.clusters[clusterIndex]

    let debugR = f32(globalIdx.x)/f32(numClustersX);
    let debugG = f32(globalIdx.y)/f32(numClustersY);
    let debugB = f32(globalIdx.z)/f32(numClustersZ);

    clusterSet.clusters[clusterIndex].color = vec3f(debugR, debugG, debugB);
}
