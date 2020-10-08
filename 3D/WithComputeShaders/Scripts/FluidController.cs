using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices.WindowsRuntime;
using UnityEngine;
using UnityEngine.UI;

namespace Chimera
{
	public class FluidController : MonoBehaviour
	{
		[Header("Compute Shader")]
		public ComputeShader fluidCompute;

		[Header("Textures Settings")]
		public Vector2Int textureSize = Vector2Int.one * 2048;

		[Header("Fluid Settings")]
		public int updatesPerFrameCount = 1;
		public float dt = 0.15f;
		[Range(0.03f, 0.2f)] public float vorticity = 0.11f;

		[Header("Debug")]
		public bool update;

		private RenderTexture _fluidTextureRead, _fluidTextureWrite, _outputTextureRead, _outputTextureWrite;

		private int _fluidInitKernel;
		private int _fluidUpdateKernel;
		private int _outputUpdateKernel;

		private int _numThreadsPerGroup = 8;
		private Vector2Int _numThreadGroup;

		private bool _initialized = false;

		#region MonoBehaviour Functions

		private void OnEnable() {

			if (!_initialized)
				Initialize();
		}

		private void Update() {

			if (!_initialized)
				Initialize();

			for (int i = 0; i < updatesPerFrameCount; i++) {
				//Update fluid
				UpdateFluid();
			}

			//Update output
			UpdateOutput();

			if (update) {
				UpdateFluid();
				update = false;
			}
		}

		#endregion

		public RenderTexture GetFluidTexture() {

			if (!_initialized)
				Initialize();

			return _fluidTextureRead;
		}

		public RenderTexture GetOutputTexture() {

			if (!_initialized)
				Initialize();

			return _outputTextureRead;
		}

		void Initialize() {

			//Create textures
			CreateFluidTextures();
			CreateOutputTexture();

			//Initialize compute shader
			InitializeComputeShaderParameters();

			//Initialize fluid
			InitializeFluid();

			_initialized = true;
		}

		void CreateFluidTextures() {

			_fluidTextureRead = new RenderTexture(textureSize.x, textureSize.y, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
			_fluidTextureRead.enableRandomWrite = true;
			_fluidTextureRead.Create();

			_fluidTextureWrite = new RenderTexture(textureSize.x, textureSize.y, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
			_fluidTextureWrite.enableRandomWrite = true;
			_fluidTextureWrite.Create();
		}

		void CreateOutputTexture() {

			_outputTextureRead = new RenderTexture(textureSize.x, textureSize.y, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
			_outputTextureRead.enableRandomWrite = true;
			_outputTextureRead.Create();

			_outputTextureWrite = new RenderTexture(textureSize.x, textureSize.y, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
			_outputTextureWrite.enableRandomWrite = true;
			_outputTextureWrite.Create();
		}

		void InitializeComputeShaderParameters() {

			//Get kernels indices
			_fluidInitKernel = fluidCompute.FindKernel("FluidInit");
			_fluidUpdateKernel = fluidCompute.FindKernel("FluidUpdate");
			_outputUpdateKernel = fluidCompute.FindKernel("OutputUpdate");

			//Compute thread group size
			_numThreadGroup = new Vector2Int(textureSize.x / _numThreadsPerGroup, textureSize.y / _numThreadsPerGroup);
		}

		void InitializeFluid() {

			fluidCompute.SetInt("_FluidTextureWidth", textureSize.x);
			fluidCompute.SetInt("_FluidTextureHeight", textureSize.y);
			fluidCompute.SetTexture(_fluidInitKernel, "_FluidTextureRead", _fluidTextureRead);
			fluidCompute.SetTexture(_fluidInitKernel, "_FluidTextureWrite", _fluidTextureWrite);

			fluidCompute.Dispatch(_fluidInitKernel, _numThreadGroup.x, _numThreadGroup.y, 1);

			Graphics.CopyTexture(_fluidTextureWrite, _fluidTextureRead);
		}

		void UpdateFluid() {

			fluidCompute.SetTexture(_fluidUpdateKernel, "_FluidTextureRead", _fluidTextureRead);
			fluidCompute.SetTexture(_fluidUpdateKernel, "_FluidTextureWrite", _fluidTextureWrite);
			fluidCompute.SetFloat("_AbsoluteTime", Time.time);
			fluidCompute.SetFloat("_Dt", dt);
			fluidCompute.SetFloat("_Vorticity", vorticity);

			fluidCompute.Dispatch(_fluidUpdateKernel, _numThreadGroup.x, _numThreadGroup.y, 1);

			Graphics.CopyTexture(_fluidTextureWrite, _fluidTextureRead);
		}

		void UpdateOutput() {

			fluidCompute.SetTexture(_outputUpdateKernel, "_OutputTextureRead", _outputTextureRead);
			fluidCompute.SetTexture(_outputUpdateKernel, "_OutputTextureWrite", _outputTextureWrite);
			fluidCompute.SetTexture(_outputUpdateKernel, "_FluidTextureRead", _fluidTextureRead);
			fluidCompute.SetFloat("_AbsoluteTime", Time.time);
			fluidCompute.SetFloat("_Dt", dt);

			fluidCompute.Dispatch(_outputUpdateKernel, _numThreadGroup.x, _numThreadGroup.y, 1);

			Graphics.CopyTexture(_outputTextureWrite, _outputTextureRead);
		}
	}
}
