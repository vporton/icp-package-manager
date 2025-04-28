import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from '../bootstrapper_frontend/src/DisplayPrincipal';
import { useAuth } from '../bootstrapper_frontend/src/auth/use-auth-client';

export const AuthButton = () => {
  const { isLoginSuccess, principal, login, clear, loginStatus } = useAuth();
  // We can't use `isLoginSuccess` because of https://github.com/kristoferlund/ic-use-internet-identity-demo/issues/6
  return (
    <>
      <Button onClick={() => loginStatus === 'idle' ? login!() : clear!()}>
        {loginStatus === 'idle' ? 'Login' : 'Logout'}
      </Button>[{loginStatus  === 'idle' ? 'not logged in' : 'logged in'}]
      {" "}
      <DisplayPrincipal value={isLoginSuccess ? principal : undefined}/>
    </>
  );
}
