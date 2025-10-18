// 3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.
struct VertexOutput
{
    @builtin(position) pos : vec4<f32>,
}

@vertex
fn main(@builtin(vertex_index) vertIdx: u32) -> VertexOutput {
    
    // full screen quad
    var vbo = array<vec2<f32>, 6>
    (
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 1.0, -1.0),
        vec2<f32>(-1.0,  1.0),

        vec2<f32>(-1.0,  1.0),
        vec2<f32>( 1.0, -1.0),
        vec2<f32>( 1.0,  1.0),
    );
    
    return VertexOutput(vec4<f32>(vbo[vertIdx].xy, 0.0, 1.0));
}