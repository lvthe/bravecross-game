# -*- coding: utf-8 -*-
"""Chay het bo kiem tra roi bao mot bang tom tat.

    python tools/check.py
    python tools/check.py --url http://127.0.0.1:7399    # may chu gia

Bo nao can may chu ma khong noi duoc thi bao BO QUA chu khong bao hong — de
con phan biet "chua bat Nakama" voi "code hong".

Viet bang Python chu khong phai PowerShell vi may nay chan chay file .ps1
(ExecutionPolicy), va do la thiet lap bao mat khong nen doi chi de chay test.
"""
import os, re, sys, shutil, argparse, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# (ten, kieu, file, can_may_chu, tham so them)
SUITES = [
    ('rig nhan vat',         'script', 'tools/verify.gd',         False, []),
    ('mo hinh chien dau',    'script', 'tools/verify_battle.gd',  False, []),
    ('bo cuc man hinh',     'script', 'tools/verify_layout.gd',  False, []),
    # Chinh sach co gian cua so: cai dat du an phai la `expand` (khong phai mac
    # dinh `keep` cua Godot), cong thuc hai nhanh cua ban goc
    # (`CSceneManager:SetWHScaleToWinSize`) van con trong `sc/`, va hai duong
    # tinh ra CUNG ket qua tren dai ti le 1,0 -> 2,5. Bo do bang cua so that
    # (`tools/do_co_gian.gd`) nam ngoai check.py vi `--headless` khong doi duoc
    # do phan giai; bo nay giu phan kiem duoc ma khong can cua so.
    ('co gian cua so',      'script', 'tools/verify_co_gian.gd', False, []),
    ('ma Lua ban goc',      'script', 'tools/verify_lua_ui.gd',  False, []),
    ('man hinh Lua ban goc','script', 'tools/verify_lua_screen.gd', False, []),
    ('action + anh (Lua)',  'script', 'tools/verify_lua_actions.gd', False, []),
    ('cham (Lua)',          'script', 'tools/verify_cham.gd',    False, []),
    ('canh Main (Lua)',     'script', 'tools/verify_main.gd',    False, []),
    # Lop CUON CCScrollLayer (lua/cuon.lua) tren canh Main that: do lech, bien,
    # nha ve bien, va nut nha ben phai (ai vo tan) co bam duoc sau khi cuon.
    ('cuon lop thanh pho',  'script', 'tools/verify_cuon.gd',    False, []),
    # BANG danh sach cua engine (lua/bang.lua): LuaTableView_create. Do tung
    # con so cua hop dong CCTableView tren mot uy quyen gia (xep o, kho o dung
    # lai, bien cuon, scrollTo theo ti le, mot cu bam ra dung chi so), roi mo
    # hai man THAT da chet o <bong LuaTableView_create()>.
    ('bang danh sach',      'script', 'tools/verify_bang.gd',    False, []),
    # CUA VAO chien dich: cham THAT vao toa nha [战役] tren man Main. Bo do
    # `do_chien_dich.gd` di TAT qua chinh cai nut (`Show(g_CUISelectLevel...)`),
    # nen duong nguoi choi di chua tung duoc do. Kem hai phep KIEM CHUNG NGUOC
    # (tat cong chuc nang di thi nut phai khoa lai, va cu cham phai khong mo gi).
    #
    # Bo nay bat mot cai bay do duoc: `CUIMain.lua:251` xep hoat canh TREO
    # `S_CCSequence(DelayTime(0), CCCallFunc(postOnMainShowBeginEvent))` tren
    # `g_MainUIScene`, ma `postOnMainShowBeginEvent` moi POST `OnDialogShowBegin`
    # — su kien mo khoa nut chuc nang. Chuoi 4 chang DUNG ngay khi Main len san
    # khau, NEN do trang thai ngay sau `chay()` la do mot khung hinh DONG BANG:
    # nhan khoa con hien, `_getBuildingStatus` tra 1. Nha khung roi moi doc.
    # (`C.tick` tu trong Lua KHONG dung duoc — `_G.C` la BONG.)
    ('nut chien dich (Main)', 'script', 'tools/verify_nut_chien_dich.gd', False, []),
    # Main -> chon ai -> bo tri quan -> tran (g_BattleField gia) -> man ket
    # thuc, qua lop offline: ca chuoi chien dich cua ban goc.
    ('chien dich (Lua)',    'script', 'tools/do_chien_dich.gd',  False, ['--kiem']),
    # Cung duong do nhung BANG CU BAM THAT vao tung nut (touch_at, nhu chuot
    # cua --xem): lop phu nao con hien ma nuot cu bam la lo ngay.
    ('bam that Main -> tran', 'script', 'tools/bam_that.gd',     False, []),
    # BON WIDGET cua man chon ai (Previous / Next / tab Normal / tab Hard) va
    # mot cu cham vao o ai. Hai bo tren deu di qua man nay ma khong hoi duoc:
    # `do_chien_dich.gd` vao bang `Show(...)` roi chon ai bang
    # `L.nSubChapter = i; L:GoNextCallback()` — di tat qua ca bon widget; con
    # `bam_that.gd` chi hoi "co qua duoc buoc khong", no thu lan luot cac o ai
    # cho toi khi MOT o mo ra, nen khong hoi o KHOA co bi tu choi khong.
    # Hai phep kiem chung nguoc: ep `nMainChapter = 2` roi bam Previous (khong ep
    # thi "bam khong doi gi" o chuong 1 la ket qua DUNG, khong phan biet duoc
    # handler song hay chet — `onToPrevious` tra `true` KE CA khi khong lam gi),
    # va cham vao o ai DANG KHOA (bi chan o hai tang: `setEnableLuaTouch(false)`
    # nen no khong con la ung vien nhan cham nao ca, roi cong `BattleStatus == 0`
    # trong `onTouchEnd_OnSelectLevel`).
    ('chon ai',              'script', 'tools/verify_chon_ai.gd', False, []),
    # MAN DAN TRAN (`CUIBattleDeploy`) va con so `Lực` cua no.
    #
    # Ba bo tren deu di QUA man nay ma khong bo nao hoi con so: `do_chien_dich.gd`
    # chi hoi "co qua duoc buoc khong", `bam_that.gd` chi hoi cu bam co toi noi
    # khong, `chon ai` dung lai truoc do mot man. Nen mot loi o day — nhan `Lực`
    # ra 0 du tuong da vao doi — khong bo nao bat duoc.
    #
    # LUAT do tu ma goc: nhan la con tag 1 cua `lBattleDeployImplement`
    # (`CUIBattleDeploy.lua:1433`), ghi boi `calcuFightingCapacity` (`:2592`) =
    # TONG cua tung tuong da xep (`:2587`); moi tuong doc bang
    # `GetHeroAllFightCapacity` (`HeroCapacityLogic.lua:56`) — ham KHONG tinh, no
    # doc truong `AllFightCapacity` da co, va chi lui ve `FightCapacity` khi
    # truong ay NIL (`:65`) — nen mot so 0 (khac nil) chan luon duong lui.
    #
    # Bo kiem doi BA nguon khop nhau: nhan tren NODE THAT trong cay, so cua Lua,
    # va so tinh lai tu chinh hai ham goc. Kem phep KIEM CHUNG NGUOC (xoa hai
    # truong -> nhan PHAI ve 0) va phep do LUY THUA DANG (goi lai `bo_sung` ->
    # so cu tro lai).
    #
    # Bo nay bat duoc mot loi THAT ngay lan chay dau: `offline/handlers/login.lua`
    # goi dien luc chien NGAY sau `ctx:call`, ma `ctx:call` chi DAY vao hang doi
    # (`net.lua:116`) roi khung hinh sau moi chay (`:235`) — nen luot dien ay chay
    # TRUOC `G_DataManager:Init` va dien 0/0 tuong (do trong `offline.log`). Loi
    # ay im lang: chi nhung ban luu co quay tuong moi hien dung so.
    ('dan tran (Lua)',       'script', 'tools/verify_luc_chien.gd', False, []),
    # Man CHIEN DICH (`BattleActivityMode`) nhin tu BEN TRONG. `chon ai` lo man
    # chon ai; `verify_nut_chien_dich.gd` lo phan MO man nay tu nut tren Main;
    # con cac the hoat dong va hai lop chon do kho thi khong bo nao hoi. The lay
    # tu CONFIG nen "tren ban luu offline khong vao duoc loai nao" la ket qua co
    # the dung — bo kiem nay ghi lai tip ma tung the tra ra, va nho do phan biet
    # duoc CONG NAO chan: tip ve CAP DO nghia la cong cap do (`:1438`) chay truoc
    # cong chua mo (`:1446`), chu khong phai mot handler chet.
    ('the hoat dong',        'script', 'tools/verify_the_hoat_dong.gd', False, []),
    # NUT CAN QUET (`ChapterSweepOnce` / `ChapterSweepTen`) — duong tieu the luc
    # va luot thach dau trong ngay. Truoc luot nay lop offline KHONG co handler
    # nao cho hai lenh ay: `offline.log` co 20.983 dong THIEU ma khong dong nao
    # mang chu "Sweep". Bo kiem nay khoa bon dieu bang so DO:
    #   (1) moi luot quet tru DUNG `ChapterUserFatigue` = 6 (do tren `L_N_01_01`),
    #       va quet 10 lan tra ve danh sach DUNG 10 muc chu khong gop — client doc
    #       no bang `ipairs` va `#tRetData >= 5` moi chen danh sach bao hiem;
    #   (2) tran 10 va tran `PlayPerDay` deu do LOP NAY gac: ban goc chi tinh
    #       `nMaxSweepCount` de HIEN THI roi goi `ChapterSweepTen(key)` tran
    #       (`CUIChapterInfo.lua:2793-2795`, `:2796-2810`), nen khong co cho nao
    #       khac gac. Khoi D nang `PlayPerDay` len 25 (co tra lai nguyen trang)
    #       de chung minh 10 la tran that chu khong phai bang so luot con lai;
    #   (3) tu choi thi van tra DU HINH client doc duoc (`ChapterKey` chuoi +
    #       `DropList` bang) — thieu mot trong hai la `ProcessNotString` /
    #       `ProcessNotTable` BAN mot dong loi ra nhat ky (do duoc voi phan hoi
    #       `{ErrorCode=1}`);
    #   (4) khong sinh vet `ProcessError!` gia: `ReduceSweepCount` (`:1342`) tu
    #       choi khi so du bang 0 va chinh ban goc IN RA ngan xep moi lan no tra
    #       false, nen lop nay phai HOI so du truoc khi tru.
    # Khoi F2 CO Y roi vao nhanh loi cua ban goc (`share_ChapterLogic.lua:1803`)
    # de chung minh cong so luot: hieu AM moi la duong tu choi that, con hieu
    # BANG 0 thi ban goc van tra `true` kem tran 0 — lop nay moi la cho tu choi.
    ('can quet',             'script', 'tools/verify_can_quet.gd', False, []),
    # QUA MOC CHUONG (`CUILevelTarget`, 阶段目标) — moc "the luc da tieu", thanh
    # tuu loai 3000. Truoc luot nay `ConsumFatigueValue` khong co NGUON GHI nao
    # trong ca hai kho: 21 cho goi `SetStatisticsCommonData` trong `sc/` nhung
    # khong cho nao dung chuoi ay, no chi duoc DOC (`AchieveCheckLogic.lua:1104`,
    # `CUILevelTarget.lua:50`). Do duoc truoc khi sua: the luc roi THAT (120 ->
    # 114 sau mot luot quet) ma thong ke van `nil`, tien do van 0, nen moc khong
    # bao gio sang `Done` va qua cua no khong bao gio phat. Bo kiem nay khoa:
    #   (1) KHOA GHI dung la khoa client dang nghe — ban ghi thanh tuu 3000 mang
    #       `DataEventList = { "GameUserGlobalData.Sta_ConsumFatigueValue" }`,
    #       dung chuoi ma `SetCommonData` phat ra (`strSaveKey = "Sta_" .. key`);
    #   (2) hai duong doc doc lap phai khop: the luc roi bao nhieu thi thong ke
    #       tang dung bay nhieu (nhom B, C — va C cho thay dem theo so lan quet
    #       THAT chu khong theo so lan client xin);
    #   (3) ghi NET chu khong ghi GOP — nhom D chan `chapterSweepHandle` de ep
    #       ba duong hoan the luc chay that; ghi gop thi quet mai mot ai luon that
    #       bai se day duoc moc ma khong mat gi;
    #   (4) day chuyen moc da co san, khong phai viet them: nhom E ghi thang 850
    #       va doi `State` nhay 1 (Doing) -> 2 (Done) — bo do KHONG goi
    #       `ReachAchieve`, nen cu nhay ay chung minh client tu nghe su kien roi
    #       goi `CallReachAchieve` xuong handler `offline/handlers/achieve.lua`.
    # CHO GHI la cho DUY NHAT phai SUY trong bo kiem nay: nua ghi cua ban goc nam
    # phia server va khong duoc ship — dung kieu voi nguoi goi `ReduceSweepCount`.
    ('qua moc chuong',       'script', 'tools/verify_moc_chuong.gd', False, []),
    # Kich ban tran: nap sc/plot/drama_<ai>.lua, chay coroutine, do chuoi thoai.
    ('kich ban tran (Lua)',  'script', 'tools/do_chien_dich.gd', False, ['--kichban']),
    ('tang cau hinh (Lua)', 'script', 'tools/verify_lua_config.gd', False, []),
    ('trang bi (GDScript)',  'script', 'tools/verify_equipment.gd', False, []),
    ('man trang bi',         'scene',  'tools/verify_equip.tscn', False, []),
    ('man nhiem vu',         'scene',  'tools/verify_tasks.tscn', False, []),
    ('thien vi san',         'scene',  'battle/battle.tscn',      False,
     ['--sim=300', '--mirror']),
    ('giao van mang',        'script', 'tools/verify_net.gd',     True,  []),
    ('phien choi',           'script', 'tools/verify_session.gd', True,  []),
    ('RPC / chong gian lan', 'script', 'tools/verify_rpc.gd',     True,  []),
    # Cau hoi quan trong nhat cua man tran: cai chieu tren man co DUNG la tran
    # may chu da xu khong. Can may chu that.
    ('phat lai dung tran',   'scene',  'battle/battle.tscn',      True,
     ['--replaycheck']),
    # Am thanh boc tu .bank cua ban goc: tung file .ogg phai nap duoc bang
    # AudioStreamOggVorbis va do dai phai BANG so_mau/rate cua FSB5 — do dai
    # dung moi chung minh khoi setup, so kenh va granule trang cuoi deu dung.
    # Kem theo: bang tra event:/... -> file phai tra ra file that cho bay
    # tieng ma chinh SoundManager.lua cua ban goc dung, VA phan cuoi di dung
    # duong Lua (khung suon -> G_SoundManager -> kenh phat) — truoc day cac
    # ten do la BONG nen moi tieng bam nut deu cam.
    ('am thanh',             'script', 'tools/verify_am.gd',     False, []),
    # Ba ham DIEM GAN cua armature (_lua_addChildToPlugIn / _lua_clearPlugIn /
    # _lua_getPlugInPositionInNode, 48 cho goi trong ma goc). Truoc day chung
    # KHONG TON TAI: ten khong co trong bang Node nen roi vao __index, tra ve
    # mot ham dem lai roi tra nil — khong bao loi, chi la khong co gi duoc treo.
    # Do bang cach so vi tri do duoc LUC CHAY voi vi tri ghi trong chinh file
    # armature Gashapon (PlugIn_4..7, dong tac Star1 — ca bon chi co mot khoa,
    # nen vi tri la hang so).
    ('diem gan armature',    'script', 'tools/verify_plug.gd',   False, []),
    # To xam (shader so 1 cua ban goc, `.rodata 0x7ccf00`). Kiem PHAN NOI DAY:
    # node VE nao doi sang vat lieu xam, node nao khong (nhan di duong Lua,
    # lop mau chua lam), vat lieu dung chung, va cong thuc trong file
    # .gdshader — he so sai o do la loi IM LANG nen phai doc file ra kiem.
    # Phan HINH do bang `tools/do_xam.gd`, chay CO trinh ve that nen khong nam
    # trong bang nay.
    ('to xam (Lua)',         'script', 'tools/verify_xam.gd',    False, []),
    # Hieu ung sang (shader so 2 cua ban goc, `.rodata 0x7cccd4`): cung ho
    # "ten -> chuong trinh" voi `setGray`. Kiem phan NOI DAY — ba lop CO ANH
    # (CCSprite / CCButton / CCScale9Sprite) doi sang vat lieu sang, nhan va lop
    # mau thi khong, hai node dung chung mot vat lieu, va luat kho nhat: hai hieu
    # ung dung CUNG mot o chuong trinh cua node nen tat cai nay la tra ve chuong
    # trinh THUONG, tuc xoa luon cai kia. Cong thuc (rgb x1,5, alpha khong nhan)
    # doc tu chinh file `.gdshader`; phan HINH do bang `tools/do_sang.gd`.
    ('to sang (Lua)',        'script', 'tools/verify_sang.gd',   False, []),
    # Chuyen sac chu (shader so 8 cua ban goc, `.rodata 0x7cbcac`). Bon ham nay
    # CHI co o lop 12 `Label` — bang bind quet ca 132 lop chi ra dung bon ban ghi,
    # va `CCLabelTTF` trong .xgg lai LA lop 12 luc chay (do duoc: goi duoc
    # `setDimensions` — API chi lop 12 moi co — len node nhan cua mot file .xgg
    # that). Nen phep kiem "node nao" khong the la `type_name == 'Label'`. Kiem
    # ca ba tang: cong thuc trong file `.gdshader` (tron nguoc chieu la loi IM
    # LANG), phan noi day (vat lieu theo TUNG node, chieu cao theo o, co khoi tao
    # 0), va duong ma man hinh dung — `g_CUIPublic:SetEnableGradualLableGray`,
    # noi khoa luon thu tu sau gia tri vi no "lam phang" dai bang bo ba THU HAI.
    # Phan HINH do bang `tools/do_chuyen_sac.gd` (can trinh ve that).
    ('chuyen sac chu (Lua)', 'script', 'tools/verify_chuyen_sac.gd', False, []),
    # He HAT cua ban goc (ui/hat.gd + lua/hat.lua). Du lieu: 33 dinh nghia
    # .plist boc bang brave-cross/work/hatref.py; bo cuc dung 87 node, 7 dinh
    # nghia. Bo kiem tinh LAI tung tham so tu file JSON roi doi chieu voi vat
    # lieu ma ui/hat.gd dat ra — hai duong khac nhau phai ra cung so, va bon
    # khang dinh trong chu thich (duration am ca 33, rotationEnd == rotationStart
    # ca 33, L+v > 0 ca 33, khong kenh mau nao 0 kem phuong sai) thanh phep kiem
    # chu khong con la cau chu.
    ('he hat',               'script', 'tools/verify_hat.gd',    False, []),
    # RichLabel: chu co the mau (bien `failed` ma CHINH Lua ban goc gan — truoc
    # day la bong nen `parseString_` tra nguyen chuoi lam mot doan, moi chuoi co
    # the hien nguyen the ra man hinh) va che do tach TUNG KY TU
    # (`getLimitShowCount` / `getLetterEx` tung tra 0/nil nen moi doan chu nam im
    # o (0,0) thay vi duoc xep cho). Do bang so tren chuoi that co dau.
    ('RichLabel',            'script', 'tools/verify_richlabel.gd', False, []),
    # O CHU cua nhan: ban goc giu BA truong rieng (o +0x2c4/+0x2c8, cap tra loi
    # +0x5c/+0x60, co autoFix +0x21c), nen `getContentSize` khong phai kich thuoc
    # node. Do bang cach chay DUNG chuoi buoc cua `brave-cross/work/emu_nhan.py`
    # tren ban goc that (may ao Android, bon luot) roi doi chieu LUAT — diem anh
    # khong so duoc vi font cua ta khac tahoma. Gom ca ba cho tung sai: co "ban"
    # bi cong theo `gd.size` (nen `setDimensions(w,0)` roi `setString` tra so CU),
    # `autoFixSize` khi o cao 0 (ban goc ra 0, nhan bien mat), va `setContentSize`
    # khong xoa co "ban" nen lan doc dau van bo cuc lai.
    ('o chu / autoFixSize',  'script', 'tools/verify_dimensions.gd', False, []),
    # Thanh / vong tien do cua ban goc (ui/tien_do.gd + lua/tien_do.lua, 325
    # node trong 73 bo cuc). Truoc day chung la node 'layer' co anh nen bi coi
    # la SPRITE va ve day dac o moi phan tram. Bo kiem chay bon tang: neo va
    # tinh CAT cua thanh, hinh hoc quat (nam gon trong o, dung chieu, khong vat
    # bon goc), noi day tu bo cuc THAT (o lay theo BAN GHI chu khong theo anh —
    # g_ptWarSoulTBar o 71x297 ma anh 102x324), va duong Lua (setPercentage /
    # setType phai doi dung node, con setOrange phai CON dem duoc la thieu).
    ('tien do',              'script', 'tools/verify_tien_do.gd', False, []),

    # O NHAP CHU (CCEditBox, 40 node trong 22 bo cuc). Truoc luot nay
    # ui/xgg_layout.gd xep chung vao kind 'label' nen chung thanh NHAN CHU, va
    # bay phuong thuc cua ma goc roi vao bo dem M.missing ma khong mot loi nao.
    # Bon tang: du lieu .xgg (40 node / 22 file; ban ghi o nhap khong co
    # text/alignH/alignV, anh nen 30x30 dung cho o 150x30..410x45 nen ban goc CO
    # GIAN anh theo o), nam phuong thuc cua CCEditBox doi chieu voi lop Node,
    # duong nguoi choi (cham -> tieu diem -> go phim that -> bon su kien began /
    # changed / ended / return ban ra ham Lua da dang ky), va thu tu tren-duoi
    # giua o nhap voi node co ten cham.
    ('o nhap',               'script', 'tools/verify_o_nhap.gd',  False, []),

    # BONG cua armature (_ShowShadow / _SetSyncShadowPosY / _UpdateShadowPosY,
    # 23 cho goi: 20 / 3 / 0). Truoc luot nay ba ten ay khong co trong bang Node
    # nen roi vao __index va chi bi dem lai — khong loi, chi la khong bao gio co
    # bong. Do ba khang dinh doc tu ma may cua ban goc: bong chi TON TAI khi co
    # nguoi goi `true` (khong dung san), `false` XOA HAN chu khong lam mo (lan
    # `true` sau tao doi tuong MOI), va armature dang an thi bong van duoc tao
    # nhung o lai trang thai an. So lieu (ti le / do dam / ten tai nguyen) doi
    # chieu voi phep dem tho tren cau hinh goc, va anh bong kiem bang chinh file
    # PNG: phai ra mot ELIP DAC vien cung, alpha phang 112/255 = 0,439 trong long
    # hinh (do lai: ca anh khong diem nao qua 115/255) — khong phai gradient mem.
    # Do la phep thu cho thuat toan tach alpha cua ETC1: doc sai mat na thi khong
    # ra hinh doi xung gon gang nhu vay.
    ('bong armature',        'script', 'tools/verify_bong.gd',   False, []),
    # HOP CHAM cua armature (`_lua_CollisionSize`) — 6 cho goi, truoc day ten
    # khong co trong bang Node nen roi vao `__index`: khong loi, chi la cai nhan
    # tren dau nhan vat roi vao goc. Ba tang doc lap: bang so lieu (ChamRef tinh
    # lai cong thuc tu chinh cac thanh phan no luu), bay phep do tren may ao ghi
    # thang vao bo kiem, va duong Lua qua `getSpriteFromSpriteCatch`. So do phan
    # biet that: chieu RONG truoc chieu CAO (ElephantSoldier 170,52 x 118,5).
    ('cham armature',        'script', 'tools/verify_cham_size.gd', False, []),
    # DIEM / HOP CUA MOT XUONG BAT KY (`_lua_getBonePosInNode`,
    # `_lua_getBoneRectInNode`) — hai cho goi trong `CUIHeroInfoFightSoulUI.lua`,
    # man gan MAT len DAU nhan vat. Chong vao `__index` cua lop gia lap: ten nao
    # cung tra ve MOT HAM, nen phep gac `~= nil` cua ban goc luon dung roi hai so
    # tra ve la nil — do la mot loi Lua THAT, khong phai mot API im lang. Bon
    # tang: cap `+0x08` doc lai tu file, nam phep do may ao, o cua anh xuong
    # (`sourceSize`, ke ca anh `_res-44` khong cat duoc PNG), va luat doi khong
    # gian (dich truot 140,43 -> ket qua doi dung -(140, 43)).
    ('xuong armature',       'script', 'tools/verify_xuong.gd',     False, []),

    # HIEU UNG SAO theo cap sao cua tuong (`_Lua_addStarLevelEffect`) — 4 cho goi
    # (tui / doi hinh / thong tin tuong / hang / ai vo tan qua `ClientPaperDoll`,
    # va san tran qua `CUIGame.lua:953`). Truoc luot nay ten khong co trong bang
    # Node nen roi vao `__index`: gac `~= nil` luon dung, khong mot loi nao, chi
    # la hieu ung khong bao gio hien — nen phep kiem phai DEM so armature duoc
    # gan chu khong chi doi "chay khong loi". Bon tang: bang so lieu rut tu khoi
    # `<star>` cua `global_config.xml` va doi chieu ten voi `map/StarLevelEffect.xml`
    # (sau cap sao, 11 ten, moi bien the DUNG mot dong tac `PluginPlay`, cap 1
    # KHONG co muc nao), 11 bien the dung thang tu `assets_ref` (so xuong phan
    # biet "chon dung bien the" voi "chon nham", va hai bien the co rig long nhau
    # nam trong `parts` chu khong trong `spriteFiles`), duong Lua do ca THU TU va
    # viec rig cua tuong VAN la con dau tien (neu khong thi `_rig_cua` tro nham
    # sang hieu ung), va chinh `g_ClientPaperDoll` chay nguyen van.
    ('hieu ung sao',         'script', 'tools/verify_sao.gd',         False, []),

    # Bon nhom API cua lop gia lap vua lam xong. Doc lap truoc tien: bang LIEN KET
    # xuong -> anh cua chinh file `.json` (`Dice3` la ANH, `Light3` la MOT BIEN THE
    # long nhau — dung hai bang ay la ly do ban goc co hai ham rieng cho mot viec
    # tuong nhu mot), roi den `SngRig.thay_o_hien` (THAY o `idx` chu khong THEM, va
    # o do lai duoc ham khung sau do nhat len), roi den duong Lua DUNG NHU CHO GOI
    # THAT (`CUIShakeDice.lua:404-419` lat sau mat xuc xac — ca hai nhanh `nPoints
    # == 6` va khong; `CUIHeroInfoFightSoulUI.lua:2673` doi so cua bua vo hon voi
    # TEN BIEN THE chu khong phai ten thu muc), va cuoi cung la bon so cua vung
    # cham di qua chinh `LuaRuntime.touch_at` / `_trong_thuc` (hai goc doi trong
    # khong gian cua node CHA, khac han o cua chinh node — phep kiem chon diem
    # phan biet duoc hai cach hieu), tieng dong chi phat o pha Begin, va
    # `_Lua_changeWingAnimation` voi tới CANH ma khong dung tới nhan vat.
    ('o hien armature',      'script', 'tools/verify_o_hien.gd',      False, []),

    # CHO DUNG QUAN — hang so lan cua man tran. Bon nam hang so cua
    # `battle/san_tran_ve.gd` (LAN_CACH/LAN_LECH/LAN_SO/ARMY_SPACE) va nam hang so
    # camera tung la ĐẶT: ghi chu noi "suy tu chinh map/global_config.xml" chu
    # khong co cho nao trong file game noi engine dung chung the nao. Nay do duoc
    # het, va bo kiem nay giu cho chung khong troi lai: chu thich 道宽 格 ngay
    # tren hai hang so trong chinh file cau hinh (don vi la O), cho engine nhan voi
    # co o px (`0x35f43e` BAN VN -> `vmul.f32` voi `+0x270` = `this+0x180`), cong
    # thuc xep lan `0x35f0a4` (vn) (`y = y0 + (Location-1)*rong + lech`, ra
    # 10/50/90 px), so
    # lan dem tu `Location` cua bang binh chung (91 muc, 0..3 — nen LAN_SO cung la
    # so do chu khong phai so ta chon), va `fArmySpace` co ban anh em
    # `fArmySpaceInArena` cho dau truong (hai ham doc rieng trong engine). Neu
    # thieu `data_ref/tran_ref.json` thi bao BO QUA.
    ('cho dung quan',        'script', 'tools/verify_lan.gd',          False, []),
    # Cho DAT toan linh khi bam nut binh chung: phai dung MOC CUA TOAN
    # (`Sprite.Troop.PosX` = 3,83 / 7,1 / 7 o tuy loai tran), khong phai o 0
    # (mep trai san). Truoc day `dua_linh` truyen cung 0.0 nen linh dua ra dung
    # cach toan minh 4..7 o. Suy ra chu CHUA DO duoc: `dispatch()` cua engine
    # khong tinh toa do (`0x45eda4` -> `0x466220`), con may ao thi chet trong
    # `RepaleceScene` khi bat `bDirectBattle` — xem `work/emu_dom.py`.
    ('cho dat toan linh',    'script', 'tools/verify_dat_linh.gd',      False, []),

    # HAI LOI lam man tran khong choi duoc. (a) `g_BlackEffectLayer` cua bo cuc
    # HUD goc la tam den DUC 2000x1000 mau [0,0,0] phu kin san — do tren khung
    # hinh that: 614.400/614.400 diem anh cung MOT mau (0,0,0); ban goc tat no
    # bang co `bShowBattleBlackEffectLayer` = false cho ai thuong
    # (`ChapterNormalLevel.lua:8`), va ten node nam trong pool chuoi cua
    # `libgame.so` (vn `0x7c0dc7`) nen chinh ENGINE tim node theo ten roi bat/tat.
    # (b) `SpriteName` trong bang quan chung la ten LOAI QUAN chu khong phai ten
    # armature (`Archer(new)`, `Stakes`, `witch doctor`) — 62/80 ten khong co
    # armature nao, ke ca trong kho atlas cua ban goc, nen moi tran ra hang tram
    # dong `SngRig: khong thay ...`. Bon bo kiem khong bat duoc vi bo do tran
    # chay `--sim`, ma duong ay goi `_spawn(false)` — tat han phan hinh. Bo nay
    # chay DUNG `_build_hud()` / `_add_unit()` cua man tran va khoa ca hai chieu:
    # ten CO armature thi PHAI hien, ten KHONG co thi PHAI vo hinh nhung VAN nam
    # tren san va VAN danh (bat/tat phan hinh khong doi mot con so mo phong nao).
    # Khoa luon chieu chong "sua loi" nguoc: luat tien to cua kho (`_thu_muc_rig`)
    # "cuu" duoc 32/62 ten nhung do la BAY — 0/80 ten trong bang la bien the that
    # su, nen ap luat ay la gan `Archer(new)` vao hinh `Archer` cu.
    ('man tran',             'scene',  'tools/verify_man_tran.tscn', False, []),
    # Cua vao cua game: `godot --path .` phai mo thang man Main THAT cua ban goc,
    # va bam Back tu nam man GDScript phai ve do TUC THI (runtime Lua nam trong
    # autoload `Game`, do duoc 5 ms so voi ~5000 ms nap lai).
    # Phai la `scene` chu khong `script`: can autoload, can theme tren root, va
    # can chuoi khoi dong chay trong mot MAN THAT.
    # Gia phai tra: nhom D chay THAT ca chuoi Login -> Main (~5 giay may ranh,
    # 7-15 giay khi chay nang may ao Android), nen bo kiem nay lam `check.py`
    # cham them chung ay.
    ('cua vao',              'scene',  'tools/verify_vao_game.tscn',  False, []),

    # `pb` — bo protobuf Lua thuan thay cho mo-dun C lua-protobuf.
    #
    # `pb` la mo-dun C, ma Lua o port nam trong addon Godot nen `require("pb")`
    # KHONG BAO GIO giai ra ma C — dat tep o dau cung vay. Do duoc: ban goc goi
    # dung BA ham (`pb.load` / `pb.encode` / `pb.decode`), o TAM cho, trong sau
    # tep. Nen `lua/pb.lua` la ban viet lai bang Lua thuan.
    #
    # Va day khong phai viec "lam cho dep": `protoc.lua` KHONG chiu duoc su vang
    # mat cua `pb`. Khoi `do...end` mo o :970 dong o :1109 dinh nghia
    # `Parser.reload/compile/compilefile/load/loadfile` va goi `Parser.reload()`
    # VO DIEU KIEN o :1107; khong co `pb` thi ca khoi bi bo qua va `Parser` tra ve
    # KHONG co `load`, nen `system/LoadProto.lua:100` chet bang
    # "attempt to call method 'load' (a nil value)" — dung nhu do truoc khi viet.
    # Tuc mot `pb` gia tra `nil` con TE HON la khong co `pb`.
    #
    # Phep kiem chinh la oracle blob cua Google, va no co luc that: lay NGUYEN VAN
    # doan `local descriptor_pb = ...` nhung trong `protoc.lua` (4604 byte, 92
    # manh chuoi, 21 message / 4 enum / 97 truong), giai ra roi ma hoa lai, doi
    # khop TUNG BYTE. Thieu mot truong trong schema `descriptor.proto` viet tay
    # trong `lua/pb.lua` thi `pb.decode` bo qua no va `pb.encode` khong ghi lai,
    # nen do dai lech ngay. Gioi han noi ro: ten truong dung SAI thi khong bat
    # duoc (ten dung doi xung o hai chieu).
    #
    # Doc `res://sc/Framework/Network/pb/protoc.lua` + `res://sc/def/PBProto.lua`,
    # tuc phai chay `python tools/import_lua.py` truoc (no bo sung lop mang 1.31
    # tu cay CN, luat chi-them). Tang C con doc 7 tep `.proto` that o cay nguon
    # VN — khong commit duoc, thieu thi bao BO QUA chu khong bao hong.
    ('pb (protobuf)',        'script', 'tools/verify_pb.gd',           False, []),

    # `setGear` / `setLevelGear` — bang DO (trang bi). Ban goc gan do bang hai
    # ham TOAN CUC, va `__index` cua lop gia lap tra ham cho MOI ten: thieu hai
    # ham ay thi **khong mot dong loi**, do chi don gian la khong bao gio doi.
    # Do la lop loi im lang dung nghia nhat trong repo, nen no khong lo ra bang
    # "chay khong co loi" — phai DEM va phai doi chieu voi BANG.
    #
    # Bon tang, tat ca deu chay tren rig THAT: (A) hinh dang bang — 201 muc
    # `<Gear>` + 14 muc `<Parts>`, nam loai muc 115/70/7/3/6, dung MOT muc ra
    # trong (`equip_3_999`), va cong thuc du phong phai TRUNG bang `<Parts>`
    # (7/7 — hai cho doc lap trong cung mot file, cung mot dap so); (B) nhanh
    # arm tren BIEN THE CUA NHAN VAT CHINH (`HeroID 25` -> `HeroSprite
    # "Player000M03W"`, do tu `battle_data.json`), gom ca CHAN TREN 7..10 -> `_6`
    # va o TRONG `equip_3_999`; (C) node con (canh) va lenh AN `_Hide`; (D) nang
    # BUNDLE — duong `setLevelGear`, tuc hai man DOANH TRAI — va nang `<Parts>`,
    # doi moi muc di theo dung `nPartsType` cua no va ghi dung MOT lan.
    #
    # Phep kiem da kiem chung NGUOC: lui nang `<Parts>` ve ban cu (co loi ghi
    # hai lan) ra **45 dat / 1 hong** dung cho ghi hai lan; bo nhanh LIST ra
    # **45 dat / 1 hong** dung cho ly do `kieu 0 (?)`.
    #
    # `data_ref/gear_ref.json` sinh tu file bang cua ban goc (xem `.gitignore`),
    # thieu thi bao BO QUA chu khong bao hong.
    ('do (trang bi)',        'script', 'tools/verify_dat_do.gd',       False, []),

    # SO SAT THUONG NOI cua tran co hinh. Ban dung truoc day KHONG co duong
    # nay, con du lieu thi du: khoi `<label>` cua `map/global_config.xml` cho
    # sau loai nhan (he so phong + tran so nhan) va `assets/fonts` co 11 bo
    # phong bitmap — bay bo chi gom chu so.
    #
    # VI SAO "chay khong loi" KHONG NOI LEN GI o day: mot nhan khong ve duoc thi
    # **khong nem mot dong loi nao** — `load()` tra `null`, `Label` khong co
    # phong van ton tai, van `queue_free()` binh thuong. Nen bo kiem phai DEM
    # (`dem()` tra `ve` / `bo` / `im_vi_sao`), dung loi `dem_tieng()` cua
    # `san_tran_ve.gd`.
    #
    # Bang ghep LOAI -> PHONG la **DAT**, va bo kiem khoa no lai chu khong khoe
    # no: sau loai phai tro vao dung MOT trong bay phong HO SO (khong bao gio
    # vao phong CHU), `Critical`/`Shield` phai trung TEN phong, va phai THUA
    # dung MOT phong va goi ten no ra (`ImpactBlue`). Do la cho ghi ro cai
    # chua biet — khong the khoi phuc bang xref (khong mot word 4 byte nao
    # trong `libgame.so` ban vn tro vao vung chuoi 12 khoa nhan hay ten `.fnt`)
    # va Lua cung **0 dong** doc `RiseLabel` tren 1013 tep `sc/*.lua`.
    #
    # Tang G di duong TRAN THAT (`_phat_trung_don` voi don vi that) va khang
    # dinh bo sinh nhan dung day so RIENG: dung chung `_rng` cua tran thi moi
    # lan lech ngang day LCG di mot buoc va DOI KET QUA DANH NHAU — mot hieu
    # ung trang tri khong duoc phep lam viec ay.
    #
    # `data_ref/nhan_ref.json` sinh tu `../brave-cross/work/nhan_ref.py` (xem
    # `.gitignore`), thieu thi bao BO QUA chu khong bao hong.
    ('so sat thuong',        'script', 'tools/verify_nhan.gd',         False, []),
    # HIEU UNG THUC TINH — 24 truong `s*` cua khoi `fight_<X>Wake`. Truoc day
    # `tuyet_chieu` chi goi `_play_lai(action)`, tuc chi doi dong tac cua CHINH
    # tuong; 14 truong con tro toi nhung armature RIENG (vong tron CaiWenJi, chu
    # ZhaoYun, khien SuperThunderDragon, hieu ung trung SiMaYi) va KHONG duong
    # nao cham toi chung.
    #
    # Cung loi "chay khong loi khong noi len gi": mot armature khong dung duoc
    # thi khong nem mot dong loi nao, nen bo kiem phai DEM (`dem_thuc_tinh`).
    #
    # Va cung loi nhan: o day co HAI con so de tu khen nham, nen bo kiem tach
    # han chung ra — **22/23 ten tra ra duoc thu muc**, nhung chi **18 dung duoc
    # rig** (`chinh_xac = true` chan phep lui ve than cua tuong, xem
    # `SngRig.build`). Bon ten khong dung duoc nam dung trong so sau ten ma
    # `SngRig` da ghi la "khong co art rieng".
    #
    # Bang chia 24 truong thanh 14 SINH HIEN + 10 TU THAN la **DAT** (ban goc
    # ghep trong ~80 lop C++ `CDFSpriteFight*Wake`), nhung hai dau mut deu do
    # duoc, va bo kiem khoa no lai chu khong khoe no: khang dinh KHONG gia tri
    # nao cua nhom TU THAN bi sinh, va goi TEN cho lech duy nhat ra
    # (`SiMaYi_WakeEffect` nam trong `sWeaponWake` nhung la hieu ung that).
    #
    # `data_ref/wake_ref.json` sinh tu `../brave-cross/work/wake_ref.py` (xem
    # `.gitignore`), thieu thi bao BO QUA chu khong bao hong.
    ('hieu ung thuc tinh',   'script', 'tools/verify_thuc_tinh.gd',    False, []),
]

