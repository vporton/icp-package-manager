import { useEffect, useState } from "react";
import { AuthContext, getIsLocal } from "./auth/use-auth-client";
import { createActor as createBootstrapperActor } from "../../declarations/bootstrapper";
import {  createActor as createBookmarkActor } from "../../declarations/bookmark";
import { Bookmark } from '../../declarations/bookmark/bookmark.did';
import { Principal } from "@dfinity/principal";
import { Agent } from "@dfinity/agent";
import Button from "react-bootstrap/Button";

export default function MainPage() {
    return (
      <AuthContext.Consumer>{
        ({isAuthenticated, principal, agent}) =>
          <MainPage2 isAuthenticated={isAuthenticated} principal={principal} agent={agent}/>
        }
      </AuthContext.Consumer>
    );
  }
  
  function MainPage2(props: {isAuthenticated: boolean, principal: Principal | undefined, agent: Agent | undefined}) {
    const [installations, setInstallations] = useState<Bookmark[]>([]);
    useEffect(() => {
      if (!props.isAuthenticated || props.agent === undefined) {
        setInstallations([]);
        return;
      }
      const bootstrapper = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: props.agent});
      bootstrapper.getUserBookmarks().then(list => {
        setInstallations(list);
      });
    }, [props.isAuthenticated, props.principal]);
    async function bootstrap() {
      const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
      const frontendPrincipal = await bootstrapper.bootstrapFrontend();
      // TODO: Wait till frontend is bootstrapped and go to it.
      const url = getIsLocal()
        ? `http://${frontendPrincipal}.localhost:4943`
        : `https://${frontendPrincipal}.ic0.app`;
      alert("You may need press reload (press F5) the page one or more times before it works."); // TODO
      open(url);
    }
    return (
      <>
        <p><Button disabled={!props.isAuthenticated} onClick={bootstrap}>Install Package Manager IC Pack</Button></p>
        <h2>Installed Package Manager</h2>
        {!props.isAuthenticated ? <i>Not logged in</i> : installations.length === 0 ? <i>None</i> :
          <ul>
            {installations.map(inst => {
              let url = `https://${inst.frontend}.ic0.app?backend=${inst.backend}`;
              return <li><a href={url}>{url}</a></li>;
            })}
          </ul>
        }
      </>
    );
  }
  