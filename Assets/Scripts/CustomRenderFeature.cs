using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        public Material blitMaterial = null;
        public Material initMaterial = null;
        public Material edgeMaterial = null;
        //public int blitMaterialPassIndex = -1;
        //目标RenderTexture 
        public RenderTexture renderTexture = null;
        public RenderTexture pathTexture = null; 

    }
    public Settings settings = new Settings();
    private CustomPass blitPass;

    public override void Create()
    {
        blitPass = new CustomPass(name, settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.blitMaterial == null)
        {
            Debug.LogWarningFormat("丢失blit材质");
            return;
        }
        blitPass.renderPassEvent = settings.renderPassEvent;
        blitPass.Setup(renderer.cameraDepthTarget);
        renderer.EnqueuePass(blitPass);
    }
}

public class CustomPass : ScriptableRenderPass
{
    private CustomRenderFeature.Settings settings;
    string m_ProfilerTag;
    RenderTargetIdentifier source;

    private bool Inited;

    public CustomPass(string tag, CustomRenderFeature.Settings settings)
    {
        m_ProfilerTag = tag;
        this.settings = settings;
    }

    public void Setup(RenderTargetIdentifier src)
    {
        source = src;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer command = CommandBufferPool.Get(m_ProfilerTag);
        var rt = settings.renderTexture;
        var pt = settings.pathTexture;
        if (!Inited)
        {
            command.Blit(source, pt, settings.initMaterial);
            Inited = true;
        }
        else
        {
            RenderTexture tmp = RenderTexture.GetTemporary(rt.width, rt.height, 
                0, RenderTextureFormat.Default);
            command.Blit(pt, tmp);
            command.Blit(tmp, pt, settings.blitMaterial);
            command.Blit(pt, rt, settings.edgeMaterial);
        }
        context.ExecuteCommandBuffer(command);
        CommandBufferPool.Release(command);
    }
}