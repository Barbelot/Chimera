Shader "Chimera/Fluid_Update"
{
    Properties
    {
        _K("K", float) = 0.2
        _Viscosity("Viscosity", float) = 0.55
        _dt("dt", float) = 0.15
        _Vorticity("Vorticity", Range(0.03, 0.2)) = 0.11
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

    float _K;           //Gas state constant
    float _Viscosity;   
    float _dt;
    float _Vorticity;   //Recommended values between 0.03 and 0.2, higher values simulate lower viscosity fluids (think billowing smoke)

    struct Emitter {
        float2 position;
        float2 direction;
        float force;
    };

    int _EmittersCount;

    StructuredBuffer<Emitter> _EmittersBuffer;

    float mag2(float2 p) { return dot(p, p); }

    float4 solveFluid(sampler2D smp, float2 uv, float2 w, float time)
    {

        float4 data = tex2D(smp, uv);
        float4 tr = tex2D(smp, uv + float2(w.x, 0));
        float4 tl = tex2D(smp, uv - float2(w.x, 0));
        float4 tu = tex2D(smp, uv + float2(0, w.y));
        float4 td = tex2D(smp, uv - float2(0, w.y));

        float3 dx = (tr.xyz - tl.xyz) * 0.5;
        float3 dy = (tu.xyz - td.xyz) * 0.5;
        float2 densDif = float2(dx.z, dy.z);

        data.z -= _dt * dot(float3(densDif, dx.x + dy.y), data.xyz); //density
        float2 laplacian = tu.xy + td.xy + tr.xy + tl.xy - 4.0 * data.xy;
        float2 viscForce = float2(_Viscosity, _Viscosity) * laplacian;
        data.xyw = tex2D(smp, uv - _dt * data.xy * w).xyw; //advection

        float2 newForce = float2(0, 0);

        //Emitters
        for (int i = 0; i < _EmittersCount; i++) {
            newForce.xy += _EmittersBuffer[i].force * _EmittersBuffer[i].direction * 0.001 / (mag2(uv - _EmittersBuffer[i].position) + 0.0001);
        }

        data.xy += _dt * (viscForce.xy - _K / _dt * densDif + newForce); //update velocity
        data.xy = max(float2(0, 0), abs(data.xy) - 1e-4) * sign(data.xy); //linear velocity decay

        data.w = (tr.y - tl.y - tu.x + td.x);
        float2 vort = float2(abs(tu.w) - abs(td.w), abs(tl.w) - abs(tr.w));
        vort *= _Vorticity / length(vort + 1e-9) * data.w;
        data.xy += vort;

        data.x *= smoothstep(.5, .49, abs(uv.x - 0.5));
        data.y *= smoothstep(.5, .49, abs(uv.y - 0.5)); //Boundaries

        data = clamp(data, float4(float2(-10, -10), 0.5, -10.), float4(float2(10, 10), 3.0, 10.));

        return data;
    }

	half4 frag(v2f_customrendertexture i) : SV_Target
	{
		float2 uv = i.globalTexcoord;

		float tw = 1.0f / _CustomRenderTextureWidth;
		float th = 1.0f / _CustomRenderTextureHeight;

		float4 fluidOutput = solveFluid(_SelfTexture2D, uv, float2(tw, th), _Time.y);

		return fluidOutput;
	}

		ENDCG

		SubShader
	{
		Cull Off ZWrite Off ZTest Always
			Pass
		{
			Name "FluidUpdate"
			CGPROGRAM
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			ENDCG
		}
	}
}
