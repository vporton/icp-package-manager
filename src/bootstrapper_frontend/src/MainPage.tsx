import { useEffect, useState } from "react";
import { AuthContext, getIsLocal } from "./auth/use-auth-client";
import { createActor as createBookmarkActor } from "../../declarations/bookmark";
import { Bookmark } from '../../declarations/bookmark/bookmark.did';
import { Principal } from "@dfinity/principal";
import { Actor, Agent } from "@dfinity/agent";
import Button from "react-bootstrap/Button";
import Accordion from "react-bootstrap/Accordion";
import { Alert, useAccordionButton } from "react-bootstrap";
import useConfirm from "./useConfirm";
import { bootstrapFrontend } from "../../lib/install";

function uint8ArrayToUrlSafeBase64(uint8Array: Uint8Array) {
  const binaryString = String.fromCharCode(...uint8Array);
  const base64String = btoa(binaryString);
  return base64String
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
}

export default function MainPage() {
    return (
      <AuthContext.Consumer>{
        ({isAuthenticated, principal, agent, defaultAgent}) =>
          <MainPage2 isAuthenticated={isAuthenticated} principal={principal} agent={agent} defaultAgent={defaultAgent}/>
        }
      </AuthContext.Consumer>
    );
  }
  
  function MainPage2(props: {isAuthenticated: boolean, principal: Principal | undefined, agent: Agent | undefined, defaultAgent: Agent | undefined}) {
    const [installations, setInstallations] = useState<Bookmark[]>([]);
    const [showAdvanced, setShowAdvanced] = useState(false);
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
    // TODO: Allow to change the bootstrap repo:
    async function bootstrap() {
      const {canister_id: frontendPrincipal, frontendTweakPrivKey} = await bootstrapFrontend({user: props.principal!, agent: props.agent!});
      // gives the right to set frontend owner and controller to backend:
      const frontendTweakPrivKeyEncoded = uint8ArrayToUrlSafeBase64(frontendTweakPrivKey);
      const url = getIsLocal()
        ? `http://${frontendPrincipal}.localhost:4943`
        : `https://${frontendPrincipal}.icp0.io`;
      open(url + "?frontendTweakPrivKey=" + frontendTweakPrivKeyEncoded, '_self');
    }
    const [BootstrapAgainDialog, confirmBootstrapAgain] = useConfirm(
      "Are you sure to bootstrap it AGAIN?",
      "Bootstrapping package manager more than once is not recommended.",
    );
    async function bootstrapAgain() {
      if (await confirmBootstrapAgain()) {
        await bootstrap();
      }
    }

    return (
      <>
        {installations.length === 0 &&
          <p><Button disabled={!props.isAuthenticated} onClick={bootstrap}>Install package manager IC Pack</Button></p>}
        <h2>Installed Package Manager</h2>
        {!props.isAuthenticated ? <i>Not logged in</i> : installations.length === 0 ? <i>None</i> :
          <ul>
            {installations.map(inst => {
              const base = getIsLocal() ? `http://${inst.frontend}.localhost:4943?` : `https://${inst.frontend}.icp0.io?`;
              const url = base + `_pm_pkg0.backend=${inst.backend.toString()}`;
              return <li key={url}><a href={url}>{url}</a></li>;
            })}
          </ul>
        }
        {installations.length !== 0 &&
          <Accordion defaultActiveKey={undefined}>
            <Accordion.Item eventKey="advanced">
              <Accordion.Header onClick={() => setShowAdvanced(!showAdvanced)}>{showAdvanced ? "Hide advanced items" : "Show advanced items"}</Accordion.Header>
              <Accordion.Body>
                <Alert variant="warning">
                  You are not recommended to install package manager more than once.{" "}
                  <span style={{color: 'red'}}>Don't click the below button</span> unless you are sure that you need several installations of the package manager.
                  Also note that multiple package managers will be totally separate, each having its own set of installed packages.
                </Alert>
                <p><Button disabled={!props.isAuthenticated} onClick={bootstrapAgain}>Install package manager IC Pack AGAIN</Button></p>
              </Accordion.Body>
            </Accordion.Item>
          </Accordion>
        }
        <BootstrapAgainDialog/>
      </>
    );
  }
  