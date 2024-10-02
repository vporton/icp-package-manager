import { Link, useNavigate } from "react-router-dom"

export function myUseNavigate() {
    const base = useNavigate();
    return (path: string) => {
        base(amendPath(path));
    }
}

export function MyLink(props: {to: string, className?: string, children: React.ReactNode}) {
    return <Link to={amendPath(props.to)} className={props.className} children={props.children}/>
}

function amendPath(path: string): string {
    const params = new URLSearchParams(window.location.search);
    const canisterId = params.get('canisterId');
    const backend = params.get('backend');

    let s = path;
    if (canisterId !== null || backend !== null) {
        s += "?";
    }
    if (canisterId !== null) {
        s += "canisterId=" + canisterId;
    }
    if (backend !== null) {
        s += "backend=" + backend;
    }
    return s;
}