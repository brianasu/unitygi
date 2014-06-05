Shader "Hidden/Voxelize" 
{

	CGINCLUDE
		#include "UnityCG.cginc"

		struct v2f 
		{
			float4 pos : POSITION;
			fixed4 col : TEXCOORD0;
			float2 uv : TEXCOORD1;
		};
		
		struct v2fBlur
		{
			float4 pos : POSITION;			
			float2 uv[3] : TEXCOORD0;
		};	
		
		struct v2fDirectionalBlur
		{
			float4 pos : POSITION;
			fixed4 col : TEXCOORD0;
			float2 uv[6] : TEXCOORD1;
		};
		
		sampler2D _NormalTex;
		
		sampler2D _BufferTex;
		float4 _BufferTex_TexelSize;
		
		sampler2D _PrevTex;
		float4 _PrevTex_TexelSize;
		
		sampler2D _MainTex;
		float4 _MainTex_TexelSize;
		
		sampler2D _AlbedoTex;
		float4 _AlbedoTex_TexelSize;

		sampler2D _CameraDepthNormalsTextureManual;
		float4 _CameraDepthNormalsTextureManual_TexelSize;

		sampler2D _CameraDepthNormalsTexture;
		float4 _CameraDepthNormalsTexture_TexelSize;

		float4x4 _WorldToView;
		float4x4 _ViewToWorld;
		float _LightCameraFar;
		float _LightCameraNear;
		
		// for calculating world positions
		float4 _FrustrumPoints;
		
		// bounds of the volume
		float _LPVDimensions;
		float _LPVDimensions2;
		float _LPVDimensionsSquared;
		float4 _LPV_AABBMin;
		float4 _LPV_AABBMax;

		float4 _LightDir;
		float _NormalOffset;
		float _FallOff;
		float _BlendSpeed;
		float _UpScale;
		
		float _VPLMergeLimit;

		float3 CalcVS(float2 screenPos, float depth)
		{
			float2 lerpVal = screenPos;
			float3 ray = float3(
				_FrustrumPoints.x * lerpVal.x + _FrustrumPoints.y * (1 - lerpVal.x),
				_FrustrumPoints.z * lerpVal.y + _FrustrumPoints.w * (1 - lerpVal.y),
				_LightCameraFar);

			#ifdef PERSPECTIVE
			float3 posVS = float3(ray.xy * depth, ray.z * -depth);
			#else
			float3 posVS = float3(ray.xy, ray.z * -depth);
			#endif		
			return posVS;
		}
		
		bool inside(float3 p, float3 minp, float3 maxp)
		{
			if (p.x>maxp.x) return false;
			if (p.x<minp.x) return false;
			if (p.y>maxp.y) return false;
			if (p.y<minp.y) return false;
			if (p.z>maxp.z) return false;
			if (p.z<minp.z) return false;
			return true;
		}	
	
		float3 toGridSpace(float2 uv)
		{
			return float3(
				frac(uv.x * _LPVDimensions),
				uv.y, 
				floor(uv.x * _LPVDimensions) / _LPVDimensions) * _LPVDimensions;		
		}
		
		float2 toUV(float3 gridSpace)
		{	
	
			float3 cell = floor(gridSpace);
			float xUV = (cell.x + cell.z * _LPVDimensions) / _LPVDimensionsSquared;
			float yUV = cell.y / _LPVDimensions;			
			return float2(xUV, yUV);
		}		
		
		v2f vertVoxel(appdata_base v)
		{
			v2f o;

	 		float2 uvMapping = floor(v.vertex.xy  * _LPVDimensions) / _LPVDimensionsSquared;
			float4 uv = float4(uvMapping, 0, 0);

			float4 flux = tex2Dlod (_MainTex, float4(uvMapping, 0, 0));

			float4 depthNormal = tex2Dlod (_CameraDepthNormalsTexture, uv);	
			
			float depth = 0;
			float3 normalVS = 0;
			DecodeDepthNormal(depthNormal, depth, normalVS);		
			
			float3 positionVS = CalcVS(uvMapping, depth);
			
			float3 camView = mul(_WorldToView, -_LightDir).xyz;
			
			positionVS += normalize(normalVS + camView) * _NormalOffset;
			
			float3 worldPos = mul(_ViewToWorld, float4(positionVS, 1)).xyz;
			float3 worldNormal = mul(_ViewToWorld, float4(normalVS, 0)).xyz;
			float dt = max(0, dot(worldNormal, -_LightDir));			
			
			float3 dim = _LPV_AABBMax.xyz - _LPV_AABBMin.xyz;
			float3 cell = ((worldPos - _LPV_AABBMin.xyz) / dim) * _LPVDimensions; 
			cell = floor(cell);
			
			v.vertex.x = cell.x + cell.z * _LPVDimensions;
			v.vertex.y = cell.y;
			v.vertex.xy += v.texcoord.xy; 		
	
			#ifdef SAMPLE_COLOR
			o.col = tex2Dlod (_MainTex, float4(uvMapping, 0, 0));
			#else
			o.col = float4(worldNormal, 1);
			#endif
			
			o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
			
			return o;
		}
		
		v2f vertSimple(appdata_base v)
		{
			v2f o;
	 		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	 		o.uv = v.texcoord;
	 		
	 		#if UNITY_UV_STARTS_AT_TOP
			if (_PrevTex_TexelSize.y < 0)
			        o.uv.y = 1 - o.uv.y;
			#endif
	 		
			return o;
		}				
		
		float4 fragDirectionalBlur (v2f IN) : COLOR
		{
			#define SAMPLE_COUNT 17
			const float3 RAND_SAMPLES[SAMPLE_COUNT] = {
				float3(0, 0, 0),
				float3(0, 1, 0),
				float3(0, 0, 1),
				float3(1, 0, 1),
				float3(0, 1, 1),
				float3(1, 1, 0),
				
				float3(0, -1,  0),
				float3(0,  0, -1),
				float3(1,  0, -1),
				float3(0,  1, -1),
				float3(1, -1,  0),	
				
				
				float3(-1,  0, 1),
				float3(0,  -1, 1),
				float3(-1,  1, 0),		
				
				float3(-1,  0, -1),
				float3( 0, -1, -1),
				float3(-1, -1,  0)																					
			};		
		
			float3 gridSpace = toGridSpace(IN.uv);
			float3 normalVS = tex2D(_NormalTex, IN.uv).xyz;
			
			float4 contribution = 0;
			for(float i = 0; i < SAMPLE_COUNT; i++)
			{
		        float dt = (dot(normalVS, RAND_SAMPLES[i]) < 0) ? -1 : 1;
		        float3 randomVec = RAND_SAMPLES[i] * -dt;
				contribution += tex2D(_MainTex, toUV(gridSpace + randomVec));
			}
			
			return contribution / _FallOff;
		} 						
		
		v2fBlur vertSpatialBlur(appdata_base v, float2 mask)
		{
			float2 offs = _MainTex_TexelSize.xy;
		
			v2fBlur o;
	 		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	 		o.uv[0] = v.texcoord;
	 		o.uv[1] = v.texcoord + mask * offs;
	 		o.uv[2] = v.texcoord - mask * offs;
			return o;
		}

		fixed4 fragSimple(v2f i) : COLOR
		{
			return i.col;
		}
		
		struct COL_OUTPUT
		{
			float4 albedo : COLOR0;
			float4 depthNormals : COLOR1;
		};
		
		// merge close VPLs
		COL_OUTPUT fragDownsampleRSM(v2f IN)
		{
			COL_OUTPUT o;	
		
			// find brightest VPL
			fixed maxLum = 0;
			float2 uvPos = 0;
			for(float i = 0; i < 2; i++)
			{
				for(float j = 0; j < 2; j++)
				{
					half2 uv = IN.uv + float2(i, j) * _MainTex_TexelSize.xy;
					
					float4 depthNormal = tex2D (_CameraDepthNormalsTexture, uv);
					float depth = 0;
					float3 normalVS = 0;
					DecodeDepthNormal(depthNormal, depth, normalVS);
					float3 normalWS = mul(_ViewToWorld, float4(normalVS, 0)).xyz;					
					
					fixed lum = Luminance(tex2D(_MainTex, uv).rgb) * max(0, dot(normalWS, -_LightDir));
					if(maxLum < lum)
					{
						maxLum = lum;
						uvPos = uv;
					}
				}
			}
			
			float3 brightestPos = toGridSpace(uvPos);
			half samples = 0;
			
			half4 albedoAVG = 0;
			float3 normalAVG = 0;
			float depthAVG = 0;

			for(float k = 0; k < 2; k++)
			{
				for(float l = 0; l < 2; l++)
				{
					half2 uv = IN.uv + float2(k, l) * _MainTex_TexelSize.xy;
					
					float3 depthPos = toGridSpace(uv);
										
					if(length(depthPos - brightestPos) < _VPLMergeLimit)
					{
						float4 depthNormal = tex2D (_CameraDepthNormalsTexture, uv);
						float depth = 0;
						float3 normalVS = 0;
						DecodeDepthNormal(depthNormal, depth, normalVS);
					
						albedoAVG += tex2D(_MainTex, uv);
						depthAVG += depth;
						normalAVG += normalVS;
						samples++;
					}
				}
			}
			
			depthAVG /= samples;
			normalAVG /= samples;
			albedoAVG /= samples;
		
			o.albedo = albedoAVG;
			o.depthNormals = EncodeDepthNormal(depthAVG, normalAVG);
			
			return o;	
		}		
		
		half4 fragSpatialBlur (v2fBlur IN) : COLOR
		{
			half4 contribution = tex2D(_MainTex, IN.uv[0]);
			contribution += tex2D(_MainTex, IN.uv[1]);
			contribution += tex2D(_MainTex, IN.uv[2]);
			return contribution / _FallOff;
		} 
		
		fixed4 fragMotionBlur (v2f IN) : COLOR
		{		
		#ifdef FRAME_BLEND
			return lerp(tex2D(_PrevTex, IN.uv), tex2D(_MainTex, IN.uv), _BlendSpeed);
		#else
			return tex2D(_MainTex, IN.uv);
		#endif
		}
		
		fixed4 getSample(sampler2D volTex, float4 bmin, float4 bmax, float3 gridSpace, float dimensions)
		{
			float3 cell = floor(gridSpace);
			float xUV = (cell.x + cell.z * dimensions) / (dimensions * dimensions);
			float yUV = cell.y / dimensions;		
			return tex2D(volTex, float2(xUV, yUV));			
		}
		
		fixed4 fragUpscale (v2f IN) : COLOR
		{		
			return tex2D(_MainTex, IN.uv);
		} 		

	ENDCG

Subshader
{
	Pass //0
	{
		Tags {"RenderType" = "Transparent" "Queue" = "Transparent" }
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }

		CGPROGRAM
		#pragma multi_compile PERSPECTIVE ORTHOGRAPHIC
		#pragma multi_compile SAMPLE_COLOR SAMPLE_NORMAL
		#pragma glsl
		#pragma target 3.0
		#pragma vertex vertVoxel
		#pragma fragment fragSimple
		ENDCG
	}
	
	Pass //1
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		ColorMask RGB
		CGPROGRAM
		#pragma vertex vertBlur
		#pragma fragment fragSpatialBlur
		v2fBlur vertBlur(appdata_base v) { return vertSpatialBlur(v, float2(1, 0)); }
		ENDCG
	}
	Pass //2
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		ColorMask RGB
		CGPROGRAM
		#pragma vertex vertBlur
		#pragma fragment fragSpatialBlur
		v2fBlur vertBlur(appdata_base v) { return vertSpatialBlur(v, float2(0, 1)); }
		ENDCG
	}
	Pass //3
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		ColorMask RGB
		CGPROGRAM
		#pragma vertex vertBlur
		#pragma fragment fragSpatialBlur
		v2fBlur vertBlur(appdata_base v) { return vertSpatialBlur(v, float2(_LPVDimensions, 0)); }
		ENDCG
	}
	
		
				
	Pass //4
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		ColorMask RGB
		CGPROGRAM
		#pragma multi_compile FRAME_BLEND FRAME_BLEND_DISABLED
		#pragma vertex vertSimple
		#pragma fragment fragMotionBlur
		ENDCG
	}	
	
	
	
	Pass //5
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		Blend One One

		CGPROGRAM
		#pragma vertex vertSimple
		#pragma fragment fragUpscale
		ENDCG
	}	
	
	
	
	Pass //6
	{
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		CGPROGRAM
		#pragma vertex vertSimple
		#pragma fragment fragDownsampleRSM
		#pragma target 3.0
		ENDCG
	}	
					
}

Fallback off

} // shader