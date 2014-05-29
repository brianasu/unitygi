Shader "Light Bleed/Particles Alpha Blended" 
{
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Softness ("Softness", FLOAT) = 1
		_Bleed ("Color Bleed", FLOAT) = 1
	}

	CGINCLUDE
	#include "UnityCG.cginc"
	#include "VoxelHelper.cginc"

	sampler2D _CameraDepthTexture;
	sampler2D _MainTex;	
	
	float _Softness;
	float _Bleed;
	
	float4x4 _InvWorld2Camera;
	
	struct Input 
	{
		float4 pos : SV_POSITION;
		float2 uv_MainTex : TEXCOORD0;
		float3 worldPos : TEXCOORD1;
		
		float depth : TEXCOORD2;
		float4 screenPos : TEXCOORD3;
		fixed4 color : COLOR0;
	};		
	
	Input vert( appdata_full v ) 
	{
	    Input o;
	    
	    o.pos = mul(UNITY_MATRIX_MVP, v.vertex);	    
	    o.worldPos = mul(_InvWorld2Camera, v.vertex).xyz;
	    
	    o.uv_MainTex = v.texcoord.xy;
	    o.color = v.color;
	    
	    o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;
	    o.screenPos = ComputeScreenPos(o.pos);
	    
	    return o;
	}
	
	fixed4 surf (Input IN) : COLOR
	{
		fixed alpha = (Linear01Depth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)))) - IN.depth) * _Softness;
		alpha = saturate(alpha);
	
		fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
		
		fixed3 gi = 0;		
		#ifdef ENABLE_BLEED
		gi = SAMPLE_GI(IN.worldPos);
		#endif
		
		#ifdef MULTIPLY_COLOR
		gi *= c.rgb * IN.color.rgb;
		#else
		gi *= c.rgb;
		#endif		
		
		fixed4 Albedo = IN.color * c;
		fixed3 Emission = gi;
		return float4(lerp(Albedo.rgb, Albedo.rgb + Emission.rgb, _Bleed), Albedo.a * alpha);
		return float4(lerp(Albedo.rgb, Albedo.rgb + Emission.rgb, _Bleed), Albedo.a);
	}		
	ENDCG
	
	SubShader 
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			
			CGPROGRAM
			#pragma multi_compile MULTIPLY_COLOR MULTIPLY_COLOR_OFF
			#pragma multi_compile ENABLE_BLEED DISABLE_BLEED
			#pragma multi_compile VOXEL_POINT_SAMPLE VOXEL_TRILINEAR_SAMPLE 
			#pragma vertex vert
			#pragma fragment surf
			#pragma target 3.0
			ENDCG
		}
	}	
}