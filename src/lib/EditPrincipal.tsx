import { Principal } from "@dfinity/principal";
import React, { useState } from "react";

// TODO@P3: Use it in wallet.
export default function EditPrincipal(props: {
    value?: Principal,
    defaultValue?: Principal,
    onInput?: ((value: Principal | undefined) => void),
    onSetError?: ((value: boolean) => void),
}) {

    const [error, setError] = useState(false);

    function handleInput(e: React.FormEvent<HTMLInputElement>) {
        const valueStr = (e.target as HTMLInputElement).value;
        if (valueStr === "") {
            props.onSetError?.(false);
            props.onInput?.(undefined);
            setError(false);
        } else {
            try {
                const value = Principal.fromText(valueStr);
                props.onSetError?.(false);
                props.onInput?.(value);
                setError(false);
            } catch (error) {
                props.onSetError?.(true);
                props.onInput?.(undefined);
                setError(true);
            }
        }
    }

    return <input className={error ? "error" : ""} type="text" defaultValue={props.defaultValue?.toString()} onInput={handleInput} />;
} 