import React, { ReactNode, createContext, useContext, useEffect, useState } from "react";

export interface BusyContextType {
    busy: boolean,
    setBusy: (busy: boolean) => void,
}

const defaultBusyContext: BusyContextType = {
    busy: false,
    setBusy: (busy: boolean) => {},
};

export const BusyContext = createContext<BusyContextType>(defaultBusyContext);

export const BusyProvider: React.FC<{children: React.ReactNode}> = (props: { children: ReactNode }) => {
    const [busy, setBusy] = useState(false);
    const value: BusyContextType = {busy, setBusy};
    return <BusyContext.Provider value={value}>{props.children}</BusyContext.Provider>;
}

export const BusyWidget: React.FC<{children: React.ReactNode}> = (props: { children: ReactNode }) => {
    const {busy} = useContext(BusyContext);
    useEffect(() => {
        document.addEventListener('DOMContentLoaded', function () {
            const overlay = document.getElementById('overlay')!;
        
            // Prevent focus on elements inside the overlay
            overlay.addEventListener('focus', (event) => {
                event.stopPropagation();
                overlay.focus();
            }, true);
        
            // Handler to intercept all keyboard events
            overlay.addEventListener('keydown', (event) => {
                event.stopPropagation();
                event.preventDefault();
            });
        
            // Intercept all click events
            overlay.addEventListener('click', (event) => {
                event.stopPropagation();
                event.preventDefault();
            });
        
            // Force focus on the overlay
            overlay.tabIndex = 0;
            overlay.focus();
        });
    }, [])
    return <>
        <div id="overlay" style={{display: (busy ? 'flex' : 'none')}} data-nosnippet>
            <div id="overlayInside">
                Wait...<br/>
                Installation process is going. Don't close the window, otherwise you may lose money spent for installation.
            </div>
        </div>
        <div id="content">
            {props.children}
        </div>
    </>;
}