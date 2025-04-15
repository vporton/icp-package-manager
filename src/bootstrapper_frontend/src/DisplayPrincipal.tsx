import { Principal } from "@dfinity/principal";

export default function DisplayPrincipal(props: {value: Principal | undefined}) {
    if (props.value === undefined || props.value.isAnonymous()) {
        return "";
    }
    const s = props.value.toString();
    const start = s.substring(0, 6);
    const end = s.substring(s.length - 4);
    return (
        <code>{start}&hellip;{end}</code>
    );
    // TODO@P3: copy to clipboard button
}