"""Luat CHI-THEM cua `import_lua.py` phai THAT SU tu choi ghi de.

    python tools/test_import_lua.py

Vi sao phai co bo kiem nay chu khong tin vao doc code: `sc/` sinh lai tu cay VN
moi lan chay `import_lua.py`, nen mot lan de len la doi **nen du lieu VN** ngay
bay gio, roi bi lan import sau xoa di — tuc cai sai O LAI con dau vet thi MAT.
Dung loai hong im lang ma `CLAUDE.md` da ghi.

Do lai tren cay GIA trong thu muc tam, khong cham vao `sc/` that.
"""
import hashlib
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_lua  # noqa: E402

NGUON = (ROOT.parent / 'bravecross-source' / 'cn131' / 'decrypted' / 'assets'
         / 'sc')

dat = 0
hong = 0


def kiem(ten, ok, ghi=''):
    global dat, hong
    if ok:
        dat += 1
    else:
        hong += 1
    print('  %-56s %s %s' % (ten, 'dat' if ok else 'HONG', ghi))


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16]


def main() -> int:
    if not NGUON.is_dir():
        print('BO QUA: khong co cay CN 1.31 o %s' % NGUON)
        return 0

    mong = (sum(1 for t in import_lua.THU_MUC_131
                for p in (NGUON / t).rglob('*') if p.is_file())
            + sum(1 for t in import_lua.TEP_131_LE
                  if (NGUON / t).is_file()))
    if not mong:
        print('BO QUA: cay CN 1.31 khong co tep nao thuoc pham vi luat')
        return 0

    tmp = Path(tempfile.mkdtemp(prefix='luat131-'))
    try:
        # 1. Cay trong: phai them dung bang so mong, khong dung cho nao.
        them, trung, dung = import_lua.be_lop_mang_131(tmp)
        kiem('cay trong -> them %d tep' % mong, them == mong, '(them %d)' % them)
        kiem('cay trong -> 0 dung', not dung, str(dung))
        co = sum(1 for p in tmp.rglob('*') if p.is_file())
        kiem('tren dia dung %d tep' % mong, co == mong, '(co %d)' % co)

        # 2. Chay lai: phai la Y NGUYEN het, khong them khong dung.
        them2, trung2, dung2 = import_lua.be_lop_mang_131(tmp)
        kiem('chay lai -> them 0', them2 == 0, '(them %d)' % them2)
        kiem('chay lai -> y nguyen %d' % mong, trung2 == mong,
             '(y nguyen %d)' % trung2)
        kiem('chay lai -> 0 dung', not dung2, str(dung2))

        # 3. Dat mot tep TRUNG TEN ma KHAC noi dung, doi luat phai DUNG va BAO.
        #    Chon dung tep co vet dich nguoc (`protoc.lua`) vi do la tep de bi
        #    sua nham nhat — neu luat co ghi de thi day la cho no se ghi.
        nan = tmp / 'Framework' / 'Network' / 'pb' / 'protoc.lua'
        nan.write_bytes(nan.read_bytes() + b'\n-- rac cua nguoi\n')
        sau_khi_dat = sha(nan)
        them3, trung3, dung3 = import_lua.be_lop_mang_131(tmp)
        kiem('co dich khac noi dung -> DUNG', len(dung3) == 1, str(dung3))
        kiem('ten dung la tep bi dat',
             bool(dung3) and dung3[0] == 'Framework/Network/pb/protoc.lua',
             str(dung3))
        kiem('KHONG ghi de: noi dung tep giu nguyen', sha(nan) == sau_khi_dat)
        kiem('khong dung cho nao khac', them3 == 0 and trung3 == mong - 1,
             'them %d, y nguyen %d' % (them3, trung3))

        # 4. Tra tep ve y nguyen thi luat thoi dung — chung minh phep dung la vi
        #    NOI DUNG chu khong phai vi ten.
        nan.write_bytes((NGUON / 'Framework' / 'Network' / 'pb'
                         / 'protoc.lua').read_bytes())
        them4, trung4, dung4 = import_lua.be_lop_mang_131(tmp)
        kiem('tra ve y nguyen -> thoi dung', not dung4 and trung4 == mong,
             'them %d, y nguyen %d, dung %d' % (them4, trung4, len(dung4)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    print('dat %d, hong %d' % (dat, hong))
    return 1 if hong else 0


if __name__ == '__main__':
    sys.exit(main())
