# -*- coding: utf-8 -*-
"""May chu GIA dung ba diem cuoi cua Nakama ma client dung.

DAY KHONG PHAI NAKAMA. No khong xac thuc token that, khong co CSDL, khong co
phan quyen. Muc dich duy nhat: kiem tra net/nakama_client.gd goi DUNG dang —
dung phuong thuc, dung duong dan, dung kieu than tin nhan, dung cach doc tra
loi — ma khong phai cai Docker.

Phep kiem tra that van la chay Nakama that:

    cd server && docker compose up -d
    godot --headless --path . --script tools/verify_net.gd -- --url=http://127.0.0.1:7350

Cung mot bo test, chi doi --url. Neu client chi chay duoc voi may gia ma
khong chay duoc voi Nakama that thi test se noi ra.

    python tools/fake_nakama.py --port 7399
"""
import re, json, base64, argparse, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

SERVER_KEY = 'defaultkey'

users = {}        # device id -> {'user_id', 'username'}
tokens = {}       # token     -> user_id
storage = {}      # (user_id, collection, key) -> {'value', 'version'}
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):

    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *args):
        pass                      # im lang, khoi lam ban output test

    # ------------------------------------------------------------- tien ich
    def _json(self, code, doc):
        raw = json.dumps(doc).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _err(self, code, msg):
        # Nakama tra loi kem truong `message`; client doc dung truong nay.
        self._json(code, {'error': msg, 'message': msg, 'code': 3})

    def _body(self):
        n = int(self.headers.get('Content-Length') or 0)
        if not n:
            return {}
        try:
            return json.loads(self.rfile.read(n).decode('utf-8'))
        except ValueError:
            return None

    def _bearer_user(self):
        auth = self.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return None
        return tokens.get(auth[7:])

    def _server_key_ok(self):
        auth = self.headers.get('Authorization', '')
        if not auth.startswith('Basic '):
            return False
        try:
            raw = base64.b64decode(auth[6:]).decode('utf-8')
        except Exception:
            return False
        return raw.split(':', 1)[0] == SERVER_KEY

    # -------------------------------------------------------------- dinh tuyen
    def do_POST(self):
        path = self.path.split('?', 1)[0]
        if path == '/v2/account/authenticate/device':
            return self._authenticate()
        if path == '/v2/storage':
            return self._read()
        self._err(404, 'khong co %s' % path)

    def do_PUT(self):
        if self.path.split('?', 1)[0] == '/v2/storage':
            return self._write()
        self._err(404, 'khong co %s' % self.path)

    # ------------------------------------------------------------ diem cuoi
    def _authenticate(self):
        if not self._server_key_ok():
            return self._err(401, 'khoa may chu sai')
        body = self._body()
        if body is None:
            return self._err(400, 'than tin nhan khong phai JSON')
        device = str(body.get('id', ''))
        if len(device) < 10:
            return self._err(400, 'ma thiet bi phai dai it nhat 10 ky tu')

        q = dict(re.findall(r'([^?&=]+)=([^&]*)', self.path))
        with lock:
            created = device not in users
            if created:
                users[device] = {
                    'user_id': 'u-%08x' % (abs(hash(device)) & 0xffffffff),
                    'username': q.get('username') or ('nguoi%d' % (len(users) + 1)),
                }
            u = users[device]
            tok = 'gia.%s.%d' % (u['user_id'], len(tokens))
            tokens[tok] = u['user_id']
        self._json(200, {'token': tok, 'refresh_token': tok + '.r',
                         'user_id': u['user_id'], 'username': u['username'],
                         'created': created})

    def _write(self):
        uid = self._bearer_user()
        if uid is None:
            return self._err(401, 'token khong hop le')
        body = self._body()
        if body is None:
            return self._err(400, 'than tin nhan khong phai JSON')
        acks = []
        with lock:
            for o in body.get('objects', []):
                if not isinstance(o.get('value'), str):
                    # Nakama doi `value` la CHUOI JSON. Bat loi nay o day de
                    # client khong am tham gui sai roi hong tren may that.
                    return self._err(400, 'truong value phai la chuoi JSON')
                k = (uid, o.get('collection', ''), o.get('key', ''))
                ver = storage.get(k, {}).get('version', 0) + 1
                storage[k] = {'value': o['value'], 'version': ver}
                acks.append({'collection': k[1], 'key': k[2],
                             'version': 'v%d' % ver, 'user_id': uid})
        self._json(200, {'acks': acks})

    def _read(self):
        uid = self._bearer_user()
        if uid is None:
            return self._err(401, 'token khong hop le')
        body = self._body()
        if body is None:
            return self._err(400, 'than tin nhan khong phai JSON')
        out = []
        with lock:
            for o in body.get('object_ids', []):
                k = (o.get('user_id') or uid, o.get('collection', ''), o.get('key', ''))
                if k in storage:
                    out.append({'collection': k[1], 'key': k[2], 'user_id': k[0],
                                'value': storage[k]['value'],
                                'version': 'v%d' % storage[k]['version']})
        self._json(200, {'objects': out})


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--port', type=int, default=7399)
    a = ap.parse_args()
    srv = HTTPServer(('127.0.0.1', a.port), Handler)
    print('may chu GIA (khong phai Nakama) tai http://127.0.0.1:%d' % a.port, flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
