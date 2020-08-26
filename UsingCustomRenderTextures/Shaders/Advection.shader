Shader "Chimera/Advection_Update"
{
    Properties
    {
        _FluidTex("Fluid Texture", 2D) = "black" {}
        _dt("dt", float) = 0.15
        _ConstantDecay("Constant Color Decay", float) = 0.00005
        _RelativeDecay("Relative Color Decay", float) = 0.002
    }

        CGINCLUDE

#include "UnityCustomRenderTexture.cginc"

    sampler2D _FluidTex;
    float _dt;
    float _ConstantDecay;
    float _RelativeDecay;

    struct Emitter {
        float2 position;
        float4 color;
        float intensity;
        float radiusPower;
    };

    int _EmittersCount;

    StructuredBuffer<Emitter> _EmittersBuffer;

    float mag2(float2 p) { return dot(p, p); }
    //float2 point1(float t) {
    //    t *= 0.62;
    //    return float2(0.12, 0.5 + sin(t) * 0.2);
    //}
    //float2 point2(float t) {
    //    t *= 0.62;
    //    return float2(0.88, 0.5 + cos(t + 1.5708) * 0.2);
    //}

    float2x2 mm2(in float a) { float c = cos(a), s = sin(a); return float2x2(c, s, -s, c); }

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

        //col += .0025 / (0.0005 + pow(length(uv - point1(_Time.y)), 1.75)) * _dt * 0.12;
        //col += .0025 / (0.0005 + pow(length(uv - point2(_Time.y)), 1.75)) * _dt * 0.12;

        //col = clamp(col, 0., 5.);
        col = max(col - _ConstantDecay - col * _RelativeDecay, 0.); //decay

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
