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

    let clusterMinZ = f32(globalIdx.z) * tileSizeZ;
    let clusterMaxZ = f32(globalIdx.z+1) * tileSizeZ;

    // Convert to View Space
    let clusterMin = camUniforms.invViewProj * vec4(clusterMinX, clusterMinY, clusterMinZ, 1.0);
    let clusterMax = camUniforms.invViewProj * vec4(clusterMaxX, clusterMaxY, clusterMaxZ, 1.0);

    //clusterSet.clusters[clusterIndex]

    let debugR = f32(globalIdx.x)/f32(numClustersX);
    let debugG = f32(globalIdx.y)/f32(numClustersY);
    let debugB = f32(globalIdx.z)/f32(numClustersZ);

    clusterSet.clusters[clusterIndex].color = vec3f(debugR, debugG, debugB);
}
