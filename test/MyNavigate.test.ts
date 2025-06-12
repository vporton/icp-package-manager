import { expect } from 'chai';
import { amendPath } from '../src/package_manager_frontend/src/MyNavigate';

describe('amendPath', () => {
  const originalWindow = global.window;

  afterEach(() => {
    global.window = originalWindow;
  });

  it('handles only canisterId', () => {
    global.window = { location: { search: '?canisterId=abc' } } as any;
    expect(amendPath('/foo')).to.equal('/foo?canisterId=abc');
  });

  it('handles only backend', () => {
    global.window = { location: { search: '?_pm_pkg0.backend=def' } } as any;
    expect(amendPath('/foo')).to.equal('/foo?_pm_pkg0.backend=def');
  });

  it('handles both params', () => {
    global.window = { location: { search: '?canisterId=abc&_pm_pkg0.backend=def' } } as any;
    expect(amendPath('/foo')).to.equal('/foo?canisterId=abc&_pm_pkg0.backend=def');
  });
});
