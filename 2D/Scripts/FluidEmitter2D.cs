using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Chimera
{
	public class FluidEmitter2D : MonoBehaviour
	{
		public enum EmitterShape { Directional, Circular }
		[Header("Shape")]
		public EmitterShape shape = EmitterShape.Directional;
		public bool normalizeDirection = false;

		public enum PositionMapping { XY, XZ, YZ }
		[Header("Position Mapping")]
		public PositionMapping positionMapping = PositionMapping.XY;
		[Tooltip("Size of your fluid area in meters.")] public Vector2 size = Vector2.one;
		[Tooltip("Is your emitter centered on its origin ?")] public bool isCentered = false;

		[Header("Fluid Emitter")]
		public string fluidControllerID;
		public float force = 1.0f;
		public float forceRadius = 0.1f;

		[Header("Color Emitter")]
		public string advectionControllerID;
		public Color color = Color.white;
		public float intensity = 1.0f;
		public float colorRadius = 0.05f;

		[Header("Gizmos")]
		public bool showGizmos = true;

		[HideInInspector] public Vector2 position = Vector2.zero;
		[HideInInspector] public Vector2 direction = Vector2.one * 0.1f;

		private FluidTextureController _fluidController;
		private AdvectionTextureController _advectionController;

		private Vector3 _direction3D = Vector3.zero;
		private Vector3 _previousPosition;

		private bool _isPreviousPositionValid = false;

		private void OnEnable() {

			AddEmitter();
			UpdateEmitter();
		}

		private void Update() {

			if(_fluidController.updateMode == FluidTextureController.UpdateMode.Update)
				UpdateEmitter();
		}

		private void FixedUpdate() {

			if (_fluidController.updateMode == FluidTextureController.UpdateMode.FixedUpdate)
				UpdateEmitter();
		}

		private void LateUpdate() {

			if (_fluidController.updateMode == FluidTextureController.UpdateMode.LateUpdate)
				UpdateEmitter();
		}

		private void OnDisable() {

			RemoveEmitter();
		}

		private void OnDrawGizmos() {

			if (!showGizmos)
				return;

			Gizmos.color = Color.yellow;

			switch (positionMapping) {
				case PositionMapping.XY:
					_direction3D = Vector3.ProjectOnPlane(transform.forward, Vector3.back);
					break;
				case PositionMapping.XZ:
					_direction3D = Vector3.ProjectOnPlane(transform.forward, Vector3.up);
					break;
				case PositionMapping.YZ:
					_direction3D = Vector3.ProjectOnPlane(transform.forward, Vector3.right);
					break;
			}

			Gizmos.DrawLine(transform.position, transform.position + _direction3D * force * 0.5f);
		}

		void AddEmitter() {

			foreach (var controller in FindObjectsOfType<FluidTextureController>()) {
				if (controller.ID == fluidControllerID) {
					_fluidController = controller; break;
				}
			}

			if (_fluidController)
				_fluidController.AddEmitter(this);

			foreach (var controller in FindObjectsOfType<AdvectionTextureController>()) {
				if (controller.ID == advectionControllerID) {
					_advectionController = controller; break;
				}
			}

			if (_advectionController)
				_advectionController.AddEmitter(this);
		}

		void UpdateEmitter() {

			if (!_isPreviousPositionValid) {
				_previousPosition = transform.position;
				_isPreviousPositionValid = true;
				return;
			}

			_direction3D = transform.position - _previousPosition;

			switch (positionMapping) {
				case PositionMapping.XY:
					position.x = isCentered ? transform.position.x / size.x + 0.5f : transform.position.x / size.x;
					position.y = isCentered ? transform.position.y / size.y + 0.5f : transform.position.y / size.y;
					_direction3D = normalizeDirection ? Vector3.ProjectOnPlane(_direction3D, Vector3.back).normalized : Vector3.ProjectOnPlane(_direction3D, Vector3.back);
					direction.x = _direction3D.x;
					direction.y = _direction3D.y;
					break;
				case PositionMapping.XZ:
					position.x = isCentered ? transform.position.x / size.x + 0.5f : transform.position.x / size.x;
					position.y = isCentered ? transform.position.z / size.y + 0.5f : transform.position.z / size.y;
					_direction3D = normalizeDirection ? Vector3.ProjectOnPlane(_direction3D, Vector3.up).normalized : Vector3.ProjectOnPlane(_direction3D, Vector3.up);
					direction.x = _direction3D.x;
					direction.y = _direction3D.z;
					break;
				case PositionMapping.YZ:
					position.x = isCentered ? transform.position.y / size.x + 0.5f : transform.position.y / size.x;
					position.y = isCentered ? transform.position.z / size.y + 0.5f : transform.position.z / size.y;
					_direction3D = normalizeDirection ? Vector3.ProjectOnPlane(_direction3D, Vector3.right).normalized : Vector3.ProjectOnPlane(_direction3D, Vector3.right);
					direction.x = _direction3D.y;
					direction.y = _direction3D.z;
					break;
			}

			_previousPosition = transform.position;
		}

		void RemoveEmitter() {

			if (_fluidController)
				_fluidController.RemoveEmitter(this);

			if (_advectionController)
				_advectionController.RemoveEmitter(this);
		}
	}
}
