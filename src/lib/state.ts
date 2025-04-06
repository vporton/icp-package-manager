import { useMemo } from "react";

let _isLocal: boolean | undefined;

export function getIsLocal() {
    if (_isLocal === undefined) {
        _isLocal =  /localhost/.test(document.location.hostname);
    }
    return _isLocal;
}