SCORE = re.compile(r'dat (\d+), hong (\d+)')
SKIP = re.compile(r'^BO QUA: *(.+)$', re.M)


def find_godot():
    """Tim Godot, ke ca khi winget khong tao duoc alias.

    Cai bang winget MA KHONG co quyen admin thi no bao "Successfully installed"
    nhung KHONG tao duoc symlink trong WinGet\\Links — exe nam nguyen trong
    WinGet\\Packages\\<id>\\Godot_vX.Y.Z-stable_win64.exe. Truoc day chi tim
    'godot' tren PATH va cai alias do, nen may nao cai kieu ay la coi nhu
    khong co Godot.
    """
    p = shutil.which('godot') or shutil.which('godot_console')
    if p:
        return p

    guess = os.path.expandvars(
        r'%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe')
    if os.path.isfile(guess):
        return guess

    pkgs = os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\WinGet\Packages')
    if os.path.isdir(pkgs):
        # Ban moi nhat truoc, va uu tien ban _console vi tren Windows no moi
        # chac chan do stdout ve cho tien trinh goi.
        found = []
        for d in os.listdir(pkgs):
            if 'Godot' not in d:
                continue
            for f in os.listdir(os.path.join(pkgs, d)):
                if f.startswith('Godot_v') and f.endswith('.exe'):
                    found.append(os.path.join(pkgs, d, f))
        if found:
            found.sort(key=lambda f: ('_console' not in f, f), reverse=False)
            found.sort(key=lambda f: os.path.basename(f).split('-')[0], reverse=True)
            return found[0]

    for env in ('GODOT', 'GODOT4'):
        p = os.environ.get(env)
        if p and os.path.isfile(p):
            return p
    return None


