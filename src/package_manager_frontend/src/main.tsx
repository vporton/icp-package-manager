import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.scss';

// readable-stream expects `process.version` to exist, but browser polyfills may
// omit it. Avoid runtime errors by providing a default value if missing.
if (typeof process !== 'undefined' && typeof (process as any).version !== 'string') {
  (process as any).version = '';
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
