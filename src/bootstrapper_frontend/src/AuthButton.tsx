import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from './DisplayPrincipal';
import { AuthContext } from './auth/use-auth-client';

export const AuthButton = () => {
  const { isLoginSuccess, identity, login, clear } = useInternetIdentity();
  return (
    <>
      <Button onClick={() => isLoginSuccess ? clear() : login()}>
        {isLoginSuccess ? 'Logout' : 'Login'}
      </Button>
      {" "}
      <DisplayPrincipal value={identity?.getPrincipal()}/>
    </>
  );
}
