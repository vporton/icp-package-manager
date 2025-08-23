# IC Pack - current plans

Currently I work on the following:

- I added "additional controllers" to package manager.
    - It allows to use the DFX's controller to control the local copy of the PM during development.
- I will allow the developer (manually or on Git commit) to call upgrade of an installed package (in development),
  and if success, automatically upload its last version (such as WASMs) to the remote repository.
- On remote repository there will be stored all old versions.
- Enumerating through all old versions, the end user will be able to upgrade a package seamlessly,
  passing through migration functions (if any) and regular upgrades.