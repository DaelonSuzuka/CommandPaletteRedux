# A Godot Command Palette

**Changelog for 1.5.0**:

- basic integration to access https://github.com/fenix-hub/godot-engine.text-editor and https://github.com/need12648430/godot3-todo via command palette. **I have no affiliation with any of those plugins. I only use them personally.**
- Open documentation pages are now included in the default list.
- context menu for the FileSystemDock, NodeDock and SceneTreeDock (via a button on the right).
- signal connection via a button using the "select a node" filter.
- removed export vars and moved them to a dedicated settings page. Available: hide script panel on start, show docs in default list, keywords for filters, keyboard shortcut, popup size, adaptive popup size, show path for recent files

- **See the built-in help page (type "?") on how to use the features.**


**Features**:

- Open any file. Filter by type or name. 
- Select any node in the current scene. Add a new script to a node.
- Edit Inspector properties of the currently selected node.
- Edit general Project/Editor settings. Add new Project settings.
- Traverse the file tree with autocompletion on paths (list all files and folders in a given path; see .gif).
- Go to line.
- Go to method.
- Quickswitch to the last file opened.

*Minor stuff*:

- A copy button is available to the right of the search LineEdit. This way you can quickly copy the file/node/settings/node property paths.
- Opening a script also opens the scene, which the script is attached to. This gives you autocompletion on the Node(Paths) and their methods.
- Ending the search_string with "  " (double space) will autocomplete file/node/settings path.


**Installation**:

Either download it from the official Godot AssetLib (within Godot itself) or download the addons folder from here and move it to the root (res://) of your project. Enable the plugin in the project settings.

**Usage**:

* Install via instructions above
* On Windows / Linux press "Ctrl+P" to open, on Mac press "Cmd+P"

**Preview**

![Preview2](preview2.gif)
![Preview](preview.png)
