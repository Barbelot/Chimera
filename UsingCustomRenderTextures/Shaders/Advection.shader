Shader "Chimera/Advection_Update"
{
    Properties
    {
        _FluidTex("Fluid Texture", 2D) = "black" {}
        _dt("dt", float) = 0.15
        _ConstantDecay("Constant Color Decay", float) = 0.00005
        _RelativeDecay("Relative Color Decay", float) = 0.002
        //_DecayTargetIntensity("Decay Target Intensity", Range(0.0, 1.0)) = 0.0
    }

        CGINCLUDE

#include "UnityCustomRenderTexture.cginc"

    sampler2D _FluidTex;
    float _dt;
    float _ConstantDecay;
    float _RelativeDecay;
    //float _DecayTargetIntensity;

    struct Emitter {
        float2 position;
        float4 color;
        float intensity;
        float radiusPower;
    };

    int _EmittersCount;

    StructuredBuffer<Emitter> _EmittersBuffer;

	half4 frag(v2f_customrendertexture i) : SV_Target
	{
		float2 uv = i.globalTexcoord;

		float tw = 1.0f / _CustomRenderTextureWidth;
		float th = 1.0f / _CustomRenderTextureHeight;

        float2 velo = tex2D(_FluidTex, uv).xy;
        float4 col = tex2D(_SelfTexture2D, uv - _dt * velo * float2(tw, th) * 3.); //advection

        for (int i = 0; i < _EmittersCount; i++) {
            col += _EmittersBuffer[i].color * _EmittersBuffer[i].intensity * .0025 / (0.0005 + pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower)) * _dt;
        }

        /* Decay to zero */
        col = max(col - _ConstantDecay - col * _RelativeDecay, 0.); //decay

        /* Decay to target intensity */
        //if((col.r + col.g + col.b) / 3 > _DecayTargetIntensity){
        //    col -= _ConstantDecay + col * _RelativeDecay; //decay
        //}
        //else {
        //    col += _ConstantDecay + col * _RelativeDecay;
        //}

        //col = max(0, col);

        return col;
	}

		ENDCG

		SubShader
	{
		Cull Off ZWrite Off ZTest Always
			Pass
		{
			Name "AdvectionUpdate"
			CGPROGRAM
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			ENDCG
		}
	}
}
