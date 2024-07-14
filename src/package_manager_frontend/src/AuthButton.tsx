import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from '@identity-labs/react-ic-ii-auth';
import DisplayPrincipal from './DisplayPrincipal';

export const AuthButton = () => {
  const { authenticate, signout, isAuthenticated, identity } = useInternetIdentity()
  console.log('>> initialize your actors with', { identity })
  return (
    <span>
      <Button onClick={isAuthenticated ? signout : authenticate}>
        {isAuthenticated ? 'Logout' : 'Login'}
      </Button>
      {" "}
      <DisplayPrincipal value={identity?.getPrincipal() ?? undefined}/>
    </span>
  );
}