def server_up(url):
    try:
        import urllib.request
        with urllib.request.urlopen(url + '/healthcheck', timeout=3) as r:
            return r.status == 200
    except Exception:
        return False


SCRIPT_ERR = re.compile(
    r'^(?:SCRIPT ERROR|ERROR|USER SCRIPT ERROR)[:.] *(.+)$', re.M)


def first_script_error(out):
    """Dong loi dau tien cua Godot, hoac '' neu khong co.

    Dung de phan biet 'chay lau' voi 'crash roi treo'. Godot khong thoat khi
    script loi trong che do --script, nen khong co cai nay thi ca hai truong
    hop deu ra QUA GIO nhu nhau.
    """
    m = SCRIPT_ERR.search(out or '')
    return m.group(1).strip()[:70] if m else ''


def run(godot, kind, path, extra, url, needs_server):
    argv = [godot, '--headless', '--path', ROOT]
    argv += ['--script', path] if kind == 'script' else [path]
    argv += ['--']
    argv += extra
    if needs_server:
        argv += ['--url=' + url]
    # Gop stderr vao stdout. Godot do 'SCRIPT ERROR' ra stderr; truoc day
    # capture_output bat rieng roi vut di, nen mot bo crash xong TREO chi hien
    # ra thanh 'QUA GIO' — dung y het mot bo chay lau, va loi that bi che.
    try:
        out = subprocess.run(argv, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True,
                             encoding='utf-8', errors='replace',
                             timeout=600).stdout or ''
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ''
        if isinstance(out, bytes):
            out = out.decode('utf-8', 'replace')
        err = first_script_error(out)
        return ('QUA GIO sau khi loi: %s' % err) if err else 'QUA GIO', True

    err = first_script_error(out)
    if err and not SCORE.search(out):
        return 'LOI SCRIPT: %s' % err, True
    # BO QUA khac HONG: bo am thanh can am thanh cua ban goc, ma thu muc do
    # khong commit duoc (xem .gitignore). Tren may khong co APK thi no phai la
    # "bo qua", khong phai "do".
    m_skip = SKIP.search(out)
    if m_skip:
        return 'BO QUA (%s)' % m_skip.group(1).strip(), False
    m = SCORE.search(out)
    if m:
        ok, bad = int(m.group(1)), int(m.group(2))
        return '%d dat, %d hong' % (ok, bad), bad > 0
    if 'san khong thien vi' in out:
        return 'dat', False
    if 'THIEN VI' in out:
        return 'HONG: san thien vi mot ben', True
    return 'KHONG DOC DUOC KET QUA', True


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--url', default='http://127.0.0.1:7350')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')

    godot = find_godot()
    online = server_up(a.url)

    print('\ngodot   : %s' % (godot or 'KHONG thay'))
    print('may chu : %s  ->  %s\n'
          % (a.url, 'dang chay' if online else 'KHONG noi duoc'))

    # Bo ca doi chieu trang bi la thu SINH RA duoc (cong thuc thuan, khong
    # can bang so nao cua ban goc), ma data_ref/ thi khong commit — nen tu
    # sinh khi thieu, thay vi de bo test bao hong tren mot ban clone moi.
    eq_ref = os.path.join(ROOT, 'data_ref', 'equipment_ref.json')
    if not os.path.isfile(eq_ref):
        print('  ... sinh %s' % os.path.relpath(eq_ref, ROOT), flush=True)
        subprocess.run([sys.executable, os.path.join(ROOT, 'sim', 'equipment.py'),
                        '--export'], capture_output=True, text=True, timeout=120)

    # Cung loai: bien_gan.json la danh sach 6.901 ten ma CHINH Lua ban goc gan
    # (tools/import_lua.py: ghi_bien_gan). Thieu no thi boot.la_bong() tra ve
    # sai cho dung nhung ten do — RichLabel lai tra nguyen chuoi lam mot doan,
    # tuc la bo RichLabel bao hong vi mot file thieu, chu khong vi code hong.
    # Sinh lai duoc tu sc/ nen tu sinh, y nhu tren.
    gan_ref = os.path.join(ROOT, 'data_ref', 'bien_gan.json')
    if not os.path.isfile(gan_ref):
        print('  ... sinh %s (tools/import_lua.py)'
              % os.path.relpath(gan_ref, ROOT), flush=True)
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'import_lua.py')],
                       capture_output=True, text=True, timeout=900)
        if not os.path.isfile(gan_ref):
            print('  (khong sinh duoc — thieu ma goc sc/: xem README brave-cross)')

    # Am thanh thi KHAC: no la du lieu cua ban goc, khong sinh ra duoc — chi
    # boc lai duoc tu APK. Khong co APK thi bo do am thanh tu bao BO QUA (xem
    # tren), con co thi boc luon cho tien: 1498 file .ogg, vai chuc giay.
    bank_py = os.path.join(os.path.dirname(ROOT), 'brave-cross', 'work', 'bank.py')
    apk_banks = os.path.join(os.path.dirname(ROOT), 'brave-cross', 'work', 'vn',
                             'apk', 'assets', 'banks')
    am_kem = os.path.join(ROOT, 'assets_ref', 'audio', 'bank_ref.json')
    if not os.path.isfile(am_kem) and os.path.isdir(apk_banks):
        print('  ... boc am thanh (bank.py --all)', flush=True)
        subprocess.run([sys.executable, bank_py, '--all', '--out',
                        os.path.join(ROOT, 'assets_ref', 'audio')],
                       capture_output=True, text=True, timeout=600)
        subprocess.run([sys.executable, os.path.join(os.path.dirname(bank_py),
                                                     'event_ref.py')],
                       capture_output=True, text=True, timeout=600)

    rows = []
    failed = 0
    # Nap project mot lan truoc khi chay bo Godot nao. Ten lop toan cuc
    # (class_name) nam trong .godot/global_script_class_cache.cfg — gitignore,
    # nen pull code co lop moi ve ma chua import thi moi script tro toi lop
    # do bao "not declared", nhin y nhu code hong nang. Da gap: bon bo hong
    # mot luc chi vi thieu buoc nay (README, "Lan dau tren mot may moi").
    print('  ... nap project (godot --import)', flush=True)
    try:
        subprocess.run([godot, '--headless', '--path', ROOT, '--import'],
                       capture_output=True, timeout=900)
    except subprocess.TimeoutExpired:
        print('  (godot --import qua gio — van chay tiep)')

    for name, kind, path, needs, extra in SUITES:
        # Thieu Godot thi BO QUA cac bo can Godot, khong thoat han: hai bo
        # Python o duoi (96 kiem tra) chay duoc ma khong can Godot, va tren
        # may chi chay phan may chu thi van muon do chung.
        if not godot:
            rows.append((name, 'BO QUA (khong co godot)'))
            continue
        if needs and not online:
            rows.append((name, 'BO QUA (can may chu)'))
            continue
        print('  ... %s' % name, flush=True)
        text, bad = run(godot, kind, path, extra, a.url, needs)
        rows.append((name, text))
        failed += 1 if bad else 0

    # Nam bo chay bang Python. Bon bo dau khong can gi; bo cuoi can may chu
    # THAT — no do dung cai ma ban gia cua lupa khong do duoc: runtime cua
    # Nakama giu moi so duoi dang float64, con lupa thi co so nguyen 64 bit.
    #
    # `test_import_lua.py` khong kiem ma Lua nao ca: no kiem chinh LUAT CHI-THEM
    # cua `import_lua.py` tren mot cay GIA trong thu muc tam. Vi sao phai co:
    # `sc/` sinh lai tu cay VN moi lan chay import, nen mot lan de len la doi
    # NEN du lieu VN ngay bay gio roi bi lan import sau xoa di — cai sai O LAI
    # con dau vet thi mat. Doc code khong bat duoc loai do; phai ep no chay.
    py_steps = [('mo phong Python', os.path.join('sim', 'test_sim.py'), False),
                ('trang bi', os.path.join('sim', 'test_equipment.py'), False),
                ('luat may chu (Lua)', os.path.join('tools', 'test_server_lua.py'), False),
                ('luat chi-them khi import', os.path.join('tools', 'test_import_lua.py'), False),
                ('tran dan tran (may chu that)',
                 os.path.join('tools', 'verify_field_live.py'), True)]
    for name, rel, needs_server in py_steps:
        if needs_server and not online:
            rows.append((name, 'bo qua (khong co may chu)'))
            continue
        print('  ... %s' % name, flush=True)
        try:
            argv = [sys.executable, os.path.join(ROOT, rel)]
            if needs_server:
                argv += ['--url', a.url]
            out = subprocess.run(argv,
                                 capture_output=True, text=True, encoding='utf-8',
                                 errors='replace', timeout=600).stdout or ''
            m = SCORE.search(out)
            if m:
                rows.append((name, '%s dat, %s hong' % m.groups()))
                failed += 1 if int(m.group(2)) else 0
            else:
                rows.append((name, 'KHONG DOC DUOC KET QUA'))
                failed += 1
        except Exception as e:
            rows.append((name, 'LOI: %s' % e))
            failed += 1

    width = max(len(r[0]) for r in rows)
    print()
    for name, text in rows:
        print('  %-*s   %s' % (width, name, text))
    print()

    if failed:
        print('%d bo co van de.' % failed)
        return 1
    if not godot:
        print('Xong. Cac bo can Godot bi bo qua.')
        print('Cai Godot:  winget install GodotEngine.GodotEngine')
    if not online:
        print('Xong. Cac bo can may chu bi bo qua.')
        print('Bat may chu:  cd server  &&  docker compose up -d')
    if godot and online:
        print('Tat ca xanh.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
