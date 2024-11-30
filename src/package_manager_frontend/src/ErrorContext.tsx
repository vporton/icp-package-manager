import React, { createContext, useState } from "react";

interface ErrorContextType {
  hasError: boolean;
  message?: string;
  setError: (message: string) => void;
  resetError: () => void;
}

const ErrorContext = createContext<ErrorContextType | undefined>(undefined);

const ErrorProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [hasError, setHasError] = useState(false);
  const [message, setMessage] = useState<string | undefined>(undefined);

  const setError = (message: string) => {
    console.log("ERROR: " + message);
    setHasError(true);
    setMessage(message);
  };

  const resetError = () => {
    setHasError(false);
    setMessage(undefined);
  };

  return (
    <ErrorContext.Provider value={{ hasError, message, setError, resetError }}>
      {children}
    </ErrorContext.Provider>
  );
};

export { ErrorContext, ErrorProvider };
