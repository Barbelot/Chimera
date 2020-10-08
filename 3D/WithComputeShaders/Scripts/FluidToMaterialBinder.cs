using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Chimera
{
    public class FluidToMaterialBinder : MonoBehaviour
    {
        public FluidController fluidController;
        public Material material;
        public string property;
        public bool bindFluidTexture;
        public bool bindOutputTexture;

        void OnEnable() {
            material.SetTexture(property, fluidController.GetFluidTexture());
        }

		private void Update() {

			if (bindFluidTexture) {
                material.SetTexture(property, fluidController.GetFluidTexture());
                bindFluidTexture = false;
            }

            if (bindOutputTexture) {
                material.SetTexture(property, fluidController.GetOutputTexture());
                bindOutputTexture = false;
            }
        }
	}
}
