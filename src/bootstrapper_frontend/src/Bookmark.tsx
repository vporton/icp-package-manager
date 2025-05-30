// import { Principal } from "@dfinity/principal";
// import { getIsLocal } from "../lib/use-auth-client";
// import Button from "react-bootstrap/Button";
// import { useContext, useEffect, useState } from "react";
// import { createActor as createBookmarkActor } from "../../declarations/bookmark";
// import { createActor as createPMActor } from "../../declarations/package_manager";

// export default function Bookmark() {
//     const {ok, principal, agent, defaultAgent} = useContext(AuthContext);
//     const params = new URLSearchParams(window.location.search) as any;
//     const paramValues = {frontend: params.get('_pm_pkg0.frontend'), backend: params.get('_pm_pkg0.backend')};
//     const frontend = Principal.fromText(paramValues.frontend);
//     const backend = Principal.fromText(paramValues.backend);
//     const bookmark = {frontend, backend};
//     const base = getIsLocal() ? `http://${frontend.toString()}.localhost:8080?` : `https://${frontend.toString()}.icp0.io?`;
//     const url = base + `_pm_pkg0.backend=${backend.toString()}`;
//     async function createBookmark() {
//         // const pm = createPMActor(process.env.CANISTER_ID_BOOKMARK!, {agent});
//         // await pm.addBookmark(bookmark);
//         // setDone(true);
//     }
//     const [done, setDone] = useState(true);
//     useEffect(() => {
//         const bookmarks = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: defaultAgent});
//         bookmarks.hasBookmark(bookmark).then(f => setDone(f));
//     }, [])
//     return (
//         <>
//             <p>Bookmark your package manager location:<br/><a href={url}>{url}</a></p>
//             {done ? <p><em>Bookmark already created</em></p> :
//                 <p><Button onClick={createBookmark} disabled={!ok}>Bookmark it</Button>
//                     {" "}Bookmarking is a paid service amounting to 10bn cycles (at the time of writing, 1.34 cents).
//                 </p>}
//         </>
//     );
// }