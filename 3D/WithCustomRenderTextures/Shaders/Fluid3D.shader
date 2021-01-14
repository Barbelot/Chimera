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
			float3 position;
			float3 direction;
			float force;
			float radiusPower;
			float shape;
		};

		int _EmittersCount;

		StructuredBuffer<Emitter> _EmittersBuffer;

		float PackFloats(float a, float b) {

			//Packing
			uint a16 = f32tof16(a);
			uint b16 = f32tof16(b);
			uint abPacked = (a16 << 16) | b16;

			return asfloat(abPacked);
		}

		void UnpackFloat(float input, out float a, out float b) {

			//Unpacking
			uint uintInput = asuint(input);
			a = f16tof32(uintInput >> 16);
			b = f16tof32(uintInput);
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

		/******* Float packing attempt **********
		float4 solveFluid2D(sampler2D smp, float2 uv, float2 w, float time)
		{
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
		***********************/

		float4 solveFluid2D(sampler2D smp, float2 uv, float2 w, float time)
		{

			float4 data = tex2D(smp, uv);

			float4 tr = tex2D(smp, uv + float2(w.x, 0));
			float4 tl = tex2D(smp, uv - float2(w.x, 0));
			float4 tu = tex2D(smp, uv + float2(0, w.y));
			float4 td = tex2D(smp, uv - float2(0, w.y));

			float4 trr = tex2D(smp, uv + 2.0 * float2(w.x, 0));
			float4 tuu = tex2D(smp, uv + 2.0 * float2(0, w.y));
			float4 tdd = tex2D(smp, uv - 2.0 * float2(0, w.y));
			float4 tll = tex2D(smp, uv - 2.0 * float2(w.x, 0));

			float4 tru = tex2D(smp, uv + float2(w.x, w.y));
			float4 trd = tex2D(smp, uv + float2(w.x, -w.y));
			float4 tlu = tex2D(smp, uv + float2(-w.x, w.y));
			float4 tld = tex2D(smp, uv + float2(-w.x, -w.y));

			//Curl
			float curl = tr.y - tl.y - tu.x + td.x;
			float trCurl = trr.y - data.y - tru.x + trd.x;
			float tlCurl = data.y - tll.y - tlu.x + tld.x;
			float tuCurl = tru.y - tlu.y - tuu.x + data.x;
			float tdCurl = trd.y - tld.y - data.x + tdd.x;

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

				if (_EmittersBuffer[i].shape == 0) {
					newForce.xy += _EmittersBuffer[i].force * _EmittersBuffer[i].direction * 0.001 / (pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower) + 0.0001);
				}
				else {
					newForce.xy += _EmittersBuffer[i].force * normalize(uv - _EmittersBuffer[i].position) * 0.001 / (pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower) + 0.0001);
					//newForce *= length(uv - _EmittersBuffer[i].position) > 0.01 ? 1 : 0;
				}
			}

			data.xy += _dt * (viscForce.xy - _K / _dt * densDif + newForce); //update velocity
			data.xy = max(float2(0, 0), abs(data.xy) - 1e-4) * sign(data.xy); //linear velocity decay

			//Vorticity confinment
			//float2 vort = float2(abs(tu.w) - abs(td.w), abs(tl.w) - abs(tr.w)); 
			float2 vort = float2(abs(tuCurl) - abs(tdCurl), abs(tlCurl) - abs(trCurl));
			vort *= _Vorticity / length(vort + 1e-9) * curl;
			data.xy += vort;

			data.x *= smoothstep(.5, .49, abs(uv.x - 0.5));
			data.y *= smoothstep(.5, .49, abs(uv.y - 0.5)); //Boundaries

			data.xy *= (1.0f - _VelocityAttenuation);

			data = clamp(data, float4(float2(-10, -10), 0.5, -10.), float4(float2(10, 10), 3.0, 10.));

			return data;
		}

		float4 solveFluid3D(sampler3D smp, float3 uv, float3 w, float time)
		{

			float4 t = tex3D(smp, uv);

			float4 tr = tex3D(smp, uv + float3(w.x, 0, 0));
			float4 tl = tex3D(smp, uv - float3(w.x, 0, 0));
			float4 tu = tex3D(smp, uv + float3(0, w.y, 0));
			float4 td = tex3D(smp, uv - float3(0, w.y, 0));
			float4 tb = tex3D(smp, uv + float3(0, 0, w.z));
			float4 tf = tex3D(smp, uv - float3(0, 0, w.z));

			float4 trr = tex3D(smp, uv + 2.0 * float3(w.x, 0, 0));
			float4 tll = tex3D(smp, uv - 2.0 * float3(w.x, 0, 0));
			float4 tuu = tex3D(smp, uv + 2.0 * float3(0, w.y, 0));
			float4 tdd = tex3D(smp, uv - 2.0 * float3(0, w.y, 0));
			float4 tbb = tex3D(smp, uv + 2.0 * float3(0, 0, w.z));
			float4 tff = tex3D(smp, uv - 2.0 * float3(0, 0, w.z));

			float4 tru = tex3D(smp, uv + float3(w.x, w.y, 0));
			float4 trd = tex3D(smp, uv + float3(w.x, -w.y, 0));
			float4 tlu = tex3D(smp, uv + float3(-w.x, w.y, 0));
			float4 tld = tex3D(smp, uv + float3(-w.x, -w.y, 0));

			//float4 truf = tex3D(smp, uv + float3(w.x, w.y, -w.z));
			//float4 trdf = tex3D(smp, uv + float3(w.x, -w.y, -w.z));
			//float4 tluf = tex3D(smp, uv + float3(-w.x, w.y, -w.z));
			//float4 tldf = tex3D(smp, uv + float3(-w.x, -w.y, -w.z));
			float4 trf = tex3D(smp, uv + float3(w.x, 0, -w.z));
			float4 tlf = tex3D(smp, uv + float3(-w.x, 0, -w.z));
			float4 tuf = tex3D(smp, uv + float3(0, w.y, -w.z));
			float4 tdf = tex3D(smp, uv + float3(0, -w.y, -w.z));

			//float4 trub = tex3D(smp, uv + float3(w.x, w.y, w.z));
			//float4 trdb = tex3D(smp, uv + float3(w.x, -w.y, w.z));
			//float4 tlub = tex3D(smp, uv + float3(-w.x, w.y, w.z));
			//float4 tldb = tex3D(smp, uv + float3(-w.x, -w.y, w.z));
			float4 trb = tex3D(smp, uv + float3(w.x, 0, w.z));
			float4 tlb = tex3D(smp, uv + float3(-w.x, 0, w.z));
			float4 tub = tex3D(smp, uv + float3(0, w.y, w.z));
			float4 tdb = tex3D(smp, uv + float3(0, -w.y, w.z));

			//Curl
			//!\ TEXTURE3D uv.z is going front to back but normalized frame as Z axis going from back to front (with X going right and Y up) 

			float3 tCurl = float3(tu.z - td.z - tf.y + tb.y, tf.x - tb.x - tr.z + tl.z, tr.y - tl.y - tu.x + td.x);
			float3 trCurl = float3(tru.z - trd.z - trf.y + trb.y, trf.x - trb.x - trr.z + t.z, trr.y - t.y - tru.x + trd.x);
			float3 tlCurl = float3(tlu.z - tld.z - tlf.y + tlb.y, tlf.x - tlb.x - t.z + tll.z, t.y - tll.y - tlu.x + tld.x);
			float3 tuCurl = float3(tuu.z - t.z - tuf.y + tub.y, tuf.x - tub.x - tru.z + tlu.z, tru.y - tlu.y - tuu.x + t.x);;
			float3 tdCurl = float3(t.z - tdd.z - tdf.y + tdb.y, tdf.x - tdb.x - trd.z + tld.z, trd.y - tld.y - t.x + tdd.x);;
			float3 tfCurl = float3(tuf.z - tdf.z - tff.y + t.y, tff.x - t.x - trf.z + tlf.z, trf.y - tlf.y - tuf.x + tdf.x);
			float3 tbCurl = float3(tub.z - tdb.z - t.y + tbb.y, t.x - tbb.x - trb.z + tlb.z, trb.y - tlb.y - tub.x + tdb.x);

			//Differences
			float4 dx = (tr - tl) * 0.5;
			float4 dy = (tu - td) * 0.5;
			float4 dz = (tf - tb) * 0.5;
			float3 densDif = float3(dx.w, dy.w, dz.w);


			t.w -= _dt * dot(float4(densDif, dx.x + dy.y + dz.z), t); //density
			float3 laplacian = tu.xyz + td.xyz + tr.xyz + tl.xyz + tb.xyz + tf.xyz - 6.0 * t.xyz;
			float3 viscForce = float3(_Viscosity, _Viscosity, _Viscosity) * laplacian;

			t.xyz = tex3D(smp, uv - _dt * t.xyz * w).xyz; //advection

			float3 newForce = float3(0, 0, 0);
			newForce += 0.75 * float3(.0000, 0.003, 0.0000) / (pow(length(uv - float3(0.5, 0.5, 0.5)), 1.75) + 0.0001);

			//Emitters
			//for (int i = 0; i < _EmittersCount; i++) {

			//	if (_EmittersBuffer[i].shape == 0) {
			//		newForce += _EmittersBuffer[i].force * _EmittersBuffer[i].direction * 0.001 / (pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower) + 0.0001);
			//	}
			//	else {
			//		newForce += _EmittersBuffer[i].force * normalize(uv - _EmittersBuffer[i].position) * 0.001 / (pow(length(uv - _EmittersBuffer[i].position), _EmittersBuffer[i].radiusPower) + 0.0001);
			//	}
			//}

			t.xyz += _dt * (viscForce - _K / _dt * densDif + newForce); //update velocity
			t.xyz = max(float3(0, 0, 0), abs(t.xyz) - 1e-4) * sign(t.xyz); //linear velocity decay

			//Vorticity confinment
			//float3 gradCurlNorm = float3(length(trCurl) - length(tlCurl), length(tuCurl) - length(tdCurl), length(tfCurl) - length(tbCurl));
			//float3 sourceVorticity = cross(gradCurlNorm / length(gradCurlNorm + 1e-9), tCurl) * _Vorticity; ///// SHOULD BE MULTIPLIED BY DT ? (cf paper)
			//t.xyz += sourceVorticity;

			//Boundaries
			t.x *= smoothstep(.5, .49, abs(uv.x - 0.5));
			t.y *= smoothstep(.5, .49, abs(uv.y - 0.5));
			t.z *= smoothstep(.5, .49, abs(uv.z - 0.5));

			t.xyz *= (1.0f - _VelocityAttenuation);

			t = clamp(t, float4(float3(-10, -10, -10), 0.5), float4(float3(10, 10, 10), 3.0));

			return t;
		}

		float4 frag(v2f_customrendertexture i) : SV_Target
		{
			float3 uv = i.globalTexcoord;

			float tw = 1.0f / _CustomRenderTextureWidth;
			float th = 1.0f / _CustomRenderTextureHeight;
			float td = 1.0f / _CustomRenderTextureDepth;

			//return solveFluid2D(_SelfTexture2D, uv.xy, float2(tw, th), _AbsoluteTime);
			return solveFluid3D(_SelfTexture3D, uv, float3(tw, th, td), _AbsoluteTime);

			//return float4(uv, 1);
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
