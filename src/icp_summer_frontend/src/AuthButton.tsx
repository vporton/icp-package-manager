import Button from 'react-bootstrap/Button';

import { useInternetIdentity } from '@identity-labs/react-ic-ii-auth';

export const AuthButton = () => {
  const { authenticate, signout, isAuthenticated, identity } = useInternetIdentity()
  console.log('>> initialize your actors with', { identity })
  return (
    <Button onClick={isAuthenticated ? signout : authenticate}>
      {isAuthenticated ? 'Logout' : 'Login'}
    </Button>
  )
}
