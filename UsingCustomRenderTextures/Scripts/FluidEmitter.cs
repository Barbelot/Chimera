using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FluidEmitter : MonoBehaviour
{
	public enum PositionMapping { XY, XZ, YZ }
	[Header("Position Mapping")]
	public PositionMapping positionMapping = PositionMapping.XY;

	[Header("Fluid Emitter")]
	public FluidTextureController fluidController;
	public bool autoFindFluid = false;
	public float force = 0.75f;

	[Header("Color Emitter")]
	public AdvectionTextureController advectionController;
	public bool autoFindAdvection = false;
	public Color color = Color.white;
	public float intensity = 0.12f;
	public float radiusPower = 1.75f;

	[Header("Gizmos")]
	public bool showGizmos = true;

	[HideInInspector] public Vector2 position = Vector2.zero;
	[HideInInspector] public Vector2 direction = Vector2.one * 0.1f;

	private Vector3 _direction3D = Vector3.zero;

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

		if (autoFindFluid)
			fluidController = FindObjectOfType<FluidTextureController>();

		if (fluidController)
			fluidController.AddEmitter(this);

		if (autoFindAdvection)
			advectionController = FindObjectOfType<AdvectionTextureController>();

		if (advectionController)
			advectionController.AddEmitter(this);
	}

	void UpdateEmitter() {

		switch (positionMapping) {
			case PositionMapping.XY:
				position.x = transform.position.x;
				position.y = transform.position.y;
				_direction3D = Vector3.ProjectOnPlane(transform.forward, Vector3.back);
				direction.x = _direction3D.x;
				direction.y = _direction3D.y;
				break;
			case PositionMapping.XZ:
				position.x = transform.position.x;
				position.y = transform.position.z;
				_direction3D = Vector3.ProjectOnPlane(transform.forward, Vector3.up);
				direction.x = _direction3D.x;
				direction.y = _direction3D.z;
				break;
			case PositionMapping.YZ:
				position.x = transform.position.y;
				position.y = transform.position.z;
				_direction3D = Vector3.ProjectOnPlane(transform.forward, Vector3.right);
				direction.x = _direction3D.y;
				direction.y = _direction3D.z;
				break;
		}
	}

	void RemoveEmitter() {

		if(fluidController)
			fluidController.RemoveEmitter(this);

		if (advectionController)
			advectionController.RemoveEmitter(this);
	}
}
