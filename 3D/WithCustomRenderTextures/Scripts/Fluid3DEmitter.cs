using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Chimera
{
	public class Fluid3DEmitter : MonoBehaviour
	{
		public enum EmitterShape { Directional, Circular }
		[Header("Shape")]
		public EmitterShape shape = EmitterShape.Directional;

		[Header("Position Mapping")]
		[Tooltip("Size of your fluid area in meters.")] public Vector3 size = Vector3.one;
		[Tooltip("Is your emitter centered on its origin ?")] public bool isCentered = false;

		[Header("Fluid Emitter")]
		public string fluidControllerID;
		public float force = 0.75f;
		public float forceRadiusPower = 2.0f;

		[Header("Color Emitter")]
		public string advectionControllerID;
		public Color color = Color.white;
		public float intensity = 0.12f;
		public float colorRadiusPower = 1.75f;

		[Header("Gizmos")]
		public bool showGizmos = true;

		[HideInInspector] public Vector3 position = Vector3.zero;
		[HideInInspector] public Vector3 direction = Vector3.one * 0.1f;

		private Fluid3DTextureController _fluidController;
		private Advection3DTextureController _advectionController;

		private void OnEnable() {

			AddEmitter();
			UpdateEmitter();
		}

		private void Update() {

			UpdateEmitter();
		}

		private void OnDisable() {

			RemoveEmitter();
		}

		private void OnDrawGizmos() {

			if (!showGizmos)
				return;

			Gizmos.color = Color.yellow;

			Gizmos.DrawLine(transform.position, transform.position + transform.forward * force * 0.5f);
		}

		void AddEmitter() {

			foreach (var controller in FindObjectsOfType<Fluid3DTextureController>()) {
				if (controller.ID == fluidControllerID) {
					_fluidController = controller; break;
				}
			}

			if (_fluidController)
				_fluidController.AddEmitter(this);

			foreach (var controller in FindObjectsOfType<Advection3DTextureController>()) {
				if (controller.ID == advectionControllerID) {
					_advectionController = controller; break;
				}
			}

			if (_advectionController)
				_advectionController.AddEmitter(this);
		}

		void UpdateEmitter() {

			position.x = isCentered ? transform.position.x / size.x + 0.5f : transform.position.x / size.x;
			position.y = isCentered ? transform.position.y / size.y + 0.5f : transform.position.y / size.y;
			position.z = isCentered ? transform.position.z / size.z + 0.5f : transform.position.z / size.z;
			direction = transform.forward;
		}

		void RemoveEmitter() {

			if (_fluidController)
				_fluidController.RemoveEmitter(this);

			if (_advectionController)
				_advectionController.RemoveEmitter(this);
		}
	}
}
