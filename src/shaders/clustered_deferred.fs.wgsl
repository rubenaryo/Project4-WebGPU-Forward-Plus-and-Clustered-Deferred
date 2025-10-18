// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos:   vec3f,
    @location(1) nor:   vec3f,
    @location(2) uv:    vec2f
}

struct GBufferOut
{
    @location(0) albedo:    vec4<f32>,
    @location(1) position:  vec4<f32>,
    @location(2) normal:    vec4<f32>,
}

@fragment
fn main(in: FragmentInput) -> GBufferOut
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5) {
        discard;
    }

    let normalRGB = (in.nor * 0.5) + vec3(0.5);

    return GBufferOut
    (
        diffuseColor,
        vec4f(in.pos, 1.0),
        vec4f(normalRGB.rgb, 0.0)
    );
}
