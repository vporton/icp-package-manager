import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from 'ic-use-internet-identity';
import DisplayPrincipal from './DisplayPrincipal';
import { AuthContext } from './auth/use-auth-client';

export const AuthButton = () => {
  // const { authenticate,  signout, isLoginSuccess, identity } = useInternetIdentity()
  // console.log('>> authenticate', { signin })
  // console.log('>> initialize your actors with', { identity })
  return (
    <AuthContext.Consumer>
    {({isLoginSuccess, principal, authClient, defaultAgent, options, login, logout}) =>
      <span>
        <Button onClick={() => isLoginSuccess ? logout!() : login!()}>
          {isLoginSuccess ? 'Logout' : 'Login'}
        </Button>
        {" "}
        <DisplayPrincipal value={principal}/>
      </span>
    }
    </AuthContext.Consumer>
  );
}
