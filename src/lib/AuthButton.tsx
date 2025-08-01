import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from './DisplayPrincipal';
import { useAuth } from './use-auth-client';
import { useEffect } from 'react';

export const AuthButton = (props: {login?: () => void, logout?: () => void}) => {
  const { principal, login, clear, identity, ok } = useAuth();
  const click = async () => {
    if (identity) {
      await clear!();
      props.logout !== undefined && props.logout();
    } else {
      await login!()
      props.login !== undefined && props.login();
    }
  };
  return (
    <>
      <Button onClick={click}>
        {identity ? 'Logout' : 'Login'}
      </Button>
      {" "}
      <DisplayPrincipal value={identity ? principal : undefined}/>
    </>
  );
}
