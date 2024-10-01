import Modal from 'react-bootstrap/Modal';
import Button from 'react-bootstrap/Button';
import { useState } from 'react';

const useConfirm = (title: string, message: string): [() => JSX.Element, () => Promise<boolean>] => {
    const [promise, setPromise] = useState<{resolve: ((value: boolean) => void) | undefined}>();
  
    const confirm = () => new Promise<boolean>((resolve, _reject) => {
      setPromise({ resolve: resolve! });
    });
  
    const handleClose = () => {
      setPromise(undefined);
    };
  
    const handleConfirm = () => {
      promise?.resolve!(true);
      handleClose();
    };
  
    const handleCancel = () => {
      promise?.resolve!(false);
      handleClose();
    };

    const ConfirmationDialog = () => (
      <Modal show={promise?.resolve !== undefined}>
        <Modal.Header closeButton>{title}</Modal.Header>
        <Modal.Body>{message}</Modal.Body>
        <Modal.Footer>
          <Button onClick={handleConfirm} className="btn btn-primary">Yes</Button>
          <Button onClick={handleCancel} className="btn btn-secondary">Cancel</Button>
        </Modal.Footer>
      </Modal>
    );
    return [ConfirmationDialog, confirm];
  };
  
  export default useConfirm;
  