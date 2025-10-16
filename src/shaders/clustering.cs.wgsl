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

fn ndcToView(ndcXY: vec2f, viewSpaceDepth: f32) -> vec3f
{
    let invProj = camUniforms.invProj;

    let unprojected = invProj * vec4(ndcXY, -1.0, 1.0); // Always unprojects to the near plane
    let nearPlanePos = unprojected / unprojected.w; // Persp divide

    let viewSpaceDist = viewSpaceDepth / -nearPlanePos.z;

    return nearPlanePos.xyz * viewSpaceDist;
}

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

    let resolution = camUniforms.resolution;
    let tileSizeX = resolution.x / numClustersX;
    let tileSizeY = resolution.y / numClustersY;
    let tileSizeZ = (camUniforms.far - camUniforms.near) / numClustersZ;

    // In Pixel Space
    let clusterMinX = f32(globalIdx.x) * tileSizeX;
    let clusterMaxX = f32(globalIdx.x+1) * tileSizeX;

    let clusterMinY = f32(globalIdx.y) * tileSizeY;
    let clusterMaxY = f32(globalIdx.y+1) * tileSizeY;

    // Convert from pixel space to NDC
    let clusterMinXMinY_pixel = vec2f(clusterMinX, clusterMinY);
    let clusterMinXMaxY_pixel = vec2f(clusterMinX, clusterMaxY);
    let clusterMaxXMinY_pixel = vec2f(clusterMaxX, clusterMinY);
    let clusterMaxXMaxY_pixel = vec2f(clusterMaxX, clusterMaxY);

    let clusterMinXMinY_ndc = ((clusterMinXMinY_pixel / resolution) * 2.0) - vec2f(1.0);
    let clusterMinXMaxY_ndc = ((clusterMinXMaxY_pixel / resolution) * 2.0) - vec2f(1.0);
    let clusterMaxXMinY_ndc = ((clusterMaxXMinY_pixel / resolution) * 2.0) - vec2f(1.0);
    let clusterMaxXMaxY_ndc = ((clusterMaxXMaxY_pixel / resolution) * 2.0) - vec2f(1.0);

    // Compute z bounds by log depth
    let near = camUniforms.near;
    let far = camUniforms.far;

    let logDepthMin = f32(globalIdx.z) * tileSizeZ;
    let logDepthMax = f32(globalIdx.z+1) * tileSizeZ;

    let clusterNear = near * pow(far/near, logDepthMin);
    let clusterFar = near * pow(far/near, logDepthMax);

    // Convert NDC to view space
    let clusterViewSpacePoints = array<vec3f, 8>(
        ndcToView(clusterMinXMinY_ndc, clusterNear),
        ndcToView(clusterMinXMaxY_ndc, clusterNear),
        ndcToView(clusterMaxXMinY_ndc, clusterNear),
        ndcToView(clusterMaxXMaxY_ndc, clusterNear),
        ndcToView(clusterMinXMinY_ndc, clusterFar),
        ndcToView(clusterMinXMaxY_ndc, clusterFar),
        ndcToView(clusterMaxXMinY_ndc, clusterFar),
        ndcToView(clusterMaxXMaxY_ndc, clusterFar)
    );

    // Iterate over all the view space points to find the true min/max
    var clusterMin = clusterViewSpacePoints[0];
    var clusterMax = clusterViewSpacePoints[0];

    for (var i = 1u; i < 8u; i++)
    {
        clusterMin = min(clusterMin, clusterViewSpacePoints[i]);
        clusterMax = max(clusterMax, clusterViewSpacePoints[i]);
    }

    // Iterate over all the lights and determine if they would affect this cluster
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

    let debugR = f32(globalIdx.x)/f32(numClustersX);
    let debugG = f32(globalIdx.y)/f32(numClustersY);
    let debugB = f32(globalIdx.z)/f32(numClustersZ);

    clusterSet.clusters[clusterIndex].color = vec3f(debugR, debugG, debugB);
}
