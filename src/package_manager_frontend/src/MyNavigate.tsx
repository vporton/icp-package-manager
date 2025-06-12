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

export function amendPath(path: string): string {
    const params = new URLSearchParams(window.location.search);
    const canisterId = params.get('canisterId');
    const backend = params.get('_pm_pkg0.backend');

    const pieces: string[] = [];
    if (canisterId !== null) {
        pieces.push(`canisterId=${canisterId}`);
    }
    if (backend !== null) {
        pieces.push(`_pm_pkg0.backend=${backend}`);
    }
    if (pieces.length > 0) {
        return path + '?' + pieces.join('&');
    }
    return path;
}