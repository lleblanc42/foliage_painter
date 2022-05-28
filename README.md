Scene scattering tool for Godot Engine
=========================================

![scatter_plugin](https://user-images.githubusercontent.com/1311555/61177048-a3fd4100-a5c3-11e9-8771-8667465ce439.gif)

This plugin adds tools to help placing many scene instances in an environment by "painting" over it, rather than dragging and dropping them manually from the file system dock.

It adds a new node `Foliage3D`.


Installation
--------------

This is a regular editor plugin.
Copy the contents of `addons/foliage_painter` into the same folder in your project, and activate it in your project settings.


How to use
--------------

- Have a scene with collisions in it, for example a ground, terrain, building...
- Add scenes you wish to be able to paint into the list, and select the one you want to paint
- Start placing them by left-clicking in the scene. 
  - This will create scene instances as child of the `Foliage3D` node.


original project:https://github.com/Zylann/godot_scatter_plugin

License
---------

- ![License file](addons/zylann.scatter/LICENSE.md)
