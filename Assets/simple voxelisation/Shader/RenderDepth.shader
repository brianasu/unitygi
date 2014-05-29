Shader "Hidden/Depth" {

CGINCLUDE
#include "UnityCG.cginc"
#include "TerrainEngine.cginc"

struct v2f {
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
    float depth : TEXCOORD1;
};

sampler2D _MainTex;
float4 _MainTex_ST;

float _Cutoff;

v2f vertNoTexture( appdata_base v ) {
    v2f o;
    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
    return o;
}

v2f vertTexture( appdata_base v ) {
    v2f o;
    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
    o.uv = v.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
    o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
    return o;
}

half4 fragNothing(v2f i) : COLOR {
	clip(-1);
	return half4(1, 0, 0, 1);
}

half4 fragAlpha(v2f i) : COLOR {
	clip(tex2D(_MainTex, i.uv).a - _Cutoff);
	return half4((i.depth) , 0, 0, 1);
}

half4 frag(v2f i) : COLOR {
	return half4((i.depth), 0, 0, 1);
}

ENDCG

Subshader
{
	Tags {"RenderType"="Opaque"}
	Pass {
		Fog { Mode Off }

		CGPROGRAM
		#pragma vertex vertNoTexture
		#pragma fragment frag
		ENDCG
	}
}
Subshader
{
	Tags {"RenderType"="Transparent"}
	Pass {
		Fog { Mode Off }

		CGPROGRAM
		#pragma vertex vertNoTexture
		#pragma fragment fragNothing
		ENDCG
	}
}
Subshader
{
	Tags {"RenderType"="TransparentCutout"}
	Pass {
		Fog { Mode Off }

		CGPROGRAM
		#pragma vertex vertTexture
		#pragma fragment fragAlpha
		ENDCG
	}
}

SubShader {
	Tags { "RenderType"="GrassBillboard" }
	Pass {
		Fog { Mode Off }
		Cull Off
		AlphaTest Greater [_Cutoff]
CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#pragma vertex vertGrassBillboard
#pragma fragment fragGrassBillboard

v2f vertGrassBillboard (appdata_full v) {
	v2f o;

	WavingGrassBillboardVert (v);

	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	o.uv = v.texcoord;

	o.depth = -mul((float3x4)UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
	return o;
}

half4 fragGrassBillboard (v2f i) : COLOR {
	return half4(i.depth, 0, 0, tex2D(_MainTex, i.uv).a);
}
ENDCG
	}
}

SubShader {
	Tags { "RenderType"="Grass" }
	Pass {
		Fog { Mode Off }
		Cull Off
		AlphaTest Greater [_Cutoff]
CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#pragma vertex vertGrass
#pragma fragment fragGrass

v2f vertGrass (appdata_full v) {
	v2f o;

	float waveAmount = v.color.a * _WaveAndDistance.z;
	TerrainWaveGrass (v.vertex, waveAmount, v.color);

	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	o.uv = v.texcoord;

	o.depth = -mul((float3x4)UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
	return o;
}

half4 fragGrass(v2f i) : COLOR {
	return half4(i.depth, 0, 0, tex2D(_MainTex, i.uv).a);
}
ENDCG
	}
}

SubShader {
	Tags { "RenderType"="TreeOpaque" }
	Pass {
		Fog { Mode Off }
CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#pragma vertex vertTreeOpaque
#pragma fragment fragTreeOpaque

v2f vertTreeOpaque (appdata_full v) {
	v2f o;
	TerrainAnimateTree(v.vertex, v.color.w);
	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	o.uv = v.texcoord;
	o.depth = -mul((float3x4)UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
	return o;
}

half4 fragTreeOpaque(v2f i) : COLOR {
	return half4(i.depth, 0, 0, 1);
}
ENDCG
	}
}

SubShader {
	Tags { "RenderType"="TreeTransparentCutout" }
	Pass {
		Fog { Mode Off }
		Cull Off
		AlphaTest Greater [_Cutoff]
CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#pragma vertex vertTreeTransparentCutout
#pragma fragment fragTreeTransparentCutout

v2f vertTreeTransparentCutout (appdata_full v) {
	v2f o;
	TerrainAnimateTree(v.vertex, v.color.w);
	o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
	o.uv = v.texcoord;
	o.depth = -mul((float3x4)UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
	return o;
}

half4 fragTreeTransparentCutout(v2f i) : COLOR {
	return half4(i.depth, 0, 0, tex2D(_MainTex, i.uv).a);
}
ENDCG
	}
}



Fallback Off
}
