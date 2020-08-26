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

        //Chimera's Breath
//by nimitz 2018 (twitter: @stormoid)

/*
    The main interest here is the addition of vorticity confinement with the curl stored in
    the alpha channel of the simulation texture (which was not used in the paper)
    this in turns allows for believable simulation of much lower viscosity fluids.
    Without vorticity confinement, the fluids that can be simulated are much more akin to
    thick oil.

    Base Simulation based on the 2011 paper: "Simple and fast fluids"
    (Martin Guay, Fabrice Colin, Richard Egli)
    (https://hal.inria.fr/inria-00596050/document)
*/

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
