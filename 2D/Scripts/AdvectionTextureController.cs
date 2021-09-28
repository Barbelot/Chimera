﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Chimera
{
	public class AdvectionTextureController : MonoBehaviour
	{
		[Header("Advection Controller ID")]
		public string ID;

		[Header("Custom Render Textures")]
		public CustomRenderTexture advectionTexture;

		[Header("Advection Parameters")]
		[Range(0, 10)] public int updatesPerFrame = 1;

		public enum UpdateMode { Update, FixedUpdate, LateUpdate }
		public UpdateMode updateMode = UpdateMode.Update;

		[Header("Debug")]
		public bool reinitialize = false;

		public struct Emitter
		{
			public Vector2 position;
			public Color color;
			public float intensity;
			public float radius;
		}

		private const int _advectionEmitterSize = 8 * sizeof(float);

		private ComputeBuffer _emittersBuffer;
		private List<FluidEmitter2D> _emittersList;
		private Emitter[] _emittersArray;

		private Material advectionMaterial;

		private bool _initialized = false;

		#region MonoBehaviour Functions

		private void OnEnable() {

			if (!_initialized)
				Initialize();
		}

		void Update() {
			if (updateMode == UpdateMode.Update)
				UpdateAdvection();
		}

		void FixedUpdate() {
			if (updateMode == UpdateMode.FixedUpdate)
				UpdateAdvection();
		}

		void LateUpdate() {
			if (updateMode == UpdateMode.LateUpdate)
				UpdateAdvection();
		}

		private void OnDisable() {

			if (_initialized)
				CleanUp();
		}

		#endregion

		void Initialize() {

			advectionMaterial = advectionTexture.material;

			//Initialize emitters
			InitializeEmitters();

			//Initialize advection texture
			advectionTexture.Initialize();

			_initialized = true;
		}

		void UpdateAdvection() {
			if (!_initialized) {
				Initialize();
				return;
			}

			//Update emitters
			UpdateEmittersBuffer();

			//Update advection texture
			advectionTexture.Update(updatesPerFrame);

			//Debug
			if (reinitialize) {
				advectionTexture.Initialize();
				reinitialize = false;
			}
		}

		void CleanUp() {

			ReleaseEmittersBuffer();

			_initialized = false;
		}

		#region Emitters

		void InitializeEmitters() {

			CreateEmittersList();
			CreateEmittersArray();
			CreateEmittersBuffer();
		}

		void CreateEmittersList() {

			_emittersList = new List<FluidEmitter2D>();
		}

		void CreateEmittersArray() {

			_emittersArray = _emittersList.Count > 0 ? new Emitter[_emittersList.Count] : new Emitter[1];
		}

		void CreateEmittersBuffer() {

			if (_emittersBuffer != null)
				_emittersBuffer.Release();

			_emittersBuffer = _emittersList.Count > 0 ? new ComputeBuffer(_emittersList.Count, _advectionEmitterSize) : new ComputeBuffer(1, _advectionEmitterSize);

			UpdateEmittersBuffer();
		}

		void UpdateEmittersArray() {

			if (_emittersArray.Length != _emittersList.Count)
				CreateEmittersArray();

			for (int i = 0; i < _emittersList.Count; i++) {
				_emittersArray[i].position = _emittersList[i].position;
				_emittersArray[i].color = _emittersList[i].color;
				_emittersArray[i].intensity = _emittersList[i].intensity;
				_emittersArray[i].radius = _emittersList[i].colorRadius;
			}
		}

		void UpdateEmittersBuffer() {

			UpdateEmittersArray();

			_emittersBuffer.SetData(_emittersArray);

			advectionMaterial.SetBuffer("_EmittersBuffer", _emittersBuffer);
			advectionMaterial.SetInt("_EmittersCount", _emittersList.Count);
		}

		void ReleaseEmittersBuffer() {

			_emittersBuffer.Release();
		}

		public void AddEmitter(FluidEmitter2D emitter) {

			if (!_initialized)
				Initialize();

			_emittersList.Add(emitter);

			CreateEmittersBuffer();
		}

		public void RemoveEmitter(FluidEmitter2D emitter) {

			_emittersList.Remove(emitter);

			CreateEmittersBuffer();
		}

		void DebugEmittersList() {

			Debug.Log("EmittersListCount = " + _emittersList.Count);

			for (int i = 0; i < _emittersList.Count; i++) {
				//Debug.Log("Emitter " + i + " : position = " + _emittersList[i].position + "; direction = " + _emittersList[i].direction + "; force = " + _emittersList[i].force);
			}
		}

		#endregion
	}
}
