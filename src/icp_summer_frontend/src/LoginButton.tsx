import { useInternetIdentity } from "ic-use-internet-identity";
import { Button } from 'react-bootstrap';

export default function LoginButton() {
  const { login, loginStatus, identity } = useInternetIdentity({});

  const disabled = loginStatus === "logging-in" || loginStatus === "success";
  const text = loginStatus === "logging-in" ? "Logging in..." : "Login";

  return <>
    <Button onClick={login} disabled={disabled}>
      {text}
    </Button>
    {identity?.getPrincipal()}
  </>;
}
