import React, { Component, ErrorInfo, ReactNode, useContext } from "react";
import { ErrorContext } from "./ErrorContext";
import { Link, useNavigate } from "react-router-dom";
import Modal from "react-bootstrap/Modal";
import Button from "react-bootstrap/Button";

interface ErrorBoundaryProps {
  children: ReactNode;
}

class ErrorBoundary extends Component<ErrorBoundaryProps> {
  static contextType = ErrorContext;
  declare context: React.ContextType<typeof ErrorContext>;

  public static getDerivedStateFromError(error: Error): null {
    return null;
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("Uncaught error:", error, errorInfo);
    if (this.context) {
      this.context.setError(error.message);
    }
  }

  public render() {
    return <>
      <ErrorHandler error={this.context?.message?.toString()}/>
      {this.props.children}
    </>;
  }
}

interface ErrorHandlerProps {
  error: string | undefined;
}

function ErrorHandler({ error }: ErrorHandlerProps) {
  const { resetError } = useContext(ErrorContext)!;
  return (
    <Modal show={error !== undefined} className="wideDialog">
      <Modal.Header closeButton>
        <Modal.Title>
        Error
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p style={{ color: 'red' }}>{error}</p>
      </Modal.Body>
      <Modal.Footer>
        <Button variant="primary" onClick={resetError}>
        Close
        </Button>
      </Modal.Footer>
    </Modal>
  );
}

export { ErrorBoundary, ErrorHandler };
