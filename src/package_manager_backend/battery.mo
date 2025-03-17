import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Map "mo:base/OrderedMap";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Common "../common";
import MainIndirect "main_indirect";
import env "env";

shared({caller = initialOwner}) actor class Battery({
    packageManagerOrBootstrapper: Principal;
    mainIndirect: Principal;
    simpleIndirect: Principal;
    user: Principal;
    installationId = _: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (mainIndirect, ()), // temporary
                (simpleIndirect, ()), // TODO: superfluous?
                (Principal.fromActor(this), ()), // to execute the timer
                (user, ()),
            ].vals(), // TODO: Are all required?
            5,
            Principal.equal,
            Principal.hash);

    func onlyOwner(caller: Principal, msg: Text) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner: " # msg);
        };
    };

    public shared({caller}) func setOwners(newOwners: [Principal]): async () {
        onlyOwner(caller, "setOwners");

        owners := HashMap.fromIter(
            Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (owner: Principal): (Principal, ()) = (owner, ())),
            Array.size(newOwners),
            Principal.equal,
            Principal.hash,
        );
    };

    public shared({caller}) func addOwner(newOwner: Principal): async () {
        onlyOwner(caller, "addOwner");

        owners.put(newOwner, ());
    };

    public shared({caller}) func removeOwner(oldOwner: Principal): async () {
        onlyOwner(caller, "removeOwner");

        owners.delete(oldOwner);
    };

    public query func getOwners(): async [Principal] {
        Iter.toArray(owners.keys());
    };

    stable var initialized = false;

    public shared({caller}) func init() : async () {
        onlyOwner(caller, "init");
        if (initialized) {
            Debug.trap("already initialized");
        };

        initTimer<system>();

        initialized := true;
    };

    let revenueRecipient = Principal.fromText(env.revenueRecipient);

    private type OurPMType = actor {
        // getModulePrincipal: query (installationId: Common.InstallationId, moduleName: Text) -> async Principal;
        getAllCanisters: query () -> async [({packageName: Text; guid: Blob}, [(Text, Principal)])];
    };

    private func getPM(): OurPMType {
        actor(Principal.toText(packageManagerOrBootstrapper));
    };

    private func getMainIndirect(): MainIndirect.MainIndirect {
        actor(Principal.toText(mainIndirect));
    };

    public type ModuleLocation = {
        package: {
            packageName: Text;
            guid: Blob;
        };
        moduleName: Text;
    };

    private func compareModuleLocation(a: ModuleLocation, b: ModuleLocation): {#less; #equal; #greater;} {
        switch (Text.compare(a.package.packageName, b.package.packageName)) {
            case (#less) {
                #less;
            };
            case (#equal) {
                switch (Blob.compare(a.package.guid, b.package.guid)) {
                case (#less) {
                    #less;
                };
                case (#equal) {
                    Text.compare(a.moduleName, b.moduleName);
                };
                case (#greater) {
                    #greater;
                };
                };
            };
            case (#greater) {
                #greater;
            };
        };
    };

    public type CanisterKind = Text;

    let moduleLocationMap = Map.Make<ModuleLocation>(compareModuleLocation);
    public type CanisterMap = Map.Map<ModuleLocation, CanisterKind>;

    let textMap = Map.Make<Text>(Text.compare);
    public type CanisterKindsMap = Map.Map<CanisterKind, Common.CanisterFulfillment>;

    public type Battery = {
        defaultFulfillment: Common.CanisterFulfillment;
        canisterMap: CanisterMap;
        canisterKindsMap: CanisterKindsMap;
        /// The number of cycles from which the fee has been already paid.
        var activatedCycles;
    };

    private func newBattery(): Battery =
        {
            defaultFulfillment = {
                threshold = 3_000_000_000_000;
                installAmount = 2_000_000_000_000;
            };
            canisterMap = moduleLocationMap.empty<CanisterKind>();
            canisterKindsMap = textMap.empty<Common.CanisterFulfillment>();
            activatedCycles = 0;
        };

    // TODO:
    // public func insertCanisterKind(battery: Battery, kind: Text, info: Common.CanisterFulfillment) {
    //     OrderedMap.put(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind, info);
    // };

    func initTimer<system>() {
        timer := ?(Timer.recurringTimer<system>(#seconds 3600, topUpAllCanisters)); // TODO: editable period
    };

    stable let battery = newBattery();

    stable var timer: ?Timer.TimerId = null;

    private func topUpOneCanister(canister: ModuleLocation, canister_id: Principal): async* () {
        let info0 = do ? {
            let kind = moduleLocationMap.get(battery.canisterMap, canister)!;
            textMap.get(battery.canisterKindsMap, kind)!;
        };
        let fulfillment = switch (info0) {
            case (?x) {
                x;
            };
            case (null) {
                battery.defaultFulfillment;
            };
        };
        // FIXME: Balance may decrease a little during the call.
        Cycles.add<system>(Cycles.balance()); // It will be only a part of it used.
        getMainIndirect().topUpOneCanisterFinish(canister_id, fulfillment);
    };

    private func topUpAllCanisters(): async () {
        let newCycles = Cycles.balance() - battery.activatedCycles;
        if (newCycles != 0) {
            let fee = newCycles * 0.05; // 5%
            CyclesLedger.transferCycles(revenueRecipient, fee);
            battery.activatedCycles += newCycles - fee;
        };

        let allCanisters = await getPM().getAllCanisters();
        
        for (entry in allCanisters.vals()) {
            let pkg = entry.0;
            let modules = entry.1;
            
            for (moduleEntry in modules.vals()) {
                let moduleName = moduleEntry.0;
                let canister_id = moduleEntry.1;
                
                let location: ModuleLocation = {
                    package = {
                        packageName = pkg.packageName;
                        guid = pkg.guid;
                    };
                    moduleName = moduleName;
                };
                
                await* topUpOneCanister(location, canister_id);
            };
        };
    };

    system func inspect({
        caller : Principal;
    }): Bool {
        onlyOwner(caller, "inspect"/*TODO*/);
        true;
    };

    system func preupgrade() {
        _ownersSave := Iter.toArray(owners.entries());
    };

    system func postupgrade() {
        initTimer<system>();

        owners := HashMap.fromIter(
            _ownersSave.vals(),
            Array.size(_ownersSave),
            Principal.equal,
            Principal.hash,
        );
        _ownersSave := []; // Free memory.
    };
}