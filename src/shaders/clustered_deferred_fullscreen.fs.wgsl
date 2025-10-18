// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

struct FragmentInput
{
    @builtin(position) pos : vec4<f32>,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    return vec4(1.0, 0.0, 0.0, 1.0);
}