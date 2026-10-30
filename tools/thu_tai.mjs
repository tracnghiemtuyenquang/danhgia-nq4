// =====================================================================
//  THỬ TẢI — giả lập nhiều người làm bài cùng lúc
//  Yêu cầu: Node.js 18 trở lên (https://nodejs.org)
//
//  Cách chạy (trong thư mục tools):
//    node thu_tai.mjs --url https://xxxx.supabase.co --key <anon key> --so 2000 --dong-thoi 100
//
//  --so         tổng số lượt thi giả lập (mặc định 1000)
//  --dong-thoi  số người bấm cùng một lúc (mặc định 50)
//
//  CHỈ chạy khi đợt đang ở chế độ THỬ NGHIỆM (Cài đặt > "Bắt đầu chạy thử" ở
//  quá khứ, "Bắt đầu chính thức" ở tương lai). Chạy xong vào trang quản trị
//  > Cài đặt > "Xóa toàn bộ dữ liệu thử nghiệm".
// =====================================================================
const arg = (k, md) => { const i = process.argv.indexOf("--" + k); return i > 0 ? process.argv[i + 1] : md; };
const URL_SB = arg("url"), KEY = arg("key"), TONG = +arg("so", 1000), DONG_THOI = +arg("dong-thoi", 50);
if (!URL_SB || !KEY) { console.log("Thiếu --url hoặc --key. Xem hướng dẫn ở đầu file."); process.exit(1); }

const headers = { apikey: KEY, "Content-Type": "application/json" };
if (KEY.startsWith("eyJ")) headers.Authorization = "Bearer " + KEY;
async function rpc(ham, body) {
  const t0 = performance.now();
  const r = await fetch(`${URL_SB}/rest/v1/rpc/${ham}`, { method: "POST", headers, body: JSON.stringify(body || {}) });
  const txt = await r.text();
  if (!r.ok) throw new Error(`${ham} ${r.status}: ${txt.slice(0, 160)}`);
  return { data: JSON.parse(txt), ms: performance.now() - t0 };
}

const { data: dot } = await rpc("thong_tin_dot");
console.log(`Đợt: ${dot.ten_dot}\nTrạng thái: ${dot.trang_thai} · ${dot.so_cau} câu · ${dot.dang_bo.length} đảng bộ`);
if (dot.trang_thai !== "thu_nghiem") {
  console.log("\n⛔ Đợt không ở chế độ THỬ NGHIỆM nên dừng lại để không lẫn vào dữ liệu chính thức.");
  console.log("   Vào trang quản trị > Cài đặt, đặt 'Bắt đầu chạy thử' về trước thời điểm hiện tại.");
  process.exit(1);
}

const tg = { bd: [], nop: [], tron: [] }; let ok = 0, loi = 0, dem = 0; const dsLoi = {};
async function motLuot(i) {
  const t0 = performance.now();
  try {
    const db = dot.dang_bo[Math.floor(Math.random() * dot.dang_bo.length)];
    const a = await rpc("bat_dau_thi", { p: { ho_ten: `Thử tải ${String(i).padStart(5, "0")}`, chuc_vu: "Đảng viên", don_vi: "Đơn vị thử tải", dang_bo_id: db.id, lanh_dao: Math.random() < 0.2 } });
    tg.bd.push(a.ms);
    const tl = {}; for (const q of a.data.cau_hoi) tl[q.id] = "ABC"[Math.floor(Math.random() * 3)];
    const b = await rpc("nop_bai", { p_id: a.data.id, p_tra_loi: tl });
    tg.nop.push(b.ms); tg.tron.push(performance.now() - t0); ok++;
  } catch (e) { loi++; const k = e.message.slice(0, 80); dsLoi[k] = (dsLoi[k] || 0) + 1; }
  dem++; if (dem % 100 === 0) process.stdout.write(`  …${dem}/${TONG}\r`);
}

console.log(`\nBắt đầu: ${TONG} lượt, ${DONG_THOI} người đồng thời…`);
const t0 = performance.now(); let tiep = 0;
await Promise.all(Array.from({ length: DONG_THOI }, async () => { while (tiep < TONG) await motLuot(++tiep); }));
const giay = (performance.now() - t0) / 1000;
const tk = a => { if (!a.length) return "–"; const s = [...a].sort((x, y) => x - y), q = p => Math.round(s[Math.min(s.length - 1, Math.floor(p * s.length))]);
  return `trung vị ${q(.5)} ms · 95% dưới ${q(.95)} ms · chậm nhất ${Math.round(s[s.length - 1])} ms`; };
console.log(`\n================ KẾT QUẢ ================
Thành công : ${ok}/${TONG}   Lỗi: ${loi}
Thời gian  : ${giay.toFixed(1)} giây  →  ${(ok / giay).toFixed(1)} lượt nộp/giây
Tải đề     : ${tk(tg.bd)}
Nộp bài    : ${tk(tg.nop)}
Trọn 1 lượt: ${tk(tg.tron)}`);
if (loi) { console.log("Các lỗi gặp:"); for (const [k, v] of Object.entries(dsLoi)) console.log(`  ${v} × ${k}`); }
console.log("\nNhớ vào trang quản trị > Cài đặt > Xóa toàn bộ dữ liệu thử nghiệm.");
