Shader "Chimera/Fluid3D_Update"
{
    Properties
    {
        _K("K", float) = 0.2
        _Viscosity("Viscosity", float) = 0.55
        _dt("dt", float) = 0.15
        _Vorticity("Vorticity", float) = 0.11
		_VelocityAttenuation("Velocity Attenuation", Range(0,1)) = 0
    }

        CGINCLUDE

#include "UnityCustomRenderTexture.cginc"

        float _AbsoluteTime;
        float _K;           //Gas state constant
        float _Viscosity;   
        float _dt;
		float _Vorticity;   //Recommended values between 0.03 and 0.2, higher values simulate lower viscosity fluids (think billowing smoke)
		float _VelocityAttenuation;

		struct Emitter {
			float2 position;
			float2 direction;
			float force;
			float radiusPower;
			float shape;
		};

		int _EmittersCount;

		StructuredBuffer<Emitter> _EmittersBuffer;

		float PackFloats(float a, float b) {

			//Packing
			uint aScaled = a * 65535.0f;
			uint bScaled = b * 65535.0f;
			uint abPacked = (aScaled << 16) | (bScaled & 0xFFFF);
			return asfloat(abPacked);
		}

		void UnpackFloat(float input, out float a, out float b) {

			//Unpacking
			uint uintInput = asuint(input);
			a = (uintInput >> 16) / 65535.0f;
			b = (uintInput & 0xFFFF) / 65535.0f;
		}

		float4 SampleBilinear(sampler2D smp, float2 uv) {

			float4 texelSize = float4(1.0f / _CustomRenderTextureWidth, 1.0f / _CustomRenderTextureHeight, _CustomRenderTextureWidth, _CustomRenderTextureHeight);

			// scale & offset uvs to integer values at texel centers
			float2 uv_texels = uv * texelSize.zw + 0.5f;

			// get uvs for the center of the 4 surrounding texels by flooring
			//float4 uv_min_max = float4((floor(uv_texels) - 0.5) * texelSize.xy, (floor(uv_texels) + 0.5) * texelSize.xy);
			
			// slightly faster alternative if texture is point filtered
			float4 uv_min_max = float4(uv - texelSize.xy * 0.5f, uv + texelSize * 0.5f);

			// blend factor
			float2 uv_frac = frac(uv_texels);

			// sample all 4 texels
			float4 texelA = tex2D(smp, uv_min_max.xy);
			float4 texelB = tex2D(smp, uv_min_max.xw);
			float4 texelC = tex2D(smp, uv_min_max.zy);
			float4 texelD = tex2D(smp, uv_min_max.zw);

			// bilinear interpolation
			return lerp(lerp(texelA, texelB, uv_frac.y), lerp(texelC, texelD, uv_frac.y), uv_frac.x);
		}

		void SampleBilinearFluidData(sampler2D smp, float2 uv, out float2 velocity, out float density, out float vorticity) {

			float4 texelSize = float4(1.0f / _CustomRenderTextureWidth, 1.0f / _CustomRenderTextureHeight, _CustomRenderTextureWidth, _CustomRenderTextureHeight);

			// scale & offset uvs to integer values at texel centers
			float2 uv_texels = uv * texelSize.zw + 0.5f;

			// slightly faster alternative if texture is point filtered
			float4 uv_min_max = float4(uv - texelSize.xy * 0.5f, uv + texelSize * 0.5f);

			// blend factor
			float2 uv_frac = frac(uv_texels);

			// sample all 4 texels
			float4 texelA = tex2D(smp, uv_min_max.xy);
			float4 texelB = tex2D(smp, uv_min_max.xw);
			float4 texelC = tex2D(smp, uv_min_max.zy);
			float4 texelD = tex2D(smp, uv_min_max.zw);

			float texelADensity, texelBDensity, texelCDensity, texelDDensity;
			float texelAVorticity, texelBVorticity, texelCVorticity, texelDVorticity;

			UnpackFloat(texelA.w, texelADensity, texelAVorticity);
			UnpackFloat(texelB.w, texelBDensity, texelBVorticity);
			UnpackFloat(texelC.w, texelCDensity, texelCVorticity);
			UnpackFloat(texelD.w, texelDDensity, texelDVorticity);

			// bilinear interpolation
			velocity = lerp(lerp(texelA.xy, texelB.xy, uv_frac.y), lerp(texelC.xy, texelD.xy, uv_frac.y), uv_frac.x);
			density = lerp(lerp(texelADensity, texelBDensity, uv_frac.y), lerp(texelCDensity, texelDDensity, uv_frac.y), uv_frac.x);
			vorticity = lerp(lerp(texelAVorticity, texelBVorticity, uv_frac.y), lerp(texelCVorticity, texelDVorticity, uv_frac.y), uv_frac.x);
		}

		void SamplePointFluidData(sampler2D smp, float2 uv, out float2 velocity, out float density, out float vorticity) {

			float4 texelSize = float4(1.0f / _CustomRenderTextureWidth, 1.0f / _CustomRenderTextureHeight, _CustomRenderTextureWidth, _CustomRenderTextureHeight);

			// scale & offset uvs to integer values at texel centers
			float2 uv_texels = uv * texelSize.zw + 0.5f;

			float4 texel = tex2D(smp, uv_texels);

			velocity = texel.xy;
			UnpackFloat(texel.w, density, vorticity);
		}

		float4 solveFluid(sampler2D smp, float2 uv, float2 w, float time)
		{

			//float4 data = SampleBilinear(smp, uv);
			//float4 tr = SampleBilinear(smp, uv + float2(w.x, 0));
			//float4 tl = SampleBilinear(smp, uv - float2(w.x, 0));
			//float4 tu = SampleBilinear(smp, uv + float2(0, w.y));
			//float4 td = SampleBilinear(smp, uv - float2(0, w.y));

			float2 velocity, trVelocity, tlVelocity, tuVelocity, tdVelocity;
			float density, trDensity, tlDensity, tuDensity, tdDensity;
			float vorticity, trVorticity, tlVorticity, tuVorticity, tdVorticity;

			SampleBilinearFluidData(smp, uv, velocity, density, vorticity);
			SampleBilinearFluidData(smp, uv + float2(w.x, 0), trVelocity, trDensity, trVorticity);
			SampleBilinearFluidData(smp, uv - float2(w.x, 0), tlVelocity, tlDensity, tlVorticity);
			SampleBilinearFluidData(smp, uv + float2(0, w.y), tuVelocity, tuDensity, tuVorticity);
			SampleBilinearFluidData(smp, uv - float2(0, w.y), tdVelocity, tdDensity, tdVorticity);

			float2 velocityDx = (trVelocity - tlVelocity) * 0.5;
			float2 velocityDy = (tuVelocity - tdVelocity) * 0.5;
			float densityDx = (trDensity - tlDensity) * 0.5;
			float densityDy = (tuDensity - tdDensity) * 0.5;
			
			float2 densDif = float2(densityDx, densityDy);

			density -= _dt * dot(float3(densDif, velocityDx.x + velocityDy.y), float3(velocity, density)); //density
			float2 laplacian = tuVelocity + tdVelocity + trVelocity + tlVelocity - 4.0 * velocity;
			float2 viscForce = float2(_Viscosity, _Viscosity) * laplacian;

			float advectedDensity; //Unused
				
			SampleBilinearFluidData(smp, uv - _dt * velocity * w, velocity, advectedDensity, vorticity);

			float2 newForce = float2(0, 0);

			//Emitters
			for (int i = 0; i < _EmittersCount; i++) {

				if (_EmittersBuffer[i].shape == 0) {
					newForce.xy += _EmittersBuffer[i].force * _EmittersBuffer[i].direction * 0.001 / (pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower) + 0.0001);
				}
				else {
					newForce.xy += _EmittersBuffer[i].force * normalize(uv - _EmittersBuffer[i].position) * 0.001 / (pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower) + 0.0001);
					//newForce *= length(uv - _EmittersBuffer[i].position) > 0.01 ? 1 : 0;
				}
			}

			velocity += _dt * (viscForce.xy - _K / _dt * densDif + newForce); //update velocity
			velocity = max(float2(0, 0), abs(velocity) - 1e-4) * sign(velocity); //linear velocity decay

			vorticity = (trVelocity.y - tlVelocity.y - tuVelocity.x + tdVelocity.x);
			float2 vort = float2(abs(tuVorticity) - abs(tdVorticity), abs(tlVorticity) - abs(trVorticity));
			vort *= _Vorticity / length(vort + 1e-9) * vorticity;
			velocity += vort;

			velocity.x *= smoothstep(.5, .49, abs(uv.x - 0.5));
			velocity.y *= smoothstep(.5, .49, abs(uv.y - 0.5)); //Boundaries

			velocity *= (1.0f - _VelocityAttenuation);

			//Clamp
			velocity = clamp(velocity, float2(-10, -10), float2(10, 10));
			density = clamp(density, 0.5, 3.0);
			vorticity = clamp(vorticity, -10., 10.);

			return float4(velocity, 0, PackFloats(density, vorticity));
		}

		float4 frag(v2f_customrendertexture i) : SV_Target
		{
			float2 uv = i.globalTexcoord;

			float tw = 1.0f / _CustomRenderTextureWidth;
			float th = 1.0f / _CustomRenderTextureHeight;

			float4 fluidOutput = solveFluid(_SelfTexture2D, uv, float2(tw, th), _AbsoluteTime);

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
