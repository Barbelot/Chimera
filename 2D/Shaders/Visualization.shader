Shader "Chimera/Visualization_Update"
{
    Properties
    {
		_FluidTex("Fluid Texture", 2D) = "black" {}
		_Channel("Channel", Range(1, 5)) = 1
		_Multiplier("Multiplier", float) = 1
    }

        CGINCLUDE

#include "UnityCustomRenderTexture.cginc"

    sampler2D _FluidTex;
	int _Channel;
	float _Multiplier;

	half4 frag(v2f_customrendertexture i) : SV_Target
	{
		float2 uv = i.globalTexcoord;

		float tw = 1.0f / _CustomRenderTextureWidth;
		float th = 1.0f / _CustomRenderTextureHeight;

        float4 fluidData = tex2D(_FluidTex, uv);

		float4 col = float4(1, 1, 1, 1);

		if (_Channel <= 1) {
			col *= fluidData.x * _Multiplier;
		} else if (_Channel <= 2) {
			col *= fluidData.y * _Multiplier;
		} else if (_Channel <= 3) {
			col *= fluidData.z * _Multiplier;
		} else  if (_Channel <= 4) {
			col *= fluidData.w * _Multiplier;
		} else {
			col = fluidData * _Multiplier;
		}

        return col;
	}

		ENDCG

		SubShader
	{
		Cull Off ZWrite Off ZTest Always
			Pass
		{
			Name "VisualizationUpdate"
			CGPROGRAM
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			ENDCG
		}
	}
}
