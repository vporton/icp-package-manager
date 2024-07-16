import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from '@internet-identity-labs/react-ic-ii-auth';
import DisplayPrincipal from './DisplayPrincipal';
import { AuthContext } from './auth/use-auth-client';

export const AuthButton = () => {
  // const { authenticate,  signout, isAuthenticated, identity } = useInternetIdentity()
  // console.log('>> authenticate', { signin })
  // console.log('>> initialize your actors with', { identity })
  return (
    <AuthContext.Consumer>
    {({isAuthenticated, principal, authClient, defaultAgent, options, login, logout}) =>
      <span>
        <Button onClick={() => isAuthenticated ? logout!() : login!()}>
          {isAuthenticated ? 'Logout' : 'Login'}
        </Button>
        {" "}
        <DisplayPrincipal value={principal}/>
      </span>
    }
    </AuthContext.Consumer>
  );
}
