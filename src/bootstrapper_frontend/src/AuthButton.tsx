import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from './DisplayPrincipal';
import { useAuth } from './auth/use-auth-client';

export const AuthButton = () => {
  const { isLoginSuccess, principal, login, clear } = useAuth();
  return (
    <>
      <Button onClick={() => isLoginSuccess ? clear!() : login!()}>
        {isLoginSuccess ? 'Logout' : 'Login'}
      </Button>
      {" "}
      <DisplayPrincipal value={principal}/>
    </>
  );
}
