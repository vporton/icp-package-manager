import { useMemo } from "react";

export function getIsLocal() {
    return useMemo(() => /localhost/.test(document.location.hostname), []);
}