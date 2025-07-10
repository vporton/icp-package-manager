To add a package to repository, you first create WASM blobs and then upload the package:

```typescript
const pmExampleFrontendBlob: Uint8Array = ...;
const pmExampleBackendBlob: Uint8Array = ...;
const pmExampleFrontend = await repositoryIndex.uploadModule({
    code: {Assets: {assets: Principal.fromText(...), wasm: pmExampleFrontendBlob}},
    installByDefault: true, // whether to install this module
    forceReinstall: false, // For this module, instead of upgrades do reinstall
    callbacks: [],
});
const pmExampleBackend = await repositoryIndex.uploadModule({
    code: {Wasm: pmExampleBackendBlob},
    installByDefault: true,
    forceReinstall: false,
    callbacks: [],
});
const efReal: SharedRealPackageInfo = {
    modules: [ // The order isn't significant.
        ['example1', pmExampleFrontend],
        ['example2', pmExampleBackend],
    ],
    dependencies: [],
    suggests: [],
    recommends: [],
    functions: [],
    permissions: [],
    checkInitializedCallback: [{moduleName: 'example1', how: {urlPath: '/index.html'}}], // how to check whether package's installation finished
    frontendModule: ['example1'], // Each package can have up to one _frontend_ module.
};
const pmEFInfo: SharedPackageInfo = {
    base: {
        name: "example",
        version: "0.0.1",
        price: 0n,
        shortDescription: "Example package",
        longDescription: "Used as an example",
        guid: Uint8Array.from([39, 165, 164, 221, 113,  51,  73,  53, 145, 150,  31,  42, 238, 133, 124, 210]), // 16 random 0..255
    },
    specific: {real: efReal},
};
const pmEFFullInfo: SharedFullPackageInfo = {
    packages: [["0.0.1", pmEFInfo]],
    versionsMap: [["stable", "0.0.1"]],
};
await repositoryIndex.setFullPackageInfo("example", pmEFFullInfo); // overrides all packages with this name (warnings: this may remove its old versions)
```

**Warning:** The fields `dependencies`, `suggests`, `recommends` are currently unsupported.
Also `functions` and `permissions` are unsupported.