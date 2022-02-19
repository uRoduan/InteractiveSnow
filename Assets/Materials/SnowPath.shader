Shader "Unlit/SnowPath"
{
    Properties
    {
        [HideInInspector]_MainTex ("Main Texture", 2D) = "white" {}
    }
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    // Texture2D _CameraDepthTexture;
    TEXTURE2D_X_FLOAT(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);
    
    ENDHLSL
    
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            struct Attributes
            {
                float4 positionOS: POSITION;
                float3 normal: Normal;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionSS: TEXCOORD1;
                float4 positionCS : SV_POSITION;
            };

            // sampler2D _MainTex;
            // float4 _MainTex_ST;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            Varyings Vertex (Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.positionSS = ComputeScreenPos(output.positionCS);
                output.uv = input.uv; 
                return output;
            }

            float4 Fragment (Varyings input) : SV_Target
            {
                float4 mtex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, input.positionSS.xy / input.positionSS.w).r;
                if(depth == 0)
                {
                    return mtex;
                }
                return float4(1, 0, 0, 1.0f);
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Diffuse"
}
