import Button from 'react-bootstrap/Button';
import DisplayPrincipal from './DisplayPrincipal';
import { useAuth } from './auth/use-auth-client';

export const AuthButton = () => {
  const { clear, login, isLoginSuccess, principal } = useAuth();
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
