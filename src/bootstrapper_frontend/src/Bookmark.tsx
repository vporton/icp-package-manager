import { Principal } from "@dfinity/principal";
import { AuthContext, getIsLocal } from "./auth/use-auth-client";
import Button from "react-bootstrap/Button";
import { useContext, useEffect, useState } from "react";
import { createActor as createBookmarkActor } from "../../declarations/bookmark";

export default function Bookmark() {
    const {isAuthenticated, principal, agent, defaultAgent} = useContext(AuthContext);
    const params = new URLSearchParams(window.location.search) as any;
    const paramValues = {frontend: params.get('_pm_pkg0.frontend'), backend: params.get('_pm_pkg0.backend')};
    const frontend = Principal.fromText(paramValues.frontend);
    const backend = Principal.fromText(paramValues.backend);
    const bookmark = {frontend, backend};
    const base = getIsLocal() ? `http://${frontend.toString()}.localhost:4943?` : `https://${frontend.toString()}.icp0.io?`;
    const url = base + `_pm_pkg0.backend=${backend.toString()}`;
    async function createBookmark() {
        const bookmarks = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent});
        await bookmarks.addBookmark(bookmark);
        setDone(true);
    }
    const [done, setDone] = useState(true);
    useEffect(() => {
        const bookmarks = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: defaultAgent});
        bookmarks.hasBookmark(bookmark).then(f => setDone(f));
    }, [])
    return (
        <>
            <p>Bookmark your package manager location:<br/><code>{url}</code></p>
            {done ? <p><em>Bookmark already created</em></p> :
                <p><Button onClick={createBookmark} disabled={!isAuthenticated}>Bookmark it</Button></p>}
        </>
    );
}