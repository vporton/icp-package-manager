import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from '../bootstrapper_frontend/src/DisplayPrincipal';
import { useAuth } from './use-auth-client';

export const AuthButton = () => {
  const { principal, login, clear, identity } = useAuth();
  return (
    <>
      <Button onClick={identity ? clear! : login!}>
        {identity ? 'Logout' : 'Login'}
      </Button>
      {" "}
      <DisplayPrincipal value={identity ? principal : undefined}/>
    </>
  );
}
