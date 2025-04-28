import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from './DisplayPrincipal';
import { AuthContext } from '../lib/use-auth-client';

export const AuthButton = () => {
  // const { authenticate,  signout, ok, identity } = useAuth()
  // console.log('>> authenticate', { signin })
  // console.log('>> initialize your actors with', { identity })
  return (
    <AuthContext.Consumer>
    {({ok, principal, authClient, defaultAgent, options, login, logout}) =>
      <span>
        <Button onClick={() => ok ? logout!() : login!()}>
          {ok ? 'Logout' : 'Login'}
        </Button>
        {" "}
        <DisplayPrincipal value={principal}/>
      </span>
    }
    </AuthContext.Consumer>
  );
}
