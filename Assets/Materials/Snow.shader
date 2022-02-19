Shader "Unlit/Snow"
{
    Properties
    {
        _Color("Color(RGB)",Color) = (1,1,1,1)
        _MainTex("MainTex",2D) = "gary" {}
        _PathTex("PathTex",2D) = "white" {}
        _SnowEffectHeight("SnowEffectHeight", range(0, 1)) = 0.5
        _Tess("Tessellation", Range(1, 32)) = 20
        _MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
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
        Tags { "RenderType"="Opaque" } //QUEUE
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma geometry Geometry
            #pragma fragment Fragment
            

            struct Attributes
            {
                float4 positionOS: POSITION;
                float3 normal: NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct ControlPoint
            {
                float4 positionOS: INTERNALTESSPOS;
                float3 normal: NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                // float4 positionSS: TEXCOORD1;
                float3 positionWS: TEXCOORD1;
                float3 normalWS: TEXCOORD2;
                float3 viewDirectionWS : TEXCOORD3;
                float4 positionCS : SV_POSITION;
                
            };

             
            sampler2D _MainTex;
            sampler2D _PathTex;
            float _SnowEffectHeight;
            float4 _Color;
            float _Tess;
            float _MaxTessDistance;
            float _MinTessDistance;
            float4 _MainTex_ST;
            // TEXTURE2D(_MainTex);
            // SAMPLER(sampler_MainTex);
            
            ControlPoint Vertex (Attributes input)
            {
                ControlPoint output;
                output.positionOS = input.positionOS;
                output.normal = input.normal;
                output.uv = input.uv;
                output.color = input.color;
                return output;
            }

            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float3 worldPS = TransformObjectToWorld(vertex.xyz);
                float dist = distance(worldPS, GetCameraPositionWS());
                float factor = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                return factor;
            }
            

            TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;
            
                TessellationFactors f;
            
                float edge0 = CalcDistanceTessFactor(patch[0].positionOS, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].positionOS, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].positionOS, minDist, maxDist, _Tess);
            
                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            [domain("tri")] //输入的patch类型
            [outputcontrolpoints(3)] //输出控制点的个数
            [outputtopology("triangle_cw")] // 输出的拓扑结构 triangle_cw（顺时针环绕三角形）、triangle_ccw（逆时针环绕三角形）、line（线段）
            [partitioning("fractional_odd")] // 分割模式？
            [patchconstantfunc("MyPatchConstantFunction")] //告诉GPU一个patch会切成多少份
            ControlPoint Hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            Varyings AfterTessVertProgram (Attributes input)
            {
                Varyings output;
                
                float4 move = tex2Dlod(_PathTex, float4(input.uv.xy,0,0));
                float4 positionOS = input.positionOS;
                positionOS.xyz -= _SnowEffectHeight * move.r * input.normal;
                positionOS.xyz += _SnowEffectHeight * move.g * input.normal;
                
                output.positionWS = TransformObjectToWorld(positionOS);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normal);
                output.viewDirectionWS = normalize(GetCameraPositionWS() - output.positionWS);
                return output;
            }

            
            /*
             *param:
             *factors: patchconstantfunc的返回值
             *patch: 上一步的patch
             *barycentricCoordinates: 重心坐标
             */
            [domain("tri")]
            Varyings Domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes attributes;

                #define DomainInterpolate(fieldName) attributes.fieldName = \
                    patch[0].fieldName * barycentricCoordinates.x + \
                    patch[1].fieldName * barycentricCoordinates.y + \
                    patch[2].fieldName * barycentricCoordinates.z;

                DomainInterpolate(positionOS)
                DomainInterpolate(normal)
                DomainInterpolate(uv)
                DomainInterpolate(color)

                return AfterTessVertProgram(attributes);
            }

            float3 CalNormal(float3 vPos0, float3 vPos1, float3 vPos2)
            {
                //   0
                // 1   2, 逆时针
                const float3 normal = cross(vPos1 - vPos0, vPos2 - vPos0);
                return normalize(normal);
            }

            [maxvertexcount(3)]
            void Geometry(triangle Varyings input[3], inout TriangleStream<Varyings> outputStream)
            {
                Varyings input0 = input[0];
                Varyings input1 = input[1];
                Varyings input2 = input[2];
                
                // float3 normal = CalNormal(input[0].positionWS, input[1].positionWS, input[2].positionWS);
                // input[0].normalWS = input[1].normalWS = input[2].normalWS = normal;

                // outputStream.Append(input[0])

                float3 normalWS = CalNormal(input0.positionWS, input1.positionWS, input2.positionWS);
                input0.normalWS = input1.normalWS = input2.normalWS = normalWS;

                outputStream.Append(input0);
                outputStream.Append(input1);
                outputStream.Append(input2);
            }
            

            float4 Fragment (Varyings input) : SV_Target
            {
                // return float4(input.uv.r,input.uv.g, 0, 1);
                // sample the texture
                
                float4 mtex = tex2D(_MainTex, input.uv);

                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = input.normalWS;
                inputData.viewDirectionWS = input.viewDirectionWS;

                float color = UniversalFragmentPBR(inputData, mtex.rgb, 0.1, 0, 0.1, 1, 0, 1);
                // return color;
                return color;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Diffuse"
}
