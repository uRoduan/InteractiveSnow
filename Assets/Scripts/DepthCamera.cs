using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DepthCamera : MonoBehaviour
{
    public Camera camera;
    public Material Blitmat;
    
    private RenderTexture rt;

    // Start is called before the first frame update
    void Start()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode = DepthTextureMode.Depth;
        rt = RenderTexture.GetTemporary(512, 512, 0);
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        Graphics.Blit(src, dest, Blitmat);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
