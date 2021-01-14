using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Chimera
{
	public class Fluid3DTextureController : MonoBehaviour
	{
		[Header("Fluid Controller ID")]
		public string ID;

		[Header("Custom Render Textures")]
		public CustomRenderTexture fluidTexture;

		[Header("Fluid Parameters")]
		[Range(0, 10)] public int updatesPerFrame = 4;

		[Header("Debug")]
		public bool reinitialize = false;

		public struct Emitter
		{
			public Vector3 position;
			public Vector3 direction;
			public float force;
			public float radiusPower;
			public float shape;
		}

		private const int _fluidEmitterSize = 9 * sizeof(float);

		private ComputeBuffer _emittersBuffer;
		private List<Fluid3DEmitter> _emittersList;
		private Emitter[] _emittersArray;

		private Material fluidMaterial;

		private bool _initialized = false;

		#region MonoBehaviour Functions

		private void OnEnable() {

			if (!_initialized)
				Initialize();
		}

		void Update() {
			if (!_initialized) {
				Initialize();
				return;
			}

			//Update shader time
			fluidMaterial.SetFloat("_AbsoluteTime", Time.time);

			//Update emitters
			UpdateEmittersBuffer();

			//Update fluid texture
			fluidTexture.Update(updatesPerFrame);

			//Debug
			if (reinitialize) {
				fluidTexture.Initialize();
				reinitialize = false;
			}
		}

		private void OnDisable() {

			ReleaseEmittersBuffer();
		}

		#endregion

		void Initialize() {

			fluidMaterial = fluidTexture.material;

			//Initialize emitters
			InitializeEmitters();

			//Initialize fluid texture
			fluidTexture.Initialize();

			_initialized = true;
		}

		#region Emitters

		void InitializeEmitters() {

			CreateEmittersList();
			CreateEmittersArray();
			CreateEmittersBuffer();
		}

		void CreateEmittersList() {

			_emittersList = new List<Fluid3DEmitter>();
		}

		void CreateEmittersArray() {

			_emittersArray = _emittersList.Count > 0 ? new Emitter[_emittersList.Count] : new Emitter[1];
		}

		void CreateEmittersBuffer() {

			if (_emittersBuffer != null)
				_emittersBuffer.Release();

			_emittersBuffer = _emittersList.Count > 0 ? new ComputeBuffer(_emittersList.Count, _fluidEmitterSize) : new ComputeBuffer(1, _fluidEmitterSize);

			UpdateEmittersBuffer();
		}

		void UpdateEmittersArray() {

			if (_emittersArray.Length != _emittersList.Count)
				CreateEmittersArray();

			for (int i = 0; i < _emittersList.Count; i++) {
				_emittersArray[i].position = _emittersList[i].position;
				_emittersArray[i].direction = _emittersList[i].direction;
				_emittersArray[i].force = _emittersList[i].force;
				_emittersArray[i].radiusPower = _emittersList[i].forceRadiusPower;
				_emittersArray[i].shape = _emittersList[i].shape == Fluid3DEmitter.EmitterShape.Directional ? 0 : 1;
			}
		}

		void UpdateEmittersBuffer() {

			UpdateEmittersArray();

			_emittersBuffer.SetData(_emittersArray);

			fluidMaterial.SetBuffer("_EmittersBuffer", _emittersBuffer);
			fluidMaterial.SetInt("_EmittersCount", _emittersList.Count);
		}

		void ReleaseEmittersBuffer() {

			_emittersBuffer.Release();
		}

		public void AddEmitter(Fluid3DEmitter emitter) {

			if (!_initialized)
				Initialize();

			_emittersList.Add(emitter);

			CreateEmittersBuffer();
		}

		public void RemoveEmitter(Fluid3DEmitter emitter) {

			_emittersList.Remove(emitter);

			CreateEmittersBuffer();
		}

		void DebugEmittersList() {

			Debug.Log("EmittersListCount = " + _emittersList.Count);

			for (int i = 0; i < _emittersList.Count; i++) {
				Debug.Log("Emitter " + i + " : position = " + _emittersList[i].position + "; direction = " + _emittersList[i].direction + "; force = " + _emittersList[i].force);
			}
		}

		#endregion
	}
}
