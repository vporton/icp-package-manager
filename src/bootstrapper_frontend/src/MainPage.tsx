import { useContext, useEffect, useState } from "react";
import { useAuth } from "../../lib/use-auth-client";
import { getIsLocal } from "../../lib/state";
import { createActor as createBookmarkActor } from "../../declarations/bookmark";
import { createActor as createRepositoryIndexActor } from "../../declarations/repository";
import { Bookmark } from '../../declarations/bookmark/bookmark.did';
import { Principal } from "@dfinity/principal";
import { Agent } from "@dfinity/agent";
import Button from "react-bootstrap/Button";
import Accordion from "react-bootstrap/Accordion";
import { Alert } from "react-bootstrap";
import useConfirm from "./useConfirm";
import { bootstrapFrontend } from "../../lib/install";
import { BusyContext } from "../../lib/busy";
import { Link, useSearchParams } from "react-router-dom";
import { ErrorContext } from "../../lib/ErrorContext";

function uint8ArrayToUrlSafeBase64(uint8Array: Uint8Array) {
  const binaryString = String.fromCharCode(...uint8Array);
  const base64String = btoa(binaryString);
  return base64String
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
}

export default function MainPage() {
  const {ok, principal, agent, defaultAgent} = useAuth();
  return <MainPage2 ok={ok} principal={principal} agent={agent} defaultAgent={defaultAgent}/>;
}

function MainPage2(props: {ok: boolean, principal: Principal | undefined, agent: Agent | undefined, defaultAgent: Agent | undefined}) {
    const { setBusy } = useContext(BusyContext)!;
    const { setError } = useContext(ErrorContext)!;
    const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
    const [showAdvanced, setShowAdvanced] = useState(false);
    useEffect(() => {
      if (!props.ok || props.agent === undefined) {
        setBookmarks([]);
        return;
      }
      const bookmark = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: props.agent});
      bookmark.getUserBookmarks().then(list => {
        setBookmarks(list);
      });
    }, [props.ok, props.agent]);
    // TODO@P3: Allow to change the bootstrap repo:
    const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORY!, {agent: props.agent}); // TODO@P3: `defaultAgent` here and in other places.
    async function bootstrap() {
      try {
        setBusy(true);

        // const bootstrapper = createBootstrapperIndirectActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
        const {installedModules, frontendTweakPrivKey, spentCycles} = await bootstrapFrontend({
          agent: props.agent!,
        });
        const installedModulesMap = new Map(installedModules);
        const url = getIsLocal()
          ? `http://${installedModulesMap.get("frontend")}.localhost:8080`
          : `https://${installedModulesMap.get("frontend")}.icp0.io`;
        // gives the right to set frontend owner and controller to backend:
        const frontendTweakPrivKeyEncoded = uint8ArrayToUrlSafeBase64(frontendTweakPrivKey);
        const packages2 = additionalPackages;
        if (addExample) {
          packages2.push({packageName: "example", version: "0.0.1", repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!)});
        }
        const packages3 = packages2.map(p => ({packageName: p.packageName, version: p.version, repo: p.repo.toText()}));
        open(
          `${url}?` +
            `frontendTweakPrivKey=${frontendTweakPrivKeyEncoded}&` +
            `additionalPackages=${JSON.stringify(packages3)}&` +
            `modules=${JSON.stringify(installedModules.map(([s, p]: [string, Principal]) => [s, p.toString()]))}&` +
            `spent=${spentCycles}`,
          '_self');
      }
      catch(e) {
        console.log(e);
        if (/Natural subtraction underflow/.test((e as object).toString())) {
          setError("Not enough cycles on the account. Please, add some cycles to your account and try again.");
        } else {
          setError((e as object).toString());
        }
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

    // TODO@P3: Move below variables to the top.
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
    const modulesJSON = (searchParams as any).get('modules');

    const b = bookmarks[0]; // TODO@P3: Allow to install not for the first package manager.

    // TODO@P3: Give user freedom to change whether bootstrap or install.
    return (
      <>
        {bookmarks.length !== 0 ?
        <>
          <h2>Installed Package Manager</h2>
          {!props.ok ? <i>Not logged in</i> :
            <ul>
              {bookmarks.map(inst => {
                const base = getIsLocal() ? `http://${inst.frontend}.localhost:8080?` : `https://${inst.frontend}.icp0.io?`;
                const url = base + `_pm_pkg0.backend=${inst.backend.toString()}`;
                return <li key={url}><a href={url}>{url}</a></li>;
              })}
            </ul>
          }
          {additionalPackages.map(p => {
            const frontend = getIsLocal() ? `http://${b.frontend}.localhost:8080` : `https://${b.frontend}.icp0.io`;
            return (
              <p>
                <Link to={`${frontend}/choose-version/${p.repo}/${p.packageName}?_pm_pkg0.backend=${b.backend}`}>
                  Install package <code>{p.packageName}</code>
                </Link>
              </p>
            );
          })}
          <Accordion defaultActiveKey={undefined}>
            <Accordion.Item eventKey="advanced">
              <Accordion.Header onClick={() => setShowAdvanced(!showAdvanced)}>{showAdvanced ? "Hide advanced items" : "Show advanced items"}</Accordion.Header>
              <Accordion.Body>
                <Alert variant="warning">
                  You are not recommended to install package manager more than once.{" "}
                  <span style={{color: 'red'}}>Don't click the below button</span> unless you are sure that you need several bookmarks of the package manager.
                  Also note that multiple package managers will be totally separate, each having its own set of installed packages.
                </Alert>
                <p><Button disabled={!props.ok} onClick={bootstrapAgain}>Install package manager IC Pack AGAIN</Button></p>
              </Accordion.Body>
            </Accordion.Item>
          </Accordion>
          <BootstrapAgainDialog/>
        </>
        :
        <>
          <p>Additional packages to be installed: {additionalPackages.map(p => <><code>{p.packageName}</code>{" "}</>)}</p>
          {/* <p> // Restore it.
            <label>
              <input type="checkbox" checked={addExample} onChange={e => setAddExample(e.target.checked)}/>{" "}
              Add example package
            </label>{" "}
            <small>(for testing)</small>
          </p> */}
          <p><Button disabled={!props.ok} onClick={bootstrap}>Install package manager IC Pack</Button></p>
        </>}
      </>
    );
  }
  