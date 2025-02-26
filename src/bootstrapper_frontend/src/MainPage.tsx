import { useContext, useEffect, useState } from "react";
import { AuthContext, getIsLocal } from "./auth/use-auth-client";
import { createActor as createBookmarkActor } from "../../declarations/bookmark";
import { createActor as createBootstrapperIndirectActor } from "../../declarations/bootstrapper";
import { createActor as createRepositoryIndexActor } from "../../declarations/repository";
import { Bookmark } from '../../declarations/bookmark/bookmark.did';
import { Principal } from "@dfinity/principal";
import { Actor, Agent } from "@dfinity/agent";
import Button from "react-bootstrap/Button";
import Accordion from "react-bootstrap/Accordion";
import { Alert, useAccordionButton } from "react-bootstrap";
import useConfirm from "./useConfirm";
import { SharedPackageInfo, SharedRealPackageInfo } from "../../declarations/repository/repository.did";
import { IDL } from "@dfinity/candid";
import { bootstrapFrontend } from "../../lib/install";
import { BusyContext } from "../../lib/busy";
import { Link, useSearchParams } from "react-router-dom";

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
    const { setBusy } = useContext(BusyContext)!;
    const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
    const [showAdvanced, setShowAdvanced] = useState(false);
    useEffect(() => {
      if (!props.isAuthenticated || props.agent === undefined) {
        setBookmarks([]);
        return;
      }
      // console.log("process.env.CANISTER_ID_BOOKMARK", process.env.CANISTER_ID_BOOKMARK);
      const bookmark = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: props.agent});
      bookmark.getUserBookmarks().then(list => {
        setBookmarks(list);
      });
    }, [props.isAuthenticated, props.principal]);
    // TODO: Allow to change the bootstrap repo:
    const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORY!, {agent: props.agent}); // TODO: `defaultAgent` here and in other places.
    async function bootstrap() { // TODO: Move to `useEffect`.
      try {
        setBusy(true);
        let pkg: SharedPackageInfo = await repoIndex.getPackage('icpack', "0.0.1"); // TODO: `"stable"`

        // const bootstrapper = createBootstrapperIndirectActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
        const {canister_id: frontendPrincipal, frontendTweakPrivKey} = await bootstrapFrontend({
          user: props.principal!,
          agent: props.agent!,
        });
        const url = getIsLocal()
          ? `http://${frontendPrincipal}.localhost:4943`
          : `https://${frontendPrincipal}.icp0.io`;
        // gives the right to set frontend owner and controller to backend:
        const frontendTweakPrivKeyEncoded = uint8ArrayToUrlSafeBase64(frontendTweakPrivKey);
        const packages2 = additionalPackages;
        if (addExample) {
          packages2.push({packageName: "example", version: "0.0.1", repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!)});
        }
        const packages3 = packages2.map(p => ({packageName: p.packageName, version: p.version, repo: p.repo.toText()}));
        open(`${url}?frontendTweakPrivKey=${frontendTweakPrivKeyEncoded}&additionalPackages=${JSON.stringify(packages3)}`, '_self');
      }
      catch(e) {
        console.log(e);
        throw e; // TODO
      }
      finally {
        setBusy(false);
      }
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

    // TODO: Move below variables to the top.
    const [searchParams, _] = useSearchParams();
    const [addExample, setAddExample] = useState(false);
    const additionalPackagesStr = (searchParams as any).get('additionalPackages');
    const additionalPackages: {
      packageName: string;
      version: string;
      repo: Principal;
    }[] = additionalPackagesStr === null ? []
      : JSON.parse(additionalPackagesStr).map((p: any) => ({packageName: p.packageName, version: p.version, repo: Principal.fromText(p.repo)}));
    // [{packageName: "example", version: "0.0.1", repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!)}];

    const b = bookmarks[0];

    return (
      <>
        {bookmarks.length === 0 ?
          <>
            <p><Button disabled={!props.isAuthenticated} onClick={bootstrap}>Install package manager IC Pack</Button></p>
            <p>Additional packages to be installed: {additionalPackages.map(p => <><code>{p.packageName}</code>{" "}</>)}</p>
            <p>
              <label>
                <input type="checkbox" checked={addExample} onChange={e => setAddExample(e.target.checked)}/>{" "}
                Add example package
              </label>{" "}
              <small>(for testing)</small>
            </p>
          </> :
          <>
            {additionalPackages.length !== 0 &&
              additionalPackages.map(p =>
                <p>
                  <Link to={`https://${b.frontend}/choose-version/${p.repo}/${p.packageName}?_pm_pkg0.backend=${b.backend}`}>
                    Install package {p.packageName}
                  </Link>
                </p>
              )}
          </>}
        {bookmarks.length === 0 &&
        <>
          <h2>Installed Package Manager</h2>
          {!props.isAuthenticated ? <i>Not logged in</i> : bookmarks.length === 0 ? <i>None</i> :
            <ul>
              {bookmarks.map(inst => {
                const base = getIsLocal() ? `http://${inst.frontend}.localhost:4943?` : `https://${inst.frontend}.icp0.io?`;
                const url = base + `_pm_pkg0.backend=${inst.backend.toString()}`;
                return <li key={url}><a href={url}>{url}</a></li>;
              })}
            </ul>
          }
          {bookmarks.length !== 0 &&
            <Accordion defaultActiveKey={undefined}>
              <Accordion.Item eventKey="advanced">
                <Accordion.Header onClick={() => setShowAdvanced(!showAdvanced)}>{showAdvanced ? "Hide advanced items" : "Show advanced items"}</Accordion.Header>
                <Accordion.Body>
                  <Alert variant="warning">
                    You are not recommended to install package manager more than once.{" "}
                    <span style={{color: 'red'}}>Don't click the below button</span> unless you are sure that you need several bookmarks of the package manager.
                    Also note that multiple package managers will be totally separate, each having its own set of installed packages.
                  </Alert>
                  <p><Button disabled={!props.isAuthenticated} onClick={bootstrapAgain}>Install package manager IC Pack AGAIN</Button></p>
                </Accordion.Body>
              </Accordion.Item>
            </Accordion>
          }
          <BootstrapAgainDialog/>
        </>}
      </>
    );
  }
  