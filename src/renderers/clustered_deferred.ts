import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

const ALBEDO_TEXTURE_FORMAT = 'rgba8unorm';
const NORMAL_TEXTURE_FORMAT = 'rgba16float';
const POSITION_TEXTURE_FORMAT = 'rgba16float';
const DEPTH_TEXTURE_FORMAT = 'depth24plus';

export class ClusteredDeferredRenderer extends renderer.Renderer
{
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    gBufferBindGroupLayout: GPUBindGroupLayout;
    gBufferBindGroup: GPUBindGroup;

    shadingBindGroupLayout: GPUBindGroupLayout;
    shadingBindGroup: GPUBindGroup;
    
    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;
    
    positionTexture: GPUTexture;
    positionTextureView: GPUTextureView;
    
    normalTexture: GPUTexture;
    normalTextureView: GPUTextureView;
    
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    sampler: GPUSampler;

    gBufferPipeline: GPURenderPipeline;
    shadingPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // Textures
        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: ALBEDO_TEXTURE_FORMAT,
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.albedoTextureView = this.albedoTexture.createView();

        this.positionTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: POSITION_TEXTURE_FORMAT,
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.positionTextureView = this.positionTexture.createView();

        this.normalTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: NORMAL_TEXTURE_FORMAT,
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.normalTextureView = this.normalTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();
        
        // Sampler
        let samplerDescriptor: GPUSamplerDescriptor = {};
        samplerDescriptor.magFilter = "linear";
        samplerDescriptor.minFilter = "linear";
        samplerDescriptor.mipmapFilter = "linear";
        samplerDescriptor.addressModeU = "repeat";
        samplerDescriptor.addressModeV = "repeat";

        this.sampler = renderer.device.createSampler(samplerDescriptor);

        // Bind Groups
        this.gBufferBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "g-buffer pass bind group layout",
            entries: [
                { // camUniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {type: "uniform"}
                }
            ]
        });

        this.gBufferBindGroup = renderer.device.createBindGroup({
            label: "g-buffer pass bind group",
            layout: this.gBufferBindGroupLayout,
            entries: [                
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        this.shadingBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "shading pass bind group layout",
            entries: [
                { // lightSet
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusterSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: {type: "read-only-storage" }
                },
                // Textures for deferred rendering
                { // albedo
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                { // position
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                { // normal
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'float'
                    }
                },
                { // textureSampler
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });

        this.shadingBindGroup = renderer.device.createBindGroup({
            label: "shading pass bind group",
            layout: this.shadingBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                },
                // Textures for Deferred rendering
                {
                    binding: 2,
                    resource: this.albedoTextureView
                },
                {
                    binding: 3,
                    resource: this.positionTextureView
                },
                {
                    binding: 4,
                    resource: this.normalTextureView
                },
                {
                    binding: 5,
                    resource: this.sampler
                }
            ]
        });


        // Pipelines
        this.gBufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "deferred g-buffer pipeline layout",
                bindGroupLayouts: [
                    this.gBufferBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "naive vert shader", // no fplus vs
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "deferred frag shader",
                    code: shaders.clusteredDeferredFragSrc
                }),
                targets: [
                    {
                        format: ALBEDO_TEXTURE_FORMAT,
                    },
                    {
                        format: POSITION_TEXTURE_FORMAT,
                    },
                    {
                        format: NORMAL_TEXTURE_FORMAT,
                    }
                ]
            }
        });

        this.shadingPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "deferred shading pipeline layout",
                bindGroupLayouts: [
                    this.gBufferBindGroupLayout,
                    this.shadingBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred full screen vs", // no fplus vs
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                buffers: [ ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred full screen fs",
                    code: shaders.clusteredDeferredFullscreenFragSrc
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });
    }

    doLightClustering()
    {
        let encoder = renderer.device.createCommandEncoder();
        this.lights.doLightClustering(encoder);
        renderer.device.queue.submit([encoder.finish()]);
    }

    getGBufferRenderPassDescriptor()
    {
        let gbufferRenderPassDesc: GPURenderPassDescriptor = {
            label: "g-buffer pass descriptor",
            colorAttachments: [
                {
                    view: this.albedoTextureView,
                    clearValue: {r:0, g:0, b:0, a:1},
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.positionTextureView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.normalTextureView,
                    clearValue: {r:0, g:0, b:0, a:0},
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        };

        return gbufferRenderPassDesc;
    }

    getShadingRenderPassDescriptor()
    {
        let shadingRenderPassDesc: GPURenderPassDescriptor = {
            label: "shading pass descriptor",
            colorAttachments: [
                {
                    view: renderer.context.getCurrentTexture().createView(),
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ]
        };
        return shadingRenderPassDesc
    }

    doGBufferPass(pipeline: GPURenderPipeline, passDescriptor: GPURenderPassDescriptor)
    {
        let encoder = renderer.device.createCommandEncoder();
        const renderPass = encoder.beginRenderPass(passDescriptor);
        renderPass.setPipeline(pipeline);

        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.gBufferBindGroup);

        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });

        renderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }

    doFullscreenPass(pipeline: GPURenderPipeline, passDescriptor: GPURenderPassDescriptor)
    {
        let encoder = renderer.device.createCommandEncoder();
        const renderPass = encoder.beginRenderPass(passDescriptor);
        
        // Fullscreen pass is simple, only the basic bind groups and drawing only 6 verts for the screen quad.
        renderPass.setPipeline(pipeline);
        renderPass.setBindGroup(0, this.gBufferBindGroup);
        renderPass.setBindGroup(1, this.shadingBindGroup);
        renderPass.draw(6);
        renderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }

    override draw()
    {
        this.doLightClustering();
        this.doGBufferPass(this.gBufferPipeline, this.getGBufferRenderPassDescriptor());
        this.doFullscreenPass(this.shadingPipeline, this.getShadingRenderPassDescriptor());
    }
}