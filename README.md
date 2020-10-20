# Chimera

<p float="left">
  <img src="https://i.imgur.com/a1IjR8z.png" width="400" />
  <img src="https://i.imgur.com/mZV2fNd.png" width="400" /> 
</p>

<p float="left">
  <img src="https://i.imgur.com/FGbvVrF.jpeg" width="400" />
  <img src="https://i.imgur.com/eObGy3T.png" width="400" /> 
</p>

## Presentation

Chimera is a 2D fluid simulation framework in Unity based on [Nimitz's implementation](https://www.shadertoy.com/view/4tGfDW) of the [Simple and fast fluids](https://hal.inria.fr/inria-00596050/document), adding vorticity confinement.

### Experimental results

[Color advection](https://twitter.com/i/status/1297219987426488320)

[Particle advection](https://twitter.com/i/status/1297605129114390534)

[Height from fluid](https://twitter.com/i/status/1297949921312743429)

[Fluid and boids](https://twitter.com/i/status/1298318316034052098)

### Result video

[![Lights of Nibel](https://i.imgur.com/NQfzGDP.png)](https://vimeo.com/458749435)

## Disclaimer

This framework is a **work in progress**, things may change (a lot) or not alway work as expected.

The 3D implementation is not functional for now, you can delete the 3D folders safely.

The 2D example scene works in HDRP since it uses HDRP materials and Visual Effect Graph, but the framework should work in any pipeline.

## Description

The fluid is simulated in a custom render texture, updated with the fluid shader and controlled by the FluidTextureController.cs script.
The velocity of the fluid is stored in the R and G channels of the texture and can be used to create normals, advect colors or particules, or refract light.

The advection texture is used to advect a texture color along the velocity of a fluid texture.

### Fluid Texture Controller

It controls how many times the fluid is updated at each frame. A higher number of updates per frames will make the fluid faster but less detailed.

Its ID is used to link emitters to it.

### Advection Texture Controller

It controls how many times the advection texture is updated at each frame. A higher number of updates per frames will make the advected color move faster.

Its ID is used to link emitters to it.

### Fluid Emitter

To create a fluid emitter add the FluidEmitter.cs script to an object in your scene. Link it to a fluid and/or advection controller via the controllers ID fields.

The position of the emitter is converted from world 3D position to UV 2D position using the position mapping parameter to define which axis to project on. 

The size parameter is used to scale the position of the emitter into the [0,1] texture UV range. Use it if your emitter movement is not in the [0,1] range (i.e. inside a 1x1x1m cube).

The IsCentered parameter is used to determine how to translate the position of the emitter to the [0,1] texture UV range. If checked, the origin (0,0,0) is mapped to the center of the texture (0.5,0.5), if unchecked no mapping is applied and the origin (0,0,0) will map to the bottom left of the texture (0,0).

The forward axis of the emitter object is used to determine 2D emitter direction.

The emitter can create velocity in the linked FluidController texture and/or add color in the linked AdvectionController texture.

## Version

Tested in 2019.4.12f1.

## Acknowledgments

- [Nimitz](https://twitter.com/stormoid) for his shadertoy example.
- Fluid simulation based on [Simple and fast fluids](https://hal.inria.fr/inria-00596050/document) by Martin Guay, Fabrice Colin and Richard Egli.
- Ben Golus for his valuable help on Unity Forums.
