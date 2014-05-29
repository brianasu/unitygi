Shader "Light Bleed/Transparent" 
{
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BumpTex ("Normal (RGB)", 2D) = "bump" {}
		_Color ("Color", COLOR) = (1, 1, 1, 1)
	}
	
	SubShader 
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
		LOD 200
		
		ZWrite Off
		Cull Off
		
		CGPROGRAM
		#pragma multi_compile ENABLE_GI DISABLE_GI
		#pragma multi_compile ENABLE_BLEED DISABLE_BLEED
		#pragma surface surf Lambert alpha
		#pragma target 3.0
		#include "VoxelHelper.cginc"

		sampler2D _MainTex;
		sampler2D _BumpTex;
		half4 _Color;
		
		struct Input 
		{
			float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
		};
		
		void surf (Input IN, inout SurfaceOutput o)
		{
			fixed4 gi = SAMPLE_GI(IN.worldPos)
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			fixed3 norm = UnpackNormal(tex2D(_BumpTex, IN.uv_MainTex));
			
			o.Albedo = _Color.rgb * c.rgb;
			#ifdef ENABLE_BLEED
			o.Emission = gi;
			#endif
			o.Alpha = _Color.a * c.a;
		}
		ENDCG
	} 
	FallBack Off
}
