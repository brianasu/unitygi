## Light bleeding library for Unity
Simple light bleeding library for unity 4.5+ that simulates global illumination. Works on mac and dx9+ windows.

### Shaders
4 shaders are included in this package

* Diffuse + Normal
* Transparent + Normal
* Transparent Cutout + Normal
* Additive Particle

### Usage
1. Drop simple voxelisaion/Prefabs/Light Bleeding.prefab into your scene
2. Set volume bounds to surround your scene
3. Adjust setting.
 * Voxel Size controls the resolution of the voxelized scene
 * Propogation steps controls the blur amount
 * Flux Res gives the size of the render texture used for generating depth/normals/flux
 * Color strength = 1 - strength of the global illumination

### Notes
This library only does simple colour bleeding using a spatial blur. SPH are not implemented.

