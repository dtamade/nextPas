(() => {
  'use strict';
  if (window.__npw) return;
  const send = (() => {
    const wk = window.webkit && window.webkit.messageHandlers &&
              window.webkit.messageHandlers.npw;
    if (wk) return (t) => wk.postMessage(t);
    const wv = window.chrome && window.chrome.webview;
    if (wv) return (t) => wv.postMessage(t);
    return null;
  })();
  const post = (frame) => {
    if (!send) throw new Error('npw: no transport');
    send(JSON.stringify(frame));
  };
  const pending = new Map();
  let nextId = 1;
  const listeners = new Map();
  const invoke = (cmd, payload) => {
    if (typeof cmd !== 'string' || cmd.length === 0)
      return Promise.reject(new Error('npw: cmd required'));
    if (nextId > 9007199254740991)
      return Promise.reject(new Error('npw: id space exhausted'));
    const id = nextId++;
    post({ v: 1, id: id,
          cmd: cmd,
          payload: payload === undefined ? null : payload });
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve: resolve, reject: reject });
    });
  };
  const listen = (event, callback) => {
    let set = listeners.get(event);
    if (!set) { set = new Set(); listeners.set(event, set); }
    set.add(callback);
    return () => set.delete(callback);
  };
  const emitLocal = (event, payload) => {
    const set = listeners.get(event);
    if (!set) return;
    set.forEach((cb) => { cb(payload); });
  };
  const settle = (id, text, ok) => {
    const p = pending.get(id);
    if (!p) return;
    pending.delete(id);
    const value = JSON.parse(text);
    if (ok) p.resolve(value); else p.reject(value);
  };
  let fireReady;
  const ready = new Promise((fire) => { fireReady = fire; });
  window.__npw = {
    version: 1,
    ready: ready,
    invoke: invoke,
    listen: listen,
    emit: emitLocal,
    __resolve: (id, t) => settle(id, t, true),
    __reject: (id, t) => settle(id, t, false),
    __emit: (event, t) => emitLocal(event, JSON.parse(t))
  };
  Object.freeze(window.__npw);
  fireReady();
})();
