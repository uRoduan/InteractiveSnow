Shader "Unlit/EdgeDetection"
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
            ZTest Always Cull Off ZWrite Off    
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            struct Attributes
            {
                float4 positionOS: POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv[9] : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;

            half2 GetUV(float2 uv, float x, float y)
            {
                return uv + _MainTex_TexelSize.xy * float2(x, y);
            }
            
            Varyings Vertex (Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                float2 uv = input.uv;
                output.uv[0] = GetUV(uv, -1, -1);
                output.uv[1] = GetUV(uv, 0, -1);
                output.uv[2] = GetUV(uv, 1, -1);
                output.uv[3] = GetUV(uv, -1, 0);
                output.uv[4] = GetUV(uv, 0, 0);
                output.uv[5] = GetUV(uv, 1, 0);
                output.uv[6] = GetUV(uv, -1, 1);
                output.uv[7] = GetUV(uv, 0, 1);
                output.uv[8] = GetUV(uv, 1, 1);
                
                return output;
            }

            float Sobel(Varyings input)
            {
                const float Gx[9] =
                    {
                        -1, -2, -1,
                         0,  0,  0,
                         1,  2,  1
                    };
                const float Gy[9] =
                    {
                        -1, 0, 1,
                        -2, 0, 2,
                        -1, 0, 1
                    };

                float edgeX = 0, edgeY = 0;
                float color;
                for (int i = 0; i < 9; i++)
                {
                   color = tex2D(_MainTex, input.uv[i]).r;
                   edgeX += Gx[i] * color;
                   edgeY += Gy[i] * color;
                }

                return abs(edgeX) + abs(edgeY);
            }

            float4 Fragment (Varyings input) : SV_Target
            {
                // return half4(0, 1, 1, 1);  
                float edge = Sobel(input);
                float4 color = tex2D(_MainTex, input.uv[4]);
                color.g = edge;
                return color;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Diffuse"
}
