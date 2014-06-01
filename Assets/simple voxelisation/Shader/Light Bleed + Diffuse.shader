Shader "Light Bleed/Diffuse Normal" 
{
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BumpTex ("Normal (RGB)", 2D) = "bump" {}
		_Color ("Color", COLOR) = (1, 1, 1, 1)
	}
	
	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma multi_compile MULTIPLY_COLOR MULTIPLY_COLOR_OFF
		#pragma multi_compile ENABLE_BLEED DISABLE_BLEED
		#pragma multi_compile VOXEL_POINT_SAMPLE VOXEL_TRILINEAR_SAMPLE
		#pragma surface surf Lambert
		#pragma target 3.0
		#include "VoxelHelper.cginc"

		sampler2D _MainTex;
		sampler2D _BumpTex;
		half4 _Color;
		
		float4 _LightDir;
		
		struct Input 
		{
			float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
		};
		
		void surf (Input IN, inout SurfaceOutput o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			fixed3 norm = UnpackNormal(tex2D(_BumpTex, IN.uv_MainTex));
			
			fixed4 gi = 0;
			#ifdef ENABLE_BLEED
			gi = SAMPLE_GI(IN.worldPos);
			#endif
			
			#ifdef MULTIPLY_COLOR
			o.Emission = gi * c.rgb * _Color;
			#else
			o.Emission = gi * c.rgb;
			#endif
			
			o.Albedo = _Color.rgb * c.rgb;
			o.Normal = norm;
			o.Alpha = 1;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
