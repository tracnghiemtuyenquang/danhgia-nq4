-- =====================================================================
--  PHẦN MỀM ĐÁNH GIÁ NHẬN THỨC SAU HỌC TẬP NGHỊ QUYẾT
--  Hội nghị Trung ương 4 khóa XIV — Tỉnh ủy Tuyên Quang
--  File khởi tạo CSDL — PHIÊN BẢN 3 (đợt 09–15/11/2026, 65 câu, bảng xếp hạng)
--
--  Chạy trong Supabase > SQL Editor. Chạy lại nhiều lần vẫn an toàn.
--  * Cài mới: tạo đủ bảng, nạp 130 đảng bộ + bộ câu hỏi.
--  * Nâng cấp lên phiên bản 3 (chỉ xảy ra MỘT LẦN, ở lần chạy đầu tiên):
--    - thay toàn bộ câu hỏi bằng bộ 65 câu mới;
--    - đặt lại cài đặt đợt: Ban Tuyên giáo Tỉnh ủy, 120 phút, đạt 70%,
--      tối đa 3 lần, KHÔNG đảo câu hỏi/đáp án, chạy thử từ lúc nâng cấp,
--      chính thức 08:00 09/11 – 22:00 15/11;
--    - XÓA toàn bộ bài thi cũ (đều là dữ liệu thử nghiệm).
--    Giữ nguyên: 130 đảng bộ, tài khoản quản trị.
--    Các lần chạy lại sau đó KHÔNG xóa hay ghi đè gì.
--  * Bản 3.1 (05/11): thêm thống kê lượt truy cập, trang Bảng xếp hạng có
--    danh sách cá nhân theo đảng bộ. Chỉ THÊM, không xóa dữ liệu.
-- =====================================================================

-- ---------- 0. NÂNG CẤP TỪ PHIÊN BẢN 1 ----------
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'bai_thi' and column_name = 'khoa_nguoi') then
    drop table public.bai_thi cascade;
    raise notice 'Đã xóa bảng bai_thi phiên bản 1 (dữ liệu thử nghiệm).';
  end if;
end $$;
drop function if exists public.qt_danh_sach(boolean, text, int, text, boolean, boolean, int, int);
drop function if exists public.qt_thong_ke_cau_hoi(boolean);
drop function if exists public.qt_cham_lai();
drop function if exists public.ds_tot_nhat(boolean);

-- ---------- 1. BẢNG ----------

create table if not exists public.cau_hinh (
  id                int primary key default 1 check (id = 1),
  ten_dot           text not null default 'Đánh giá nhận thức sau học tập Nghị quyết Hội nghị Trung ương 4 khóa XIV',
  don_vi_to_chuc    text not null default 'Tỉnh ủy Tuyên Quang',
  thoi_gian_lam_bai int  not null default 45 check (thoi_gian_lam_bai between 1 and 300),
  ty_le_dat         int  not null default 70 check (ty_le_dat between 1 and 100),
  thu_nghiem_tu     timestamptz,
  mo_tu             timestamptz,
  dong_luc          timestamptz,
  dao_cau_hoi       boolean not null default true,
  tam_dung          boolean not null default false,
  thong_bao         text,
  cap_nhat_luc      timestamptz not null default now()
);
alter table public.cau_hinh add column if not exists so_lan_toi_da int not null default 2;
alter table public.cau_hinh drop column if exists cho_thi_lai;
alter table public.cau_hinh add column if not exists tai_lieu jsonb not null default '[]'::jsonb;   -- danh mục tài liệu
alter table public.cau_hinh add column if not exists phien_du_lieu int not null default 0;        -- đánh dấu đã nâng cấp dữ liệu
alter table public.cau_hinh add column if not exists cong_khai_ca_nhan boolean not null default true; -- công khai danh sách cá nhân trên bảng xếp hạng
do $$ begin
  alter table public.cau_hinh add constraint cau_hinh_so_lan_chk check (so_lan_toi_da between 1 and 10);
exception when duplicate_object then null; end $$;

create table if not exists public.dang_bo (
  id serial primary key, ten text not null, nhom text not null default 'Đảng ủy các xã, phường',
  thu_tu int not null default 0, hoat_dong boolean not null default true
);

create table if not exists public.cau_hoi (
  id serial primary key, thu_tu int not null default 0, chuyen_de text, noi_dung text not null,
  a text not null, b text not null, c text, d text,
  dap_an char(1) not null check (dap_an in ('A','B','C','D')),
  hoat_dong boolean not null default true, ghi_chu text, cap_nhat_luc timestamptz not null default now()
);

-- Mỗi bộ câu hỏi (thứ tự cố định) là một "đề"; bài thi chỉ lưu số hiệu đề
create table if not exists public.de_thi (
  id   serial primary key,
  ds   int[] not null unique,
  tao_luc timestamptz not null default now()
);

-- Mỗi người MỘT dòng (riêng chính thức / thử nghiệm). Giữ kết quả cao nhất.
create table if not exists public.nguoi_thi (
  thu_nghiem      boolean not null,
  khoa            uuid    not null,          -- băm của họ tên + đảng bộ + đơn vị (đã chuẩn hóa)
  ho_ten          text not null,
  chuc_vu         text not null,
  don_vi          text not null,
  dang_bo_id      int  not null references public.dang_bo(id),
  lanh_dao        boolean not null,
  tim             text not null,             -- chữ thường không dấu để tìm kiếm
  so_lan_bat_dau  smallint not null default 0,
  so_lan          smallint not null default 0,   -- số lần đã nộp
  bai_tot_nhat    uuid,
  so_cau_dung     smallint,
  tong_so_cau     smallint,
  dat             boolean,
  nop_luc         timestamptz,
  thoi_gian_giay  int,
  primary key (thu_nghiem, khoa)
);
create index if not exists nguoi_thi_db_idx on public.nguoi_thi (thu_nghiem, dang_bo_id);

-- Từng lượt làm bài (gọn nhẹ: đáp án là chuỗi ký tự theo thứ tự đề)
create table if not exists public.bai_thi (
  id             uuid primary key default gen_random_uuid(),
  thu_nghiem     boolean not null,
  khoa           uuid not null,
  dang_bo_id     int  not null,
  de_id          int  not null references public.de_thi(id),
  bat_dau        timestamptz not null default now(),
  nop_luc        timestamptz,
  tra_loi        text,            -- VD 'ACB-A…' ; '-' = bỏ trống
  so_cau_dung    smallint,
  tong_so_cau    smallint not null,
  dat            boolean,
  thoi_gian_giay int,
  qua_gio        boolean not null default false
);
create index if not exists bai_thi_khoa_idx    on public.bai_thi (thu_nghiem, khoa);
create index if not exists bai_thi_db_idx      on public.bai_thi (dang_bo_id);
create index if not exists bai_thi_dang_lam_idx on public.bai_thi (bat_dau) where nop_luc is null;

create table if not exists public.quan_tri (email text primary key);

-- Bộ nhớ đệm bảng xếp hạng (tính lại tối đa 2 phút/lần, tránh tải khi đông người xem)
create table if not exists public.bxh_cache (
  thu_nghiem boolean primary key,
  du_lieu    jsonb not null,
  cap_nhat   timestamptz not null default now()
);

-- Bộ đếm lượt truy cập (chia 64 ngăn để nhiều người cùng ghi không phải chờ nhau)
create table if not exists public.luot_truy_cap (
  ngan smallint primary key,
  so   bigint not null default 0
);
insert into public.luot_truy_cap (ngan) select g from generate_series(0, 63) g on conflict do nothing;

-- ---------- 2. BẢO MẬT ----------
alter table public.cau_hinh  enable row level security;
alter table public.dang_bo   enable row level security;
alter table public.cau_hoi   enable row level security;
alter table public.de_thi    enable row level security;
alter table public.nguoi_thi enable row level security;
alter table public.bai_thi   enable row level security;
alter table public.quan_tri  enable row level security;
alter table public.bxh_cache enable row level security;
alter table public.luot_truy_cap enable row level security;
revoke all on public.cau_hinh, public.dang_bo, public.cau_hoi, public.de_thi, public.nguoi_thi, public.bai_thi, public.quan_tri, public.bxh_cache, public.luot_truy_cap from anon;

create or replace function public.la_quan_tri()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.quan_tri where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

do $$
declare t text;
begin
  foreach t in array array['cau_hinh','dang_bo','cau_hoi','de_thi','nguoi_thi','bai_thi'] loop
    execute format('drop policy if exists qt_toan_quyen on public.%I', t);
    execute format('create policy qt_toan_quyen on public.%I for all to authenticated using (public.la_quan_tri()) with check (public.la_quan_tri())', t);
  end loop;
  drop policy if exists qt_xem on public.quan_tri;
  create policy qt_xem on public.quan_tri for select to authenticated using (public.la_quan_tri());
end $$;
grant select, insert, update, delete on public.cau_hinh, public.dang_bo, public.cau_hoi to authenticated;
grant select on public.de_thi, public.nguoi_thi, public.bai_thi, public.quan_tri to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ---------- 3. HÀM DÙNG CHUNG ----------
create or replace function public.chuan_hoa(p text)
returns text language sql immutable as $$
  select lower(regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g'));
$$;

-- Bỏ dấu tiếng Việt để tìm kiếm không dấu
create or replace function public.bo_dau(p text)
returns text language sql immutable as $$
  select translate(public.chuan_hoa(p), 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ', 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd');
$$;

create or replace function public.trang_thai_dot()
returns text language sql stable security definer set search_path = public as $$
  select case
    when c.tam_dung then 'tam_dung'
    when c.dong_luc is not null and now() >= c.dong_luc then 'da_ket_thuc'
    when c.mo_tu is not null and now() >= c.mo_tu then 'dang_mo'
    when c.thu_nghiem_tu is not null and now() >= c.thu_nghiem_tu then 'thu_nghiem'
    else 'chua_mo' end
  from public.cau_hinh c where c.id = 1;
$$;

-- Chuỗi đáp án đúng của một đề theo đáp án HIỆN TẠI ('?' nếu câu đã bị xóa)
create or replace function public.khoa_dap_an(p_de int)
returns text language sql stable security definer set search_path = public as $$
  select string_agg(coalesce(q.dap_an, '?'), '' order by i)
  from public.de_thi d
  cross join lateral generate_subscripts(d.ds, 1) i
  left join public.cau_hoi q on q.id = d.ds[i]
  where d.id = p_de;
$$;

create or replace function public.dem_dung(p_tra_loi text, p_khoa text)
returns int language sql immutable as $$
  select count(*)::int from generate_series(1, length(coalesce(p_khoa,''))) i
  where substr(p_tra_loi, i, 1) = substr(p_khoa, i, 1);
$$;

-- Tính lại kết quả tốt nhất + số lần của một người
create or replace function public.tinh_lai_nguoi(p_tn boolean, p_khoa uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare b public.bai_thi; n int;
begin
  select count(*) into n from public.bai_thi where thu_nghiem = p_tn and khoa = p_khoa and nop_luc is not null;
  select * into b from public.bai_thi where thu_nghiem = p_tn and khoa = p_khoa and nop_luc is not null
    order by so_cau_dung desc, nop_luc asc limit 1;
  if n = 0 and not exists (select 1 from public.bai_thi where thu_nghiem = p_tn and khoa = p_khoa) then
    delete from public.nguoi_thi where thu_nghiem = p_tn and khoa = p_khoa; return;
  end if;
  update public.nguoi_thi set so_lan = n, bai_tot_nhat = b.id, so_cau_dung = b.so_cau_dung, tong_so_cau = b.tong_so_cau,
    dat = b.dat, nop_luc = b.nop_luc, thoi_gian_giay = b.thoi_gian_giay
  where thu_nghiem = p_tn and khoa = p_khoa;
end;
$$;
revoke execute on function public.tinh_lai_nguoi(boolean, uuid) from public, anon;

-- ---------- 4. HÀM CHO NGƯỜI THI ----------

create or replace function public.thong_tin_dot()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ten_dot', c.ten_dot, 'don_vi_to_chuc', c.don_vi_to_chuc,
    'thoi_gian_lam_bai', c.thoi_gian_lam_bai, 'ty_le_dat', c.ty_le_dat,
    'so_lan_toi_da', c.so_lan_toi_da,
    'so_cau', (select count(*) from public.cau_hoi where hoat_dong),
    'thu_nghiem_tu', c.thu_nghiem_tu, 'mo_tu', c.mo_tu, 'dong_luc', c.dong_luc,
    'thong_bao', c.thong_bao, 'trang_thai', public.trang_thai_dot(), 'bay_gio', now(),
    'tai_lieu', c.tai_lieu, 'cong_khai_ca_nhan', c.cong_khai_ca_nhan,
    'dang_bo', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'ten', d.ten, 'nhom', d.nhom) order by d.thu_tu, d.id)
                         from public.dang_bo d where d.hoat_dong), '[]'::jsonb))
  from public.cau_hinh c where c.id = 1;
$$;

create or replace function public.bat_dau_thi(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  c      public.cau_hinh;
  tt     text := public.trang_thai_dot();
  v_tn   boolean;
  v_ten  text := btrim(regexp_replace(coalesce(p->>'ho_ten',''),  '\s+', ' ', 'g'));
  v_cv   text := btrim(regexp_replace(coalesce(p->>'chuc_vu',''), '\s+', ' ', 'g'));
  v_dv   text := btrim(regexp_replace(coalesce(p->>'don_vi',''),  '\s+', ' ', 'g'));
  v_db   int;  v_ld boolean;  v_khoa uuid;  v_ds int[];  v_de int;  v_id uuid;  v_bd timestamptz;
  v_cu   public.nguoi_thi;
begin
  select * into c from public.cau_hinh where id = 1;
  if tt = 'tam_dung'    then raise exception 'TAM_DUNG: Đợt đánh giá đang tạm dừng. Đề nghị đồng chí quay lại sau.'; end if;
  if tt = 'chua_mo'     then raise exception 'CHUA_MO: Đợt đánh giá chưa bắt đầu.'; end if;
  if tt = 'da_ket_thuc' then raise exception 'DA_KET_THUC: Đợt đánh giá đã kết thúc.'; end if;
  v_tn := tt = 'thu_nghiem';

  begin v_db := (p->>'dang_bo_id')::int; exception when others then v_db := null; end;
  v_ld := case p->>'lanh_dao' when 'true' then true when 'false' then false else null end;
  if length(v_ten) < 4 or length(v_ten) > 100 then raise exception 'DU_LIEU: Họ và tên không hợp lệ.'; end if;
  if length(v_cv)  < 2 or length(v_cv)  > 200 then raise exception 'DU_LIEU: Chức vụ không hợp lệ.'; end if;
  if length(v_dv)  < 2 or length(v_dv)  > 200 then raise exception 'DU_LIEU: Đơn vị công tác không hợp lệ.'; end if;
  if v_ld is null then raise exception 'DU_LIEU: Chưa chọn có giữ chức vụ lãnh đạo, quản lý hay không.'; end if;
  if v_db is null or not exists (select 1 from public.dang_bo where id = v_db and hoat_dong)
    then raise exception 'DU_LIEU: Chưa chọn đảng bộ.'; end if;

  v_khoa := md5(public.chuan_hoa(v_ten) || '|' || v_db || '|' || public.chuan_hoa(v_dv))::uuid;

  select * into v_cu from public.nguoi_thi where thu_nghiem = v_tn and khoa = v_khoa;
  if found and v_cu.so_lan >= c.so_lan_toi_da then
    raise exception 'DA_THI: Đồng chí đã làm bài % lần (số lần tối đa). Kết quả cao nhất: %/% câu đúng — %.',
      v_cu.so_lan, v_cu.so_cau_dung, v_cu.tong_so_cau, case when v_cu.dat then 'Đạt yêu cầu' else 'Chưa đạt yêu cầu' end;
  end if;

  select array_agg(id order by thu_tu, id) into v_ds from public.cau_hoi where hoat_dong;
  if v_ds is null then raise exception 'CHUA_CO_DE: Chưa có câu hỏi.'; end if;
  select id into v_de from public.de_thi where ds = v_ds;
  if v_de is null then
    insert into public.de_thi (ds) values (v_ds) on conflict (ds) do nothing returning id into v_de;
    if v_de is null then select id into v_de from public.de_thi where ds = v_ds; end if;
  end if;

  insert into public.nguoi_thi (thu_nghiem, khoa, ho_ten, chuc_vu, don_vi, dang_bo_id, lanh_dao, tim, so_lan_bat_dau)
  values (v_tn, v_khoa, v_ten, v_cv, v_dv, v_db, v_ld, public.bo_dau(v_ten || ' ' || v_cv || ' ' || v_dv), 1)
  on conflict (thu_nghiem, khoa) do update set
    ho_ten = excluded.ho_ten, chuc_vu = excluded.chuc_vu, don_vi = excluded.don_vi, lanh_dao = excluded.lanh_dao,
    tim = excluded.tim, so_lan_bat_dau = public.nguoi_thi.so_lan_bat_dau + 1;

  insert into public.bai_thi (thu_nghiem, khoa, dang_bo_id, de_id, tong_so_cau)
  values (v_tn, v_khoa, v_db, v_de, cardinality(v_ds))
  returning id, bat_dau into v_id, v_bd;

  return jsonb_build_object(
    'id', v_id, 'bat_dau', v_bd, 'bay_gio', now(),
    'thoi_gian_giay', c.thoi_gian_lam_bai * 60, 'dao_cau_hoi', c.dao_cau_hoi, 'thu_nghiem', v_tn,
    'lan_thu', coalesce(v_cu.so_lan, 0) + 1, 'so_lan_toi_da', c.so_lan_toi_da,
    'cau_hoi', (select jsonb_agg(jsonb_build_object('id', q.id, 'chuyen_de', q.chuyen_de, 'noi_dung', q.noi_dung,
                                                   'a', q.a, 'b', q.b, 'c', q.c, 'd', q.d) order by q.thu_tu, q.id)
                from public.cau_hoi q where q.id = any(v_ds)));
end;
$$;

-- Nộp bài: p_tra_loi = {"<id câu hỏi>": "A", ...}. Gọi lại nhiều lần vẫn an toàn.
create or replace function public.nop_bai(p_id uuid, p_tra_loi jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  b public.bai_thi; c public.cau_hinh; n public.nguoi_thi;
  v_ds int[]; v_tl text; v_dung int; v_giay int;
begin
  select * into c from public.cau_hinh where id = 1;
  select * into b from public.bai_thi where id = p_id for update;
  if not found then raise exception 'KHONG_THAY: Không tìm thấy bài làm.'; end if;

  if b.nop_luc is null then
    select * into n from public.nguoi_thi where thu_nghiem = b.thu_nghiem and khoa = b.khoa for update;
    if n.so_lan >= c.so_lan_toi_da then
      raise exception 'DA_THI: Đồng chí đã nộp bài % lần (số lần tối đa). Kết quả cao nhất: %/% câu đúng.', n.so_lan, n.so_cau_dung, n.tong_so_cau;
    end if;
    select ds into v_ds from public.de_thi where id = b.de_id;
    select string_agg(case when upper(coalesce(p_tra_loi ->> v_ds[i]::text, '')) in ('A','B','C','D')
                           then upper(p_tra_loi ->> v_ds[i]::text) else '-' end, '' order by i)
      into v_tl from generate_subscripts(v_ds, 1) i;
    v_dung := public.dem_dung(v_tl, public.khoa_dap_an(b.de_id));
    v_giay := extract(epoch from now() - b.bat_dau)::int;

    update public.bai_thi set nop_luc = now(), tra_loi = v_tl, so_cau_dung = v_dung,
      dat = v_dung * 100 >= c.ty_le_dat * b.tong_so_cau, thoi_gian_giay = v_giay,
      qua_gio = v_giay > c.thoi_gian_lam_bai * 60 + 300
    where id = p_id returning * into b;

    update public.nguoi_thi n2 set
      so_lan = n2.so_lan + 1,
      bai_tot_nhat   = case when n2.so_cau_dung is null or b.so_cau_dung > n2.so_cau_dung then b.id else n2.bai_tot_nhat end,
      tong_so_cau    = case when n2.so_cau_dung is null or b.so_cau_dung > n2.so_cau_dung then b.tong_so_cau else n2.tong_so_cau end,
      dat            = case when n2.so_cau_dung is null or b.so_cau_dung > n2.so_cau_dung then b.dat else n2.dat end,
      nop_luc        = case when n2.so_cau_dung is null or b.so_cau_dung > n2.so_cau_dung then b.nop_luc else n2.nop_luc end,
      thoi_gian_giay = case when n2.so_cau_dung is null or b.so_cau_dung > n2.so_cau_dung then b.thoi_gian_giay else n2.thoi_gian_giay end,
      so_cau_dung    = greatest(coalesce(n2.so_cau_dung, -1), b.so_cau_dung)
    where n2.thu_nghiem = b.thu_nghiem and n2.khoa = b.khoa;
  end if;

  select * into n from public.nguoi_thi where thu_nghiem = b.thu_nghiem and khoa = b.khoa;
  return jsonb_build_object(
    'so_cau_dung', b.so_cau_dung, 'tong_so_cau', b.tong_so_cau, 'dat', b.dat,
    'ty_le_dat', c.ty_le_dat, 'can_dat', ceil(c.ty_le_dat * b.tong_so_cau / 100.0)::int,
    'ho_ten', n.ho_ten, 'nop_luc', b.nop_luc, 'thu_nghiem', b.thu_nghiem,
    'so_lan', n.so_lan, 'so_lan_toi_da', c.so_lan_toi_da,
    'cao_nhat', n.so_cau_dung, 'dat_cao_nhat', n.dat);
end;
$$;

-- 4.4 Bảng xếp hạng đảng bộ và số liệu thống kê chung (công khai, chỉ số liệu tổng hợp)
--     Xếp theo: số người tham gia ↓, rồi tổng số câu trả lời đúng ↓.
create or replace function public.tinh_bxh(p_tn boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  with s as (
    select d.id, d.ten, d.nhom, d.thu_tu,
           count(n.khoa) tg, coalesce(sum(n.so_cau_dung), 0) dung, count(n.khoa) filter (where n.dat) dat,
           coalesce(sum(n.so_lan), 0) luot, coalesce(sum(n.tong_so_cau), 0) tong_cau
    from public.dang_bo d
    left join public.nguoi_thi n on n.dang_bo_id = d.id and n.thu_nghiem = p_tn and n.so_lan > 0
    where d.hoat_dong
    group by d.id),
  r as (select s.*, case when tg > 0 then rank() over (order by tg desc, dung desc) end hang from s)
  select jsonb_build_object(
    'cap_nhat', now(), 'thu_nghiem', p_tn,
    'tong_nguoi', (select coalesce(sum(tg),0) from s),
    'tong_luot', (select coalesce(sum(luot),0) from s),
    'tong_dat', (select coalesce(sum(dat),0) from s),
    'so_dang_bo_co', (select count(*) from s where tg > 0),
    'luot_truy_cap', (select coalesce(sum(so),0) from public.luot_truy_cap),
    'cong_khai_ca_nhan', (select cong_khai_ca_nhan from public.cau_hinh where id = 1),
    'ds', coalesce((select jsonb_agg(jsonb_build_object('h', hang, 'id', id, 'ten', ten, 'nhom', nhom, 'tg', tg, 'dung', dung, 'dat', dat,
                    'luot', luot, 'tb', case when tg > 0 then round(dung::numeric / tg, 1) end,
                    'tl', case when tg > 0 then round(dat * 100.0 / tg, 1) end)
                    order by hang nulls last, thu_tu, id) from r), '[]'::jsonb));
$$;
revoke execute on function public.tinh_bxh(boolean) from public, anon;

create or replace function public.bang_xep_hang()
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_tn boolean := public.trang_thai_dot() = 'thu_nghiem'; v jsonb; v_luc timestamptz;
begin
  select du_lieu, cap_nhat into v, v_luc from public.bxh_cache where thu_nghiem = v_tn;
  if v is not null and v_luc > now() - interval '2 minutes' then return v; end if;
  -- chỉ một yêu cầu được tính lại; các yêu cầu khác dùng tạm số liệu cũ
  if pg_try_advisory_xact_lock(4612026) then
    v := public.tinh_bxh(v_tn);
    insert into public.bxh_cache (thu_nghiem, du_lieu, cap_nhat) values (v_tn, v, now())
    on conflict (thu_nghiem) do update set du_lieu = excluded.du_lieu, cap_nhat = excluded.cap_nhat;
  elsif v is null then
    v := public.tinh_bxh(v_tn);
  end if;
  return v;
end;
$$;

-- 4.5 Ghi một lượt truy cập (trang gọi một lần cho mỗi phiên trình duyệt)
create or replace function public.ghi_truy_cap()
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_ngan int := floor(random() * 64)::int;   -- chọn ngăn MỘT lần
begin
  update public.luot_truy_cap set so = so + 1 where ngan = v_ngan;
end;
$$;

-- 4.6 Xếp hạng cá nhân trong một đảng bộ (khi bấm vào đảng bộ trên trang Bảng xếp hạng)
--     Xếp theo: số câu đúng (kết quả cao nhất) ↓, rồi thời gian làm bài ↑. Mỗi trang 50 người.
create or replace function public.bxh_ca_nhan(p_dang_bo int, p_tim text default null, p_tu int default 0)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tn boolean := public.trang_thai_dot() = 'thu_nghiem'; v_tim text := nullif(public.bo_dau(p_tim), ''); v jsonb;
begin
  if not (select cong_khai_ca_nhan from public.cau_hinh where id = 1) then
    raise exception 'KHONG_CONG_KHAI: Danh sách cá nhân chưa được công khai.';
  end if;
  with r as (
    select n.ho_ten, n.chuc_vu, n.don_vi, n.so_cau_dung, n.tong_so_cau, n.dat, n.so_lan, n.thoi_gian_giay, n.tim,
           rank() over (order by n.so_cau_dung desc, n.thoi_gian_giay asc nulls last) h
    from public.nguoi_thi n
    where n.thu_nghiem = v_tn and n.dang_bo_id = p_dang_bo and n.so_lan > 0),
  loc as (select * from r where v_tim is null or r.tim like '%' || v_tim || '%')
  select jsonb_build_object('tong', (select count(*) from loc),
    'ds', coalesce((select jsonb_agg(jsonb_build_object('h', h, 'ten', ho_ten, 'cv', chuc_vu, 'dv', don_vi,
              'dung', so_cau_dung, 'tong', tong_so_cau, 'dat', dat, 'lan', so_lan, 'tg', thoi_gian_giay) order by h, ho_ten)
           from (select * from loc order by h, ho_ten offset greatest(coalesce(p_tu, 0), 0) limit 50) x), '[]'::jsonb))
  into v;
  return v;
end;
$$;

-- ---------- 5. HÀM CHO QUẢN TRỊ ----------
create or replace function public.kiem_tra_quan_tri()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.la_quan_tri() then raise exception 'KHONG_CO_QUYEN: Tài khoản không có quyền quản trị.'; end if;
end;
$$;

-- 5.1 Tổng hợp theo đảng bộ
drop function if exists public.qt_thong_ke(boolean);
create or replace function public.qt_thong_ke(p_thu_nghiem boolean default false)
returns table (dang_bo_id int, ten text, nhom text, thu_tu int,
  tham_gia bigint, tham_gia_ld bigint, dat bigint, dat_ld bigint, khong_dat bigint, khong_dat_ld bigint, so_luot bigint, tong_dung bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.kiem_tra_quan_tri();
  return query
  with s as (
    select n.dang_bo_id db, count(*) tg, count(*) filter (where n.lanh_dao) tg_ld,
           count(*) filter (where n.dat) d, count(*) filter (where n.dat and n.lanh_dao) d_ld,
           count(*) filter (where not n.dat) kd, count(*) filter (where not n.dat and n.lanh_dao) kd_ld,
           sum(n.so_lan) sl, sum(n.so_cau_dung) td
    from public.nguoi_thi n where n.thu_nghiem = p_thu_nghiem and n.so_lan > 0 group by n.dang_bo_id)
  select d.id, d.ten, d.nhom, d.thu_tu, coalesce(s.tg,0), coalesce(s.tg_ld,0), coalesce(s.d,0), coalesce(s.d_ld,0),
         coalesce(s.kd,0), coalesce(s.kd_ld,0), coalesce(s.sl,0)::bigint, coalesce(s.td,0)::bigint
  from public.dang_bo d left join s on s.db = d.id
  order by d.thu_tu, d.id;
end;
$$;

-- 5.2 Tổng quan
create or replace function public.qt_tong_quan(p_thu_nghiem boolean default false)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  perform public.kiem_tra_quan_tri();
  select jsonb_build_object(
    'so_nguoi',    (select count(*) from public.nguoi_thi where thu_nghiem = p_thu_nghiem and so_lan > 0),
    'so_dat',      (select count(*) from public.nguoi_thi where thu_nghiem = p_thu_nghiem and so_lan > 0 and dat),
    'so_luot_nop', (select coalesce(sum(so_lan),0) from public.nguoi_thi where thu_nghiem = p_thu_nghiem),
    'diem_tb',     (select round(avg(so_cau_dung)::numeric, 2) from public.nguoi_thi where thu_nghiem = p_thu_nghiem and so_lan > 0),
    'dang_lam',    (select count(*) from public.bai_thi where nop_luc is null and thu_nghiem = p_thu_nghiem and bat_dau > now() - interval '1 hour'),
    'bo_do',       (select count(*) from public.bai_thi where nop_luc is null and thu_nghiem = p_thu_nghiem and bat_dau <= now() - interval '1 hour'),
    'so_thu_nghiem', (select count(*) from public.bai_thi where thu_nghiem),
    'theo_ngay',   coalesce((select jsonb_agg(jsonb_build_object('ngay', s.ngay, 'so_luot', s.n) order by s.ngay) from (
                     select to_char(nop_luc at time zone 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') ngay, count(*) n
                     from public.bai_thi where nop_luc is not null and thu_nghiem = p_thu_nghiem group by 1) s), '[]'::jsonb),
    'trang_thai',  public.trang_thai_dot(), 'bay_gio', now()) into r;
  return r;
end;
$$;

-- 5.3 Số người chọn từng phương án của từng câu (kết quả tốt nhất mỗi người), theo 1 đảng bộ
create or replace function public.qt_thong_ke_cau_hoi(p_thu_nghiem boolean, p_dang_bo int)
returns table (cau_hoi_id int, so_a bigint, so_b bigint, so_c bigint, so_d bigint, bo_trong bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.kiem_tra_quan_tri();
  return query
  select d.ds[i], count(*) filter (where substr(b.tra_loi, i, 1) = 'A'), count(*) filter (where substr(b.tra_loi, i, 1) = 'B'),
         count(*) filter (where substr(b.tra_loi, i, 1) = 'C'), count(*) filter (where substr(b.tra_loi, i, 1) = 'D'),
         count(*) filter (where substr(b.tra_loi, i, 1) = '-')
  from public.nguoi_thi n
  join public.bai_thi b on b.id = n.bai_tot_nhat
  join public.de_thi d on d.id = b.de_id
  cross join lateral generate_subscripts(d.ds, 1) i
  where n.thu_nghiem = p_thu_nghiem and n.dang_bo_id = p_dang_bo and n.so_lan > 0
  group by d.ds[i];
end;
$$;

-- 5.4 Danh sách (mỗi người 1 dòng, hoặc mọi lượt thi)
create or replace function public.qt_danh_sach(
  p_thu_nghiem boolean default false, p_tim text default null, p_dang_bo int default null,
  p_ket_qua text default null, p_lanh_dao boolean default null, p_tat_ca_luot boolean default false,
  p_tu int default 0, p_so int default 50)
returns table (id uuid, khoa uuid, ho_ten text, chuc_vu text, don_vi text, dang_bo_id int, dang_bo text, lanh_dao boolean,
  so_cau_dung int, tong_so_cau int, dat boolean, bat_dau timestamptz, nop_luc timestamptz, thoi_gian_giay int,
  qua_gio boolean, so_lan int, tong bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_tim text := nullif(public.bo_dau(p_tim), '');
begin
  perform public.kiem_tra_quan_tri();
  if not p_tat_ca_luot then
    return query
    select n.bai_tot_nhat, n.khoa, n.ho_ten, n.chuc_vu, n.don_vi, n.dang_bo_id, d.ten, n.lanh_dao, n.so_cau_dung::int, n.tong_so_cau::int,
           n.dat, null::timestamptz, n.nop_luc, n.thoi_gian_giay, false, n.so_lan::int, count(*) over ()
    from public.nguoi_thi n join public.dang_bo d on d.id = n.dang_bo_id
    where n.thu_nghiem = p_thu_nghiem and n.so_lan > 0
      and (v_tim is null or n.tim like '%' || v_tim || '%')
      and (p_dang_bo is null or n.dang_bo_id = p_dang_bo)
      and (p_lanh_dao is null or n.lanh_dao = p_lanh_dao)
      and (p_ket_qua is null or (p_ket_qua = 'dat' and n.dat) or (p_ket_qua = 'khong_dat' and not n.dat))
    order by d.thu_tu, n.dang_bo_id, n.ho_ten, n.khoa
    offset greatest(p_tu, 0) limit least(greatest(p_so, 1), 1000);
  else
    return query
    select b.id, b.khoa, n.ho_ten, n.chuc_vu, n.don_vi, n.dang_bo_id, d.ten, n.lanh_dao, b.so_cau_dung::int, b.tong_so_cau::int,
           b.dat, b.bat_dau, b.nop_luc, b.thoi_gian_giay, b.qua_gio, n.so_lan::int, count(*) over ()
    from public.bai_thi b
    join public.nguoi_thi n on n.thu_nghiem = b.thu_nghiem and n.khoa = b.khoa
    join public.dang_bo d on d.id = n.dang_bo_id
    where b.thu_nghiem = p_thu_nghiem
      and (v_tim is null or n.tim like '%' || v_tim || '%')
      and (p_dang_bo is null or b.dang_bo_id = p_dang_bo)
      and (p_lanh_dao is null or n.lanh_dao = p_lanh_dao)
      and (p_ket_qua is null or (p_ket_qua = 'dat' and b.dat) or (p_ket_qua = 'khong_dat' and b.dat = false))
    order by d.thu_tu, n.dang_bo_id, n.ho_ten, n.khoa, b.bat_dau
    offset greatest(p_tu, 0) limit least(greatest(p_so, 1), 1000);
  end if;
end;
$$;

-- 5.5 Chấm lại theo từng đảng bộ (trang quản trị gọi lần lượt 130 đảng bộ;
--     đảng bộ đông người thì chia 16 phần, p_phan = 0..15)
drop function if exists public.qt_cham_lai(int);
create or replace function public.qt_cham_lai(p_dang_bo int, p_phan int default null)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int; v_tl int;
begin
  perform public.kiem_tra_quan_tri();
  select ty_le_dat into v_tl from public.cau_hinh where id = 1;
  with k as (select d.id, public.khoa_dap_an(d.id) kh from public.de_thi d),
  m as (select b.id, public.dem_dung(b.tra_loi, k.kh) dung
        from public.bai_thi b join k on k.id = b.de_id
        where b.dang_bo_id = p_dang_bo and b.nop_luc is not null
          and (p_phan is null or get_byte(uuid_send(b.khoa), 0) % 16 = p_phan))
  update public.bai_thi b set so_cau_dung = m.dung, dat = m.dung * 100 >= v_tl * b.tong_so_cau
  from m where m.id = b.id
    and (b.so_cau_dung is distinct from m.dung or b.dat is distinct from (m.dung * 100 >= v_tl * b.tong_so_cau));
  get diagnostics n = row_count;
  -- cập nhật kết quả tốt nhất của từng người trong đảng bộ
  update public.nguoi_thi nt set bai_tot_nhat = t.id, so_cau_dung = t.so_cau_dung, tong_so_cau = t.tong_so_cau,
         dat = t.dat, nop_luc = t.nop_luc, thoi_gian_giay = t.thoi_gian_giay
  from (select distinct on (b.thu_nghiem, b.khoa) b.* from public.bai_thi b
        where b.dang_bo_id = p_dang_bo and b.nop_luc is not null
          and (p_phan is null or get_byte(uuid_send(b.khoa), 0) % 16 = p_phan)
        order by b.thu_nghiem, b.khoa, b.so_cau_dung desc, b.nop_luc asc) t
  where nt.thu_nghiem = t.thu_nghiem and nt.khoa = t.khoa
    and (nt.bai_tot_nhat is distinct from t.id or nt.so_cau_dung is distinct from t.so_cau_dung or nt.dat is distinct from t.dat);
  return n;
end;
$$;

-- 5.6 Xóa dữ liệu thử nghiệm (mỗi lần tối đa 20.000 bài; trả về số bài thử còn lại)
create or replace function public.qt_xoa_thu_nghiem()
returns int language plpgsql volatile security definer set search_path = public as $$
declare con int;
begin
  perform public.kiem_tra_quan_tri();
  delete from public.bai_thi where id in (select id from public.bai_thi where thu_nghiem limit 20000);
  select count(*) into con from public.bai_thi where thu_nghiem;
  if con = 0 then
    delete from public.nguoi_thi where thu_nghiem;
    update public.luot_truy_cap set so = 0;   -- đếm lại lượt truy cập từ đầu cho đợt chính thức
    delete from public.bxh_cache;
  end if;
  return con;
end;
$$;

-- 5.7 Xóa một lượt thi / một người
create or replace function public.qt_xoa_bai(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare b public.bai_thi;
begin
  perform public.kiem_tra_quan_tri();
  delete from public.bai_thi where id = p_id returning * into b;
  if found then perform public.tinh_lai_nguoi(b.thu_nghiem, b.khoa); end if;
end;
$$;
create or replace function public.qt_xoa_nguoi(p_thu_nghiem boolean, p_khoa uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public.kiem_tra_quan_tri();
  delete from public.bai_thi where thu_nghiem = p_thu_nghiem and khoa = p_khoa;
  delete from public.nguoi_thi where thu_nghiem = p_thu_nghiem and khoa = p_khoa;
end;
$$;

-- Quyền gọi hàm
revoke execute on all functions in schema public from anon, public;
grant execute on function public.thong_tin_dot(), public.bat_dau_thi(jsonb), public.nop_bai(uuid, jsonb), public.bang_xep_hang(),
  public.ghi_truy_cap(), public.bxh_ca_nhan(int, text, int) to anon, authenticated;
grant execute on function public.la_quan_tri(), public.qt_thong_ke(boolean), public.qt_tong_quan(boolean),
  public.qt_thong_ke_cau_hoi(boolean, int), public.qt_cham_lai(int, int), public.qt_xoa_thu_nghiem(),
  public.qt_xoa_bai(uuid), public.qt_xoa_nguoi(boolean, uuid),
  public.qt_danh_sach(boolean, text, int, text, boolean, boolean, int, int) to authenticated;

-- ---------- 6. DỮ LIỆU BAN ĐẦU ----------
insert into public.cau_hinh (id, thu_nghiem_tu, mo_tu, dong_luc)
values (1, '2026-11-04 08:00:00+07', '2026-11-05 08:00:00+07', '2026-11-15 17:00:00+07')
on conflict (id) do nothing;

insert into public.quan_tri (email) values ('ngacvantuan.hg@gmail.com') on conflict do nothing;

-- 130 đảng bộ trực thuộc Tỉnh ủy (theo biểu gửi kèm)
insert into public.dang_bo (ten, nhom, thu_tu)
select * from (values
('Đảng ủy các cơ quan Đảng tỉnh', 'Đảng ủy trực thuộc Tỉnh ủy', 1),
('Đảng uỷ Uỷ ban nhân dân tỉnh', 'Đảng ủy trực thuộc Tỉnh ủy', 2),
('Đảng ủy Công an tỉnh', 'Đảng ủy trực thuộc Tỉnh ủy', 3),
('Đảng ủy Mặt trận Tổ quốc, các đoàn thể', 'Đảng ủy trực thuộc Tỉnh ủy', 4),
('Đảng ủy Quân sự tỉnh', 'Đảng ủy trực thuộc Tỉnh ủy', 5),
('Đảng ủy Hội đồng nhân dân tỉnh', 'Đảng ủy trực thuộc Tỉnh ủy', 6),
('Phường Minh Xuân', 'Đảng ủy các xã, phường', 7),
('Phường Mỹ Lâm', 'Đảng ủy các xã, phường', 8),
('Phường Nông Tiến', 'Đảng ủy các xã, phường', 9),
('Phường An Tường', 'Đảng ủy các xã, phường', 10),
('Phường Bình Thuận', 'Đảng ủy các xã, phường', 11),
('Phường Hà Giang 2', 'Đảng ủy các xã, phường', 12),
('Phường Hà Giang 1', 'Đảng ủy các xã, phường', 13),
('Xã Thượng Lâm', 'Đảng ủy các xã, phường', 14),
('Xã Lâm Bình', 'Đảng ủy các xã, phường', 15),
('Xã Minh Quang', 'Đảng ủy các xã, phường', 16),
('Xã Bình An', 'Đảng ủy các xã, phường', 17),
('Xã Côn Lôn', 'Đảng ủy các xã, phường', 18),
('Xã Yên Hoa', 'Đảng ủy các xã, phường', 19),
('Xã Thượng Nông', 'Đảng ủy các xã, phường', 20),
('Xã Hồng Thái', 'Đảng ủy các xã, phường', 21),
('Xã Nà Hang', 'Đảng ủy các xã, phường', 22),
('Xã Tân Mỹ', 'Đảng ủy các xã, phường', 23),
('Xã Yên Lập', 'Đảng ủy các xã, phường', 24),
('Xã Tân An', 'Đảng ủy các xã, phường', 25),
('Xã Chiêm Hóa', 'Đảng ủy các xã, phường', 26),
('Xã Hòa An', 'Đảng ủy các xã, phường', 27),
('Xã Kiên Đài', 'Đảng ủy các xã, phường', 28),
('Xã Tri Phú', 'Đảng ủy các xã, phường', 29),
('Xã Kim Bình', 'Đảng ủy các xã, phường', 30),
('Xã Yên Nguyên', 'Đảng ủy các xã, phường', 31),
('Xã Trung Hà', 'Đảng ủy các xã, phường', 32),
('Xã Yên Phú', 'Đảng ủy các xã, phường', 33),
('Xã Bạch Xa', 'Đảng ủy các xã, phường', 34),
('Xã Phù Lưu', 'Đảng ủy các xã, phường', 35),
('Xã Hàm Yên', 'Đảng ủy các xã, phường', 36),
('Xã Bình Xa', 'Đảng ủy các xã, phường', 37),
('Xã Thái Sơn', 'Đảng ủy các xã, phường', 38),
('Xã Thái Hòa', 'Đảng ủy các xã, phường', 39),
('Xã Hùng Đức', 'Đảng ủy các xã, phường', 40),
('Xã Hùng Lợi', 'Đảng ủy các xã, phường', 41),
('Xã Trung Sơn', 'Đảng ủy các xã, phường', 42),
('Xã Thái Bình', 'Đảng ủy các xã, phường', 43),
('Xã Tân Long', 'Đảng ủy các xã, phường', 44),
('Xã Xuân Vân', 'Đảng ủy các xã, phường', 45),
('Xã Lực Hành', 'Đảng ủy các xã, phường', 46),
('Xã Yên Sơn', 'Đảng ủy các xã, phường', 47),
('Xã Nhữ Khê', 'Đảng ủy các xã, phường', 48),
('Xã Kiến Thiết', 'Đảng ủy các xã, phường', 49),
('Xã Tân Trào', 'Đảng ủy các xã, phường', 50),
('Xã Minh Thanh', 'Đảng ủy các xã, phường', 51),
('Xã Sơn Dương', 'Đảng ủy các xã, phường', 52),
('Xã Bình Ca', 'Đảng ủy các xã, phường', 53),
('Xã Tân Thanh', 'Đảng ủy các xã, phường', 54),
('Xã Sơn Thủy', 'Đảng ủy các xã, phường', 55),
('Xã Phú Lương', 'Đảng ủy các xã, phường', 56),
('Xã Trường Sinh', 'Đảng ủy các xã, phường', 57),
('Xã Hồng Sơn', 'Đảng ủy các xã, phường', 58),
('Xã Đông Thọ', 'Đảng ủy các xã, phường', 59),
('Xã Ngọc Đường', 'Đảng ủy các xã, phường', 60),
('Xã Đồng Văn', 'Đảng ủy các xã, phường', 61),
('Xã Lũng Cú', 'Đảng ủy các xã, phường', 62),
('Xã Sà Phìn', 'Đảng ủy các xã, phường', 63),
('Xã Phố Bảng', 'Đảng ủy các xã, phường', 64),
('Xã Lũng Phìn', 'Đảng ủy các xã, phường', 65),
('Xã Mèo Vạc', 'Đảng ủy các xã, phường', 66),
('Xã Sơn Vĩ', 'Đảng ủy các xã, phường', 67),
('Xã Sủng Máng', 'Đảng ủy các xã, phường', 68),
('Xã Khâu Vai', 'Đảng ủy các xã, phường', 69),
('Xã Niêm Sơn', 'Đảng ủy các xã, phường', 70),
('Xã Tát Ngà', 'Đảng ủy các xã, phường', 71),
('Xã Bạch Đích', 'Đảng ủy các xã, phường', 72),
('Xã Yên Minh', 'Đảng ủy các xã, phường', 73),
('Xã Thắng Mố', 'Đảng ủy các xã, phường', 74),
('Xã Mậu Duệ', 'Đảng ủy các xã, phường', 75),
('Xã Đường Thượng', 'Đảng ủy các xã, phường', 76),
('Xã Du Già', 'Đảng ủy các xã, phường', 77),
('Xã Ngọc Long', 'Đảng ủy các xã, phường', 78),
('Xã Quản Bạ', 'Đảng ủy các xã, phường', 79),
('Xã Tùng Vài', 'Đảng ủy các xã, phường', 80),
('Xã Nghĩa Thuận', 'Đảng ủy các xã, phường', 81),
('Xã Cán Tỷ', 'Đảng ủy các xã, phường', 82),
('Xã Lùng Tám', 'Đảng ủy các xã, phường', 83),
('Xã Hoàng Su Phì', 'Đảng ủy các xã, phường', 84),
('Xã Thàng Tín', 'Đảng ủy các xã, phường', 85),
('Xã Bản Máy', 'Đảng ủy các xã, phường', 86),
('Xã Nậm Dịch', 'Đảng ủy các xã, phường', 87),
('Xã Tân Tiến', 'Đảng ủy các xã, phường', 88),
('Xã Hồ Thầu', 'Đảng ủy các xã, phường', 89),
('Xã Pờ Ly Ngài', 'Đảng ủy các xã, phường', 90),
('Xã Thông Nguyên', 'Đảng ủy các xã, phường', 91),
('Xã Bắc Mê', 'Đảng ủy các xã, phường', 92),
('Xã Minh Ngọc', 'Đảng ủy các xã, phường', 93),
('Xã Đường Hồng', 'Đảng ủy các xã, phường', 94),
('Xã Yên Cường', 'Đảng ủy các xã, phường', 95),
('Xã Minh Sơn', 'Đảng ủy các xã, phường', 96),
('Xã Giáp Trung', 'Đảng ủy các xã, phường', 97),
('Xã Vị Xuyên', 'Đảng ủy các xã, phường', 98),
('Xã Thanh Thủy', 'Đảng ủy các xã, phường', 99),
('Xã Phú Linh', 'Đảng ủy các xã, phường', 100),
('Xã Linh Hồ', 'Đảng ủy các xã, phường', 101),
('Xã Minh Tân', 'Đảng ủy các xã, phường', 102),
('Xã Bạch Ngọc', 'Đảng ủy các xã, phường', 103),
('Xã Thuận Hòa', 'Đảng ủy các xã, phường', 104),
('Xã Lao Chải', 'Đảng ủy các xã, phường', 105),
('Xã Việt Lâm', 'Đảng ủy các xã, phường', 106),
('Xã Tùng Bá', 'Đảng ủy các xã, phường', 107),
('Xã Thượng Sơn', 'Đảng ủy các xã, phường', 108),
('Xã Bắc Quang', 'Đảng ủy các xã, phường', 109),
('Xã Tân Quang', 'Đảng ủy các xã, phường', 110),
('Xã Hùng An', 'Đảng ủy các xã, phường', 111),
('Xã Vĩnh Tuy', 'Đảng ủy các xã, phường', 112),
('Xã Liên Hiệp', 'Đảng ủy các xã, phường', 113),
('Xã Đồng Yên', 'Đảng ủy các xã, phường', 114),
('Xã Bằng Hành', 'Đảng ủy các xã, phường', 115),
('Xã Đồng Tâm', 'Đảng ủy các xã, phường', 116),
('Xã Quang Bình', 'Đảng ủy các xã, phường', 117),
('Xã Tân Trịnh', 'Đảng ủy các xã, phường', 118),
('Xã Cao Bồ', 'Đảng ủy các xã, phường', 119),
('Xã Yên Thành', 'Đảng ủy các xã, phường', 120),
('Xã Bằng Lang', 'Đảng ủy các xã, phường', 121),
('Xã Xuân Giang', 'Đảng ủy các xã, phường', 122),
('Xã Tiên Yên', 'Đảng ủy các xã, phường', 123),
('Xã Tiên Nguyên', 'Đảng ủy các xã, phường', 124),
('Xã Pà Vầy Sủ', 'Đảng ủy các xã, phường', 125),
('Xã Xín Mần', 'Đảng ủy các xã, phường', 126),
('Xã Quảng Nguyên', 'Đảng ủy các xã, phường', 127),
('Xã Trung Thịnh', 'Đảng ủy các xã, phường', 128),
('Xã Nấm Dẩn', 'Đảng ủy các xã, phường', 129),
('Xã Khuôn Lùng', 'Đảng ủy các xã, phường', 130)
) v
where not exists (select 1 from public.dang_bo);

-- ---------- 7. NÂNG CẤP DỮ LIỆU LÊN PHIÊN BẢN 3 (chạy MỘT LẦN) ----------
do $$
begin
  if (select phien_du_lieu from public.cau_hinh where id = 1) < 3 then
    -- xóa bài thi cũ (đều là thử nghiệm) và bộ câu hỏi cũ
    delete from public.bai_thi;
    delete from public.nguoi_thi;
    delete from public.bxh_cache;
    delete from public.de_thi;
    delete from public.cau_hoi;

    insert into public.cau_hoi (thu_tu, chuyen_de, noi_dung, a, b, c, d, dap_an, hoat_dong, ghi_chu) values
  (1, 'Nghị quyết số 31-NQ/TW', 'Đặt trong yêu cầu phát triển đất nước ở kỷ nguyên mới, nhận thức nào phản ánh đầy đủ nhất vị trí và yêu cầu đối với công tác xây dựng, chỉnh đốn Đảng?', 'Đây là nhiệm vụ then chốt, thường xuyên, quyết định thành công của sự nghiệp xây dựng và bảo vệ Tổ quốc trong kỷ nguyên mới.', 'Đây là nhiệm vụ trọng tâm trong giai đoạn kiện toàn tổ chức bộ máy; kết quả chủ yếu thể hiện ở sự hoàn chỉnh về tổ chức, quy chế và đội ngũ.', 'Đây là nhiệm vụ tập trung vào phát hiện, xử lý vi phạm và tăng cường kỷ luật, qua đó củng cố sức chiến đấu và giữ vững sự ổn định của tổ chức đảng.', null, 'A', true, null),
  (2, 'Nghị quyết số 31-NQ/TW', 'Quan hệ giữa “kiên định” và “đổi mới” được thể hiện như thế nào trong tư duy chỉ đạo của Nghị quyết?', 'Kiên định mục tiêu và nguyên tắc là nền tảng; đổi mới chỉ cần đặt ra ở cách tổ chức thực hiện, không nhất thiết phát triển nhận thức và lý luận.', 'Đổi mới phải đi trước để đáp ứng thực tiễn; khi yêu cầu phát triển thay đổi có thể chủ động điều chỉnh các nguyên tắc nền tảng.', 'Kiên định và vận dụng, phát triển sáng tạo chủ nghĩa Mác-Lênin, tư tưởng Hồ Chí Minh, lý luận về đường lối đổi mới, mục tiêu độc lập dân tộc và chủ nghĩa xã hội, các nguyên tắc tổ chức, hoạt động của Đảng. Trên nền tảng đó, không ngừng đổi mới tư duy, phát triển lý luận, tổng kết thực tiễn, nâng cao năng lực dự báo và kiến tạo tầm nhìn dài hạn.', null, 'C', true, null),
  (3, 'Nghị quyết số 31-NQ/TW', 'Điểm cốt lõi nào thể hiện hiệu quả xử lý vi phạm, không để vi phạm tương tự tái diễn?', 'Tiếp tục tăng mức xử lý kỷ luật đối với các trường hợp trực tiếp vi phạm, coi tính nghiêm minh của xử lý là kết quả khắc phục chủ yếu.', 'Chuyển mạnh từ phát hiện, xử lý khi vi phạm sang chủ động nhận diện, cảnh báo, phòng ngừa từ sớm, từ xa, từ gốc; kết hợp xử lý nghiêm vi phạm với loại bỏ nguyên nhân, điều kiện phát sinh và ngăn ngừa tái diễn.', 'Tập trung giáo dục, nhắc nhở và hoàn thiện hồ sơ kiểm điểm; chuyển việc theo dõi các nguy cơ tái diễn sang các kỳ kiểm tra tiếp theo.', null, 'B', true, null),
  (4, 'Nghị quyết số 31-NQ/TW', 'Đâu là điểm nâng tầm cốt lõi của yêu cầu “tự đổi mới, tự chỉnh đốn, tự hoàn thiện” đối với một đảng cầm quyền?', 'Tăng tần suất kiểm điểm, đánh giá và sơ kết để các cấp ủy sớm nhận diện và khắc phục khuyết điểm.', 'Tăng cường sự giám sát từ cơ quan cấp trên và các chủ thể bên ngoài để kịp thời phát hiện sai phạm.', 'Tạo chuyển biến sâu sắc về nhận thức và hành động trong toàn Đảng và hệ thống chính trị về xây dựng, chỉnh đốn Đảng là quy luật phát triển, nhu cầu tự thân, thường xuyên của Đảng.', null, 'C', true, null),
  (5, 'Nghị quyết số 31-NQ/TW', 'Phương án nào thể hiện đúng nhất bước phát triển trong việc xây dựng Đảng “thật sự là đạo đức, là văn minh” theo Nghị quyết?', 'Chuyển các giá trị vì nước, vì dân, cần, kiệm, liêm chính, chí công vô tư, trung thực, nêu gương từ yêu cầu tu dưỡng, rèn luyện thành chuẩn mực bắt buộc trong ứng xử, ra quyết định, sử dụng quyền lực và kỷ luật thực thi công vụ.', 'Đặt trọng tâm vào giáo dục, tự giác tu dưỡng và các phong trào nêu gương; các chuẩn mực về hành vi, quyết định và sử dụng quyền lực sẽ hình thành từ quá trình rèn luyện.', 'Xây dựng hệ thống văn hóa lãnh đạo, văn hóa cầm quyền, văn hóa quản lý và văn hóa liêm chính như bốn thành tố độc lập ngang nhau; đánh giá chủ yếu qua việc tuân thủ quy tắc ứng xử.', null, 'A', true, null),
  (6, 'Nghị quyết số 31-NQ/TW', 'Theo Nghị quyết, khi phân cấp nhiệm vụ cho cấp sát việc, sát dân, phương án nào bảo đảm đồng bộ nhất giữa trao quyền và trách nhiệm?', 'Giao rõ nhiệm vụ, tăng nguồn lực nhưng vẫn yêu cầu cấp dưới xin ý kiến cấp trên trước các quyết định thuộc thẩm quyền để giảm rủi ro.', 'Trao quyền quyết định và yêu cầu cấp dưới tự chịu trách nhiệm; hoạt động kiểm tra, giám sát chủ yếu tiến hành sau khi phát sinh khó khăn, sai phạm.', 'Trao đủ thẩm quyền, nguồn lực và trách nhiệm giải trình; cấp trên tập trung định hướng, tiêu chuẩn, kiểm tra, giám sát, cấp dưới chủ động quyết định và chịu trách nhiệm theo thẩm quyền. Kiểm soát quyền lực xuyên suốt từ giao quyền, thực hiện quyền đến kiểm tra, giám sát.', null, 'C', true, null),
  (7, 'Nghị quyết số 31-NQ/TW', 'Theo quan điểm “Dân là gốc”, đâu là cách hiểu đầy đủ nhất về cơ sở tạo dựng và kiểm chứng uy tín của Đảng?', 'Đề cao sự đồng thuận của Nhân dân trong quá trình góp ý chủ trương, quyết sách; kết quả được đánh giá chủ yếu qua mức độ tham gia và ủng hộ.', 'Xây dựng Đảng phải vì Nhân dân, dựa vào Nhân dân và chịu sự giám sát của Nhân dân. Lấy chất lượng cuộc sống, sự đồng thuận và niềm tin của Nhân dân làm thước đo.', 'Lấy sự hài lòng của Nhân dân làm thước đo; việc góp ý, giám sát và giải quyết kiến nghị trước hết do các cơ quan chuyên trách đảm nhận.', null, 'B', true, null),
  (8, 'Nghị quyết số 31-NQ/TW', 'Việc khuyến khích, bảo vệ cán bộ dám nghĩ, dám làm, dám chịu trách nhiệm vì lợi ích chung phải tuân theo nguyên tắc nào?', 'Phân biệt sai phạm do vụ lợi, cố ý làm trái với rủi ro phát sinh trong đổi mới sáng tạo; việc bảo vệ phải căn cứ động cơ trong sáng, vì lợi ích chung, đúng thẩm quyền và có kiểm soát, không bao che hoặc miễn trừ trách nhiệm.', 'Ưu tiên bảo vệ người có sáng kiến và có động cơ tích cực; chỉ xem xét trách nhiệm khi chứng minh được mục đích vụ lợi.', 'Chỉ bảo vệ các quyết định sáng tạo đã đạt kết quả dự kiến; trường hợp chưa đạt kết quả phải xử lý trách nhiệm như các vi phạm thông thường.', null, 'A', true, null),
  (9, 'Nghị quyết số 31-NQ/TW', 'Khi nhìn lại các nghị quyết Trung ương 4 khóa XI, khóa XII, Kết luận Trung ương 4 khóa XIII và định hướng của nghị quyết Trung ương 4 khóa XIV, cách khái quát nào phản ánh đúng nhất mạch kế thừa và phát triển?', 'Tiếp tục coi kiểm điểm, xem xét, xử lý vi phạm là nội dung bao trùm; nâng hiệu quả xây dựng Đảng chủ yếu bằng tăng cường kỷ luật và chế tài.', 'Yêu cầu xây dựng, chỉnh đốn nghiêm minh, kết hợp ngày càng chặt chẽ “xây” và “chống”; giữa giáo dục, rèn luyện với giữ nghiêm kỷ luật, kỷ cương và kiểm soát quyền lực; chuyển mạnh từ xử lý vi phạm sang chủ động phòng ngừa, cảnh báo từ sớm, từ xa.', 'Chuyển trọng tâm từ xây dựng tổ chức đảng, đảng viên sang đổi mới quản lý nhà nước, coi cải cách hành chính là nội dung thay thế cơ bản cho xây dựng Đảng.', null, 'B', true, null),
  (10, 'Nghị quyết số 31-NQ/TW', 'Từ yêu cầu “cán bộ là nhân tố quyết định”, “công tác cán bộ là then chốt của then chốt”, trách nhiệm của người đứng đầu cần được hiểu thế nào?', 'Chịu trách nhiệm cả về kết quả công tác và chất lượng tổ chức, đội ngũ, đoàn kết nội bộ và khả năng phát huy trí tuệ tập thể.', 'Tập trung chịu trách nhiệm về việc phân công, kiểm tra và hoàn thành nhiệm vụ; chất lượng đội ngũ và nguồn kế cận do cấp có thẩm quyền về công tác cán bộ quyết định.', 'Chịu trách nhiệm về chỉ tiêu của cơ quan, đơn vị; những quyết định đã được tập thể thông qua thì chỉ xem xét trách nhiệm chung của tập thể.', null, 'A', true, null),
  (11, 'Nghị quyết số 31-NQ/TW', 'Một chi bộ sinh hoạt đủ kỳ, có đông đảng viên phát biểu nhưng ít vấn đề được giải quyết và khuyết điểm thường lặp lại. Theo Nghị quyết, tiêu chí nào cần được coi trọng để tạo chuyển biến thực chất?', 'Bảo đảm đủ nội dung, thời lượng, tỉ lệ tham gia và chất lượng biên bản sinh hoạt, coi đó là điều kiện tiên quyết đánh giá chi bộ.', 'Tăng thời gian trao đổi, giáo dục chính trị, tư tưởng để nâng cao đồng thuận; các vấn đề khó tiếp tục nghiên cứu, chưa cần xác định trách nhiệm ngay.', 'Sinh hoạt phải thiết thực, dân chủ, có trọng tâm, bám sát nhiệm vụ chính trị; mọi vấn đề phải được thảo luận và đi đến kết luận, phân công, thời hạn và kiểm tra kết quả.', null, 'C', true, null),
  (12, 'Nghị quyết số 31-NQ/TW', 'Điểm mới cần nhận thức đầy đủ về chế độ trách nhiệm thực chất là gì?', 'Tăng số đợt kiểm tra của cấp trên, tập trung vào các hành vi lạm quyền, vụ lợi và sử dụng sai nguồn lực đã được phát hiện.', 'Phân định rõ trách nhiệm của tập thể, cá nhân, người đứng đầu, cơ quan tham mưu, người đề xuất, người quyết định, người tổ chức thực hiện và người kiểm tra, giám sát, theo nguyên tắc quyền hạn đến đâu, trách nhiệm đến đó.', 'Để hạn chế rủi ro, cấp trên giữ quyền quyết định cuối cùng đối với phần lớn vấn đề mới, khó; cấp dưới tập trung tổ chức thực hiện.', null, 'B', true, null),
  (13, 'Nghị quyết số 29-NQ/TW', 'Theo Nghị quyết, Đảng thực hiện phương thức lãnh đạo chủ yếu bằng những phương thức nào?', 'Bằng hoạt động quản lý hành chính, điều hành trực tiếp và quyết định thay các cơ quan nhà nước.', 'Bằng Cương lĩnh, đường lối, chủ trương, định hướng chiến lược; công tác tư tưởng, tuyên truyền, vận động; công tác tổ chức, cán bộ; kiểm tra, giám sát, kiểm soát quyền lực; vai trò tiên phong, gương mẫu của cán bộ, đảng viên.', 'Chủ yếu bằng việc phân bổ nguồn lực, ban hành pháp luật và trực tiếp tổ chức thực hiện mọi nhiệm vụ phát triển kinh tế - xã hội.', null, 'B', true, null),
  (14, 'Nghị quyết số 29-NQ/TW', 'Quan điểm của Nghị quyết về mối quan hệ giữa quyền lãnh đạo và trách nhiệm chính trị được xác định như thế nào?', 'Quyền lãnh đạo thuộc về tập thể; cá nhân chỉ chịu trách nhiệm chính trị khi có vi phạm pháp luật.', 'Cấp trên chịu trách nhiệm thay cho cấp dưới đối với mọi nhiệm vụ đã phân cấp, phân quyền.', 'Quyền lãnh đạo gắn với trách nhiệm chính trị; thẩm quyền đến đâu, trách nhiệm đến đó.', null, 'C', true, null),
  (15, 'Nghị quyết số 29-NQ/TW', 'Nội dung nào sau đây được Nghị quyết xác định là thước đo hiệu quả lãnh đạo, cầm quyền?', 'Chất lượng quyết sách, kết quả thực hiện, sự phát triển của đất nước và sự hài lòng của Nhân dân.', 'Số lượng văn bản, nghị quyết được ban hành và số cuộc họp được tổ chức trong từng năm.', 'Mức độ phân cấp, phân quyền và số lượng nhiệm vụ được giao cho cấp dưới.', null, 'A', true, null),
  (16, 'Nghị quyết số 29-NQ/TW', 'Mục tiêu tổng quát về đổi mới phương thức lãnh đạo, cầm quyền của Đảng được Nghị quyết xác định theo hướng nào?', 'Tập trung thống nhất mọi hoạt động quản lý, điều hành vào cấp ủy để bảo đảm sự lãnh đạo toàn diện.', 'Khoa học, dân chủ, pháp quyền, hiện đại, vì lợi ích quốc gia - dân tộc và vì Nhân dân.', 'Ưu tiên hoàn thiện tổ chức bộ máy trước, việc đổi mới phương thức lãnh đạo được thực hiện sau khi bộ máy ổn định.', null, 'B', true, null),
  (17, 'Nghị quyết số 29-NQ/TW', 'Việc vận hành thực chất cơ chế “Đảng lãnh đạo, Nhà nước quản lý, Nhân dân làm chủ” đòi hỏi điều gì?', 'Đảng xác định đường lối, định hướng chiến lược, quyết định vấn đề lớn theo thẩm quyền; Nhà nước kịp thời thể chế hóa, quản lý, điều hành, kiến tạo phát triển; Nhân dân thực hiện quyền làm chủ, tham gia xây dựng Đảng, xây dựng Nhà nước, giám sát hoạt động của hệ thống chính trị và thụ hưởng thành quả phát triển.', 'Đảng trực tiếp thực hiện các công việc quản lý, điều hành; Nhà nước chủ yếu làm nhiệm vụ tham mưu và báo cáo.', 'Mặt trận Tổ quốc Việt Nam thay cơ quan nhà nước tổ chức thực hiện chính sách và giải quyết công việc hành chính cho Nhân dân.', null, 'A', true, null),
  (18, 'Nghị quyết số 29-NQ/TW', 'Theo Nghị quyết, mỗi quyết sách phải xác định rõ những nội dung chủ yếu nào?', 'Chủ yếu xác định cơ quan chủ trì và thời điểm báo cáo; các nội dung còn lại được bổ sung trong quá trình thực hiện.', 'Mục tiêu cuối cùng, chủ thể thực hiện, trách nhiệm, nguồn lực, thời hạn, sản phẩm.', 'Chỉ cần xác định mục tiêu và tiến độ; chủ thể thực hiện được lựa chọn sau khi quyết sách được ban hành.', null, 'B', true, null),
  (19, 'Nghị quyết số 29-NQ/TW', 'Nguyên tắc phân cấp, phân quyền được Nghị quyết xác định như thế nào?', 'Phân cấp càng nhiều càng tốt, không cần gắn với điều kiện nguồn lực và cơ chế kiểm soát.', 'Cấp dưới thực hiện nhiệm vụ nhưng phải xin ý kiến cấp trên trước khi quyết định mọi vấn đề đã được phân cấp.', 'Phân cấp, phân quyền phải bảo đảm rõ ràng, thực chất, gắn với trách nhiệm, nguồn lực, hậu kiểm và kiểm soát quyền lực.', null, 'C', true, null),
  (20, 'Nghị quyết số 29-NQ/TW', 'Nghị quyết yêu cầu kiểm soát quyền lực được giao bằng những phương thức nào?', 'Bằng thể chế, quy chế, quy trình, dữ liệu, công khai, minh bạch và trách nhiệm giải trình; kiểm soát cả hành vi lạm quyền, vượt quyền và tình trạng né, không tránh thực hiện đầy đủ thẩm quyền, trách nhiệm.', 'Chủ yếu bằng kiểm tra định kỳ sau khi nhiệm vụ đã kết thúc, hạn chế kiểm tra trong quá trình thực hiện.', 'Tập trung kiểm soát cán bộ cấp dưới, không đặt ra yêu cầu kiểm soát đối với cơ quan tham mưu và người đứng đầu.', null, 'A', true, null),
  (21, 'Nghị quyết số 29-NQ/TW', 'Nghị quyết xác định vai trò của trí tuệ nhân tạo, công nghệ mới trong lãnh đạo, chỉ đạo như thế nào?', 'Có thể thay thế quyết định chính trị khi hệ thống dữ liệu đã đầy đủ và được liên thông.', 'Hỗ trợ tham mưu, phân tích, dự báo, theo dõi tiến độ; không thay thế thẩm quyền, trách nhiệm quyết định của tổ chức, cá nhân.', 'Chỉ sử dụng trong công tác thống kê, lưu trữ; không áp dụng cho kiểm tra, giám sát và cảnh báo sớm.', null, 'B', true, null),
  (22, 'Nghị quyết số 30-NQ/TW', 'Theo Nghị quyết, việc đổi mới nội dung đánh giá cán bộ phải bảo đảm nguyên tắc nào?', 'Phẩm chất chính trị, tư tưởng, đạo đức, liêm chính, kỷ luật.', 'Năng lực thực tiễn, sản phẩm, kết quả, hiệu quả, mức độ cống hiến.', 'Bảo đảm toàn diện, thực chất về phẩm chất chính trị, tư tưởng, đạo đức, liêm chính, kỷ luật; năng lực thực tiễn, sản phẩm, kết quả, hiệu quả, mức độ cống hiến, uy tín trong tổ chức và trước Nhân dân.', null, 'C', true, null),
  (23, 'Nghị quyết số 30-NQ/TW', 'Hai cán bộ cùng nhóm chức danh, cùng được giao một loại nhiệm vụ, nhưng một người công tác ở địa bàn thuận lợi, nguồn lực dồi dào; một người ở địa bàn khó khăn, nguồn lực hạn chế. Theo Nghị quyết, phương thức đánh giá phải:', 'Áp dụng thống nhất một bộ tiêu chí và một thang điểm chung để bảo đảm công bằng, khách quan.', 'Đặt kết quả trong tương quan với thẩm quyền, nguồn lực, điều kiện, hoàn cảnh và độ khó của nhiệm vụ.', 'Lấy mức độ hoàn thành chỉ tiêu đã đăng ký từ đầu năm làm căn cứ chủ yếu.', null, 'B', true, null),
  (24, 'Nghị quyết số 30-NQ/TW', 'Về hoàn thiện đồng bộ chức danh, nhiệm vụ, vị trí việc làm, Nghị quyết yêu cầu phải bảo đảm đồng thời hai mặt nào?', 'Cơ cấu chức danh và tiêu chuẩn cán bộ. Không vì cơ cấu mà hạ thấp tiêu chuẩn; không đặt ra tiêu chuẩn hình thức làm thu hẹp nguồn cán bộ.', 'Không hạ thấp tiêu chuẩn về bằng cấp, đồng thời nâng cao tiêu chuẩn về kinh nghiệm thực tiễn.', 'Bảo đảm tiêu chuẩn chung của Đảng, đồng thời cho phép mỗi cấp ủy quy định thêm tiêu chuẩn riêng phù hợp đặc thù.', null, 'A', true, null),
  (25, 'Nghị quyết số 30-NQ/TW', 'Nghị quyết xác định quan hệ giữa tiêu chuẩn chức danh với năng lực thực tiễn, kết quả thực hiện nhiệm vụ trong việc đánh giá mức độ phù hợp của cán bộ với vị trí như thế nào?', 'Tiêu chuẩn chức danh và năng lực thực tiễn là hai căn cứ ngang nhau, bổ sung cho nhau.', 'Tiêu chuẩn là điều kiện cần; năng lực thực tiễn, kết quả thực hiện nhiệm vụ, khả năng đáp ứng yêu cầu vị trí là căn cứ quan trọng để đánh giá mức độ phù hợp.', 'Năng lực thực tiễn là điều kiện cần; tiêu chuẩn chức danh là căn cứ quyết định khi lựa chọn nhân sự.', null, 'B', true, null),
  (26, 'Nghị quyết số 30-NQ/TW', 'Nghị quyết xác định chỉ tiêu đến năm 2030, việc xây dựng đội ngũ cán bộ cần đạt là gì?', 'Tỷ lệ cán bộ hoàn thành xuất sắc nhiệm vụ và tỷ lệ cán bộ đạt chuẩn chức danh.', 'Mức độ hoàn thành các chỉ tiêu về cơ cấu cán bộ trẻ, cán bộ nữ, cán bộ là người dân tộc thiểu số.', 'Bảo đảm cơ cấu cán bộ hợp lý; tiếp tục nâng tỷ lệ cán bộ trẻ, cán bộ nữ, cán bộ là người dân tộc thiểu số, chuyên gia, nhà khoa học, nhân tài phù hợp với mô hình tổ chức chính quyền địa phương 2 cấp.', null, 'C', true, null),
  (27, 'Nghị quyết số 30-NQ/TW', 'Điểm mới của Nghị quyết về phương thức huy động, sử dụng nhân tài là gì?', 'Xuất phát từ yêu cầu nhiệm vụ, những vấn đề lớn, khó, chiến lược của đất nước; gắn việc sử dụng người tài với nhiệm vụ xứng tầm, thẩm quyền, nguồn lực, sản phẩm và giá trị cống hiến.', 'Cho phép tuyển dụng không qua thi tuyển đối với người có học vị tiến sĩ và chuyên gia đầu ngành.', 'Mở rộng chỉ tiêu biên chế cho các lĩnh vực khoa học, công nghệ, đổi mới sáng tạo và chuyển đổi số.', null, 'A', true, null),
  (28, 'Nghị quyết số 30-NQ/TW', 'Việc bố trí cán bộ phải bảo đảm yêu cầu gì?', 'Căn cứ yêu cầu thực tế để xác định.', 'Bảo đảm cơ cấu hợp lý, năng lực và sở trường, đúng người, đúng việc.', 'Thực hiện theo quy trình và báo cáo cấp có thẩm quyền.', null, 'B', true, null),
  (29, 'Nghị quyết số 30-NQ/TW', 'Nghị quyết yêu cầu phân định rõ hai loại chính sách nào đối với cán bộ?', 'Chính sách tiền lương theo ngạch, bậc với chính sách tiền thưởng theo kết quả công việc.', 'Chính sách đối với cán bộ lãnh đạo, quản lý với chính sách đối với chuyên gia, cán bộ chuyên môn sâu.', 'Chính sách đãi ngộ theo kết quả, cống hiến với chính sách hỗ trợ do điều kiện công tác khó khăn, nguy hiểm, rủi ro.', null, 'C', true, null),
  (30, 'Nghị quyết số 30-NQ/TW', 'Theo Nghị quyết, thước đo chất lượng tham mưu của cơ quan làm công tác tổ chức, cán bộ là gì?', 'Chất lượng đội ngũ và chất lượng quyết định cán bộ.', 'Số lượng và tiến độ các đề án, văn bản được tham mưu ban hành đúng hạn.', 'Mức độ chặt chẽ, chính xác của hồ sơ và quy trình nhân sự do cơ quan thẩm định.', null, 'A', true, null),
  (31, 'Nghị quyết số 30-NQ/TW', 'Sau khi đã phân cấp, phân quyền trong công tác cán bộ, trách nhiệm của cấp trên được Nghị quyết xác định là gì?', 'Thẩm định lại hồ sơ nhân sự trước khi cấp dưới ban hành quyết định.', 'Không làm thay việc đã phân cấp; tập trung kiểm tra, giám sát, hậu kiểm và cảnh báo rủi ro.', 'Cho ý kiến bằng văn bản đối với những trường hợp nhân sự quan trọng thuộc thẩm quyền cấp dưới.', null, 'B', true, null),
  (32, 'Nghị quyết số 30-NQ/TW', 'Đột phá về tạo nguồn của Nghị quyết chuyển công tác quy hoạch cán bộ theo hướng nào?', 'Từ quy hoạch khép kín theo chức danh sang chủ động chuẩn bị đội ngũ cho các nhiệm vụ và năng lực chiến lược của tương lai.', 'Từ quy hoạch theo nhiệm kỳ sang quy hoạch dài hạn 10 năm cho từng chức danh lãnh đạo, quản lý.', 'Từ quy hoạch do tập thể cấp ủy quyết định sang quy hoạch do người đứng đầu giới thiệu và chịu trách nhiệm.', null, 'A', true, null),
  (33, 'Nghị quyết số 30-NQ/TW', 'Chỉ tiêu đến năm 2030 về nguồn kế cận đối với vị trí lãnh đạo, quản lý cấp chiến lược và người đứng đầu các cấp là gì?', '100% vị trí có nguồn quy hoạch với hệ số từ 1,5 đến 2 lần số lượng cấp ủy viên đương nhiệm.', 'Ít nhất 80% vị trí có nguồn kế cận tại chỗ, 20% còn lại chuẩn bị nguồn từ nơi khác điều động đến.', '100% vị trí có nguồn kế cận được chuẩn bị nhiều lớp, có ít nhất 2 phương án gắn với kế hoạch phát hiện, đào tạo, bồi dưỡng, rèn luyện, thử thách và kiểm chứng qua thực tiễn.', null, 'C', true, null),
  (34, 'Quy định số 224-QĐ/TW', 'Nhận định nào dưới đây phản ánh đúng phạm vi điều chỉnh của Quy định số 224-QĐ/TW về đảng viên tham gia hoạt động đầu tư kinh doanh?', 'Chỉ quy định quyền sở hữu tài sản của đảng viên ngoài khu vực công.', 'Chỉ quy định thủ tục kê khai và xin chấp thuận trước khi đảng viên đầu tư kinh doanh.', 'Quy định về chủ trương, nguyên tắc, giới hạn, quyền, trách nhiệm và kiểm soát xung đột lợi ích đối với đảng viên tham gia hoạt động đầu tư kinh doanh.', null, 'C', true, null),
  (35, 'Quy định số 224-QĐ/TW', 'Quy định số 224-QĐ/TW điều chỉnh việc tham gia hoạt động đầu tư kinh doanh đối với nhóm đảng viên nào?', 'Đảng viên trong và ngoài khu vực công, với quyền và giới hạn tương ứng theo chức danh, vị trí, nhiệm vụ.', 'Chỉ đảng viên là viên chức.', 'Chỉ đảng viên ngoài khu vực công.', null, 'A', true, null),
  (36, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, hoạt động đầu tư kinh doanh của đảng viên được phân thành những nhóm nào?', 'Hoạt động chuyên môn và khai thác tài sản tạo thu nhập; đầu tư kinh doanh nhưng không đầu tư thành lập tổ chức kinh tế và không chi phối, quản lý, điều hành.', 'Đầu tư kinh doanh có đầu tư thành lập tổ chức kinh tế hoặc có chi phối nhưng không quản lý, điều hành; đầu tư kinh doanh có tham gia quản lý, điều hành, kể cả trường hợp có đầu tư thành lập tổ chức kinh tế hoặc có chi phối.', 'Cả A và B.', null, 'C', true, null),
  (37, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, nhận định nào phản ánh đầy đủ nguyên tắc áp dụng quyền, giới hạn và kiểm soát xung đột lợi ích?', 'Áp dụng theo chức danh, vị trí công tác, chức trách, nhiệm vụ được giao; đảng viên giữ nhiều chức danh, thực hiện nhiều nhiệm vụ hoặc thuộc nhiều nhóm đối tượng phải tuân thủ giới hạn tương ứng với từng chức danh, nhiệm vụ, nhóm đối tượng.', 'Chỉ áp dụng theo chức danh cao nhất mà đảng viên đang giữ.', 'Chỉ áp dụng theo nơi đảng viên sinh hoạt đảng, không xét nhiệm vụ thực tế.', null, 'A', true, null),
  (38, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, nhận định nào đúng đối với đảng viên ngoài khu vực công khi được giao thực hiện nhiệm vụ công?', 'Phải xin chấp thuận của tổ chức đảng trước mọi khoản đầu tư kinh doanh hợp pháp.', 'Không được lợi dụng tư cách đảng viên, chức vụ trong Đảng hoặc quan hệ với người có thẩm quyền để tạo lợi thế bất bình đẳng, tác động trái quy định, phục vụ lợi ích riêng, lợi ích nhóm; không được xử lý công việc, nhiệm vụ có xung đột lợi ích chưa được kiểm soát hoặc làm ảnh hưởng tiêu cực đến việc thực hiện nhiệm vụ công được giao.', 'Được tự mình tiếp tục xử lý công việc có xung đột lợi ích chưa được kiểm soát.', null, 'B', true, null),
  (39, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, hoạt động nào đảng viên là viên chức được thực hiện mà không phải xin chấp thuận?', 'Hoạt động chuyên môn và khai thác tài sản tạo thu nhập; đầu tư kinh doanh không thành lập tổ chức kinh tế và không chi phối, quản lý, điều hành; nếu không ở vị trí, lĩnh vực có nguy cơ cao phát sinh xung đột lợi ích, được thực hiện hoạt động đầu tư kinh doanh có đầu tư thành lập tổ chức kinh tế hoặc có chi phối nhưng không quản lý, điều hành.', 'Tạm thời rời vị trí công tác để thành lập, chi phối, quản lý, điều hành tổ chức kinh tế mà không cần quyết định của cấp có thẩm quyền.', 'Viên chức không giữ chức vụ quản lý được trực tiếp điều hành tổ chức kinh tế trong khi vẫn làm việc mà không phải xin chấp thuận.', null, 'A', true, null),
  (40, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, đảng viên là cán bộ, công chức không thuộc diện Bộ Chính trị, Ban Bí thư quản lý ở vị trí, lĩnh vực nào thì không được tham gia đầu tư kinh doanh?', 'Ở vị trí, lĩnh vực có nguy cơ cao phát sinh xung đột lợi ích.', 'Không được thực hiện hoạt động chuyên môn và khai thác tài sản tạo thu nhập.', 'Không được thực hiện bất kỳ khoản đầu tư nào mà không tham gia quản lý, điều hành hoặc chi phối.', null, 'A', true, null),
  (41, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, đảng viên là viên chức giữ chức vụ quản lý không được thực hiện hoạt động nào?', 'Hoạt động chuyên môn và khai thác tài sản tạo thu nhập.', 'Đồng thời quản lý, điều hành tổ chức kinh tế, trừ trường hợp được cử tham gia quản lý hoặc làm đại diện phần vốn, tài sản của đơn vị tại tổ chức kinh tế theo quy định của pháp luật.', 'Đầu tư kinh doanh nhưng không thành lập tổ chức kinh tế và không chi phối, quản lý, điều hành.', null, 'B', true, null),
  (42, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, đảng viên là người quản lý doanh nghiệp nhà nước, người đại diện phần vốn nhà nước được làm gì mà không phải xin chấp thuận?', 'Được thực hiện hoạt động chuyên môn và khai thác tài sản tạo thu nhập; đầu tư kinh doanh nhưng không đầu tư thành lập tổ chức kinh tế và không chi phối, quản lý, điều hành; mua, nhận, nắm giữ cổ phần, phần vốn góp và thực hiện quyền cổ đông, thành viên tại doanh nghiệp do mình quản lý hoặc đại diện phần vốn nhà nước theo quy định của pháp luật; việc thực hiện quyền đối với phần vốn cá nhân phải tách bạch với chức trách quản lý, đại diện phần vốn nhà nước và bảo đảm kiểm soát xung đột lợi ích.', 'Được tự mình thành lập và trực tiếp điều hành tổ chức kinh tế ngoài khu vực công trong mọi lĩnh vực.', 'Được đầu tư kinh doanh trong ngành, lĩnh vực có lợi ích liên quan trực tiếp đến doanh nghiệp nhà nước do mình quản lý, không cần điều kiện nào.', null, 'A', true, null),
  (43, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, đảng viên không còn công tác trong khu vực công sau khi thôi công tác, nghỉ hưu không được thực hiện hoạt động nào?', 'Các hoạt động bị hạn chế có liên quan đến lĩnh vực, công việc đã phụ trách trong phạm vi và thời hạn theo quy định của pháp luật.', 'Hoạt động chuyên môn và khai thác tài sản tạo thu nhập hợp pháp.', 'Đầu tư thành lập tổ chức kinh tế trong lĩnh vực không bị hạn chế theo pháp luật.', null, 'A', true, null),
  (44, 'Kết luận số 105-KL/TW', 'Theo Kết luận, nhân tài được nhận thức như thế nào?', 'Là người có phẩm chất, tố chất, năng lực nổi trội và tư duy sáng tạo; có sản phẩm, thành tích hoặc đóng góp đặc biệt, có tính đột phá, tạo ra giá trị và tác động tích cực; có khả năng đảm nhiệm, giải quyết hiệu quả nhiệm vụ quan trọng, mới, khó, phức tạp.', 'Là người có bằng cấp cao, học hàm, học vị và nhiều năm giữ chức vụ lãnh đạo, quản lý trong cơ quan nhà nước.', 'Là người được cơ quan có thẩm quyền tuyển dụng vào biên chế và xếp ở ngạch chuyên môn cao nhất.', null, 'A', true, null),
  (45, 'Kết luận số 105-KL/TW', 'Việc thu hút và trọng dụng nhân tài phải đặt trong tổng thể nào và lấy nội dung nào làm định hướng cao nhất?', 'Đặt trong tổng thể phát triển đất nước và nhu cầu tăng số lượng người có học hàm, học vị trong khu vực công.', 'Đặt trong tổng thể chiến lược phát triển đất nước, lấy lợi ích quốc gia, dân tộc làm định hướng cao nhất.', 'Đặt trong tổng thể phát triển đất nước và mở rộng đồng đều chính sách nhân tài cho tất cả ngành, lĩnh vực và địa phương.', null, 'B', true, null),
  (46, 'Kết luận số 105-KL/TW', 'Theo quan điểm của Kết luận, đâu là khâu then chốt và đâu là nhiệm vụ căn bản, lâu dài trong công tác nhân tài?', 'Đãi ngộ là khâu then chốt; thu hút từ nước ngoài là nhiệm vụ căn bản, lâu dài.', 'Tuyển dụng là khâu then chốt; đánh giá hằng năm là nhiệm vụ căn bản, lâu dài.', 'Trọng dụng là khâu then chốt; tạo nguồn nhân tài là nhiệm vụ căn bản, lâu dài.', null, 'C', true, null),
  (47, 'Kết luận số 105-KL/TW', 'Đến năm 2030, Kết luận đặt mục tiêu phấn đấu thu hút, trọng dụng khoảng bao nhiêu nhân tài quốc gia gắn với từng nhiệm vụ, chương trình, dự án cụ thể?', 'Khoảng 1.000 nhân tài quốc gia.', 'Khoảng 2.000 nhân tài quốc gia.', 'Khoảng 5.000 nhân tài quốc gia.', null, 'A', true, null),
  (48, 'Kết luận số 105-KL/TW', 'Mục tiêu đến năm 2030 về Chỉ số năng lực cạnh tranh nhân tài toàn cầu của Việt Nam là gì?', 'Thuộc nhóm 20 quốc gia dẫn đầu thế giới.', 'Thuộc nhóm 03 nước đứng đầu Đông Nam Á.', 'Đứng đầu châu Á về Chỉ số năng lực cạnh tranh nhân tài toàn cầu.', null, 'B', true, null),
  (49, 'Kết luận số 105-KL/TW', 'Đến năm 2045, Việt Nam phấn đấu đạt vị trí nào về Chỉ số năng lực cạnh tranh nhân tài toàn cầu?', 'Thuộc nhóm 03 nước đứng đầu Đông Nam Á.', 'Thuộc nhóm 10 quốc gia đứng đầu châu Á.', 'Thuộc nhóm 20 quốc gia dẫn đầu thế giới.', null, 'C', true, null),
  (50, 'Kết luận số 105-KL/TW', 'Nhóm hạ tầng và công cụ số quốc gia về nhân tài được Kết luận xác định gồm những thành phần chủ yếu nào?', 'Cơ sở dữ liệu quốc gia về nhân tài, hệ thống chỉ số quốc gia về nhân tài, Cổng thông tin quốc gia về nhân tài và các nền tảng số phục vụ quản trị, đánh giá.', 'Chỉ gồm Cơ sở dữ liệu quốc gia về nhân tài do Trung ương quản lý.', 'Các cơ sở dữ liệu riêng biệt của từng địa phương, không kết nối và không dùng chung chỉ số đánh giá.', null, 'A', true, null),
  (51, 'Kết luận số 105-KL/TW', 'Mức ngân sách nhà nước dành cho công tác nhân tài được Kết luận định hướng như thế nào?', 'Khoảng 0,05% GDP hằng năm, bố trí ngoài nguồn lực dành cho khoa học, công nghệ.', 'Khoảng 0,1% GDP hằng năm trong tổng nguồn lực dành cho khoa học, công nghệ, đổi mới sáng tạo và chuyển đổi số.', 'Khoảng 1% GDP hằng năm, phân bổ bình quân cho các bộ, ngành, địa phương.', null, 'B', true, null),
  (52, 'Kết luận số 105-KL/TW', 'Nhân tài phải được đánh giá chủ yếu dựa trên căn cứ nào?', 'Bằng cấp, học hàm, học vị, chức vụ quản lý và thâm niên công tác.', 'Vị trí công tác, độ tuổi, cơ quan công tác và số năm giữ chức vụ.', 'Kết quả thực hiện nhiệm vụ, chất lượng sản phẩm và giá trị tạo ra.', null, 'C', true, null),
  (53, 'Kết luận số 105-KL/TW', 'Nguyên tắc nào phải được thực hiện nhất quán khi giao nhiệm vụ chiến lược cho nhân tài?', 'Nhiệm vụ đi liền với người thực hiện, thẩm quyền và nguồn lực.', 'Giao nhiệm vụ trước, xác định thẩm quyền và nguồn lực sau khi có kết quả bước đầu.', 'Ưu tiên giao nhiệm vụ theo chức vụ, thâm niên và thứ bậc hành chính.', null, 'A', true, null),
  (54, 'Kết luận số 105-KL/TW', 'Kết luận xác định việc phát hiện, giới thiệu, tiến cử nhân tài và sử dụng nhân tài trong khu vực công như thế nào?', 'Chỉ phát hiện trong khu vực công và phải tính đủ vào chỉ tiêu biên chế.', 'Thực hiện từ nhiều nguồn trong và ngoài nước, không phân biệt khu vực công và khu vực tư, không tính vào chỉ tiêu biên chế đối với khu vực công.', 'Chỉ tiếp nhận nhân tài là người Việt Nam ở nước ngoài theo chế độ tuyển dụng đặc biệt.', null, 'B', true, null),
  (55, 'Kết luận số 105-KL/TW', 'Trong đánh giá kết quả thực hiện nhiệm vụ của nhân tài, Kết luận yêu cầu phân định rõ nội dung nào?', 'Rủi ro, thất bại khách quan trong nghiên cứu, đổi mới sáng tạo với hành vi thiếu trách nhiệm, gian lận hoặc vụ lợi.', 'Kết quả của cá nhân với kết quả của tập thể để chỉ xem xét trách nhiệm của người đứng đầu.', 'Nhiệm vụ có nguồn ngân sách nhà nước với nhiệm vụ do doanh nghiệp tài trợ để áp dụng hai tiêu chuẩn đánh giá khác nhau.', null, 'A', true, null),
  (56, 'Kết luận số 106-KL/TW', 'Hội nghị lần thứ tư Ban Chấp hành Trung ương Đảng khóa XIV xác định năm 2027 là năm như thế nào?', 'Năm bản lề, tạo nền tảng cho cả giai đoạn phát triển 2026 - 2030.', 'Năm tăng tốc, bứt phá, tạo đà, tạo thế, tạo lực để thực hiện thắng lợi Nghị quyết Đại hội XIV của Đảng.', 'Năm củng cố, ổn định, tạo tiền đề cho giai đoạn tăng tốc từ năm 2028.', null, 'B', true, null),
  (57, 'Kết luận số 106-KL/TW', 'Mục tiêu tăng trưởng kinh tế năm 2027 được Trung ương thống nhất là:', 'Phấn đấu tăng trưởng khoảng 8,5%, ưu tiên giữ vững ổn định kinh tế vĩ mô.', 'Phấn đấu tăng trưởng từ 10% trở lên, chấp nhận lạm phát cao hơn mục tiêu để hỗ trợ tăng trưởng.', 'Phấn đấu tăng trưởng từ 10% trở lên, gắn với giữ vững ổn định kinh tế vĩ mô, kiểm soát lạm phát, bảo đảm các cân đối lớn.', null, 'C', true, null),
  (58, 'Kết luận số 106-KL/TW', 'Trung ương xác định những yếu tố nào được lấy làm thước đo cho sự phát triển?', 'Hiệu quả thực chất, năng suất và đời sống của Nhân dân.', 'Quy mô GDP, tốc độ tăng thu ngân sách nhà nước và tỷ lệ giải ngân vốn đầu tư công.', 'Số dự án đầu tư được phê duyệt, tổng vốn đầu tư toàn xã hội và kim ngạch xuất khẩu.', null, 'A', true, null),
  (59, 'Kết luận số 106-KL/TW', 'Trung ương xác định tốc độ tăng chỉ số giá tiêu dùng (CPI) bình quân năm 2027 ở mức:', 'Khoảng 3,5%.', 'Khoảng 5,5%.', 'Khoảng 4,5%.', null, 'C', true, null),
  (60, 'Kết luận số 106-KL/TW', 'Trung ương đồng ý phấn đấu thu ngân sách nhà nước năm 2027 tăng khoảng bao nhiêu so với ước thực hiện năm 2026?', 'Khoảng 9,1%.', 'Khoảng 12%.', 'Khoảng 15%.', null, 'A', true, null),
  (61, 'Kết luận số 106-KL/TW', 'Trung ương yêu cầu tạo đột phá thực chất, chuyển mạnh sang tạo sản phẩm, kết quả và giá trị cụ thể, lượng hóa đóng góp vào tăng trưởng đối với lĩnh vực nào?', 'Mở rộng tín dụng và tăng mạnh vốn đầu tư công.', 'Khoa học, công nghệ, đổi mới sáng tạo, chuyển đổi số.', 'Khai thác tài nguyên và thu hút vốn đầu tư nước ngoài.', null, 'B', true, null),
  (62, 'Kết luận số 106-KL/TW', 'Trong dự toán ngân sách nhà nước năm 2027, Trung ương yêu cầu tiết kiệm ngay khi phân bổ ngân sách từ đầu năm như thế nào?', 'Tiết kiệm 5% chi đầu tư công để bổ sung cho các dự án trọng điểm, cấp thiết và 10% chi thường xuyên (ngoài tiết kiệm tạo nguồn cải cách tiền lương, các khoản chi lương, có tính chất tiền lương và các khoản chi cho con người) để bổ sung nguồn chi an sinh xã hội.', 'Tiết kiệm 10% chi đầu tư công để bổ sung dự phòng ngân sách và 5% chi thường xuyên để bổ sung nguồn cải cách tiền lương.', 'Tiết kiệm 5% chi thường xuyên để bổ sung cho các dự án trọng điểm, cấp thiết, không tiết kiệm chi đầu tư công.', null, 'A', true, null),
  (63, 'Kết luận số 106-KL/TW', 'Về quy định tỷ lệ phần trăm (%) bố trí chi ngân sách nhà nước cho các ngành, lĩnh vực, Trung ương xác định:', 'Bổ sung quy định tỷ lệ chi tối thiểu cho các lĩnh vực ưu tiên.', 'Giao các địa phương tự quy định tỷ lệ chi cho từng lĩnh vực.', 'Không ban hành thêm các quy định về tỷ lệ % bố trí chi ngân sách nhà nước cho các ngành, lĩnh vực.', null, 'C', true, null),
  (64, 'Kết luận số 106-KL/TW', 'Theo chỉ đạo của Trung ương, trách nhiệm trực tiếp chỉ đạo xử lý dứt điểm nhà, đất dôi dư của địa phương thuộc về ai?', 'Bí thư Tỉnh ủy, Thành ủy.', 'Chủ tịch Ủy ban nhân dân cấp xã.', 'Giám đốc Sở Tài chính.', null, 'A', true, null),
  (65, 'Kết luận số 106-KL/TW', 'Trong trường hợp có biến động hoặc ban hành thêm chính sách tác động tới thu ngân sách nhà nước, Trung ương cho phép đánh giá việc hoàn thành nhiệm vụ tài chính - ngân sách nhà nước năm 2027 của Trung ương và địa phương theo cách nào?', 'Theo dự toán Quốc hội quyết định từ đầu năm, không điều chỉnh trong năm.', 'Theo dự toán điều chỉnh.', 'Theo số thực hiện năm 2026 cộng mức tăng thu dự kiến.', null, 'B', true, null);

    update public.cau_hinh set
      ten_dot           = 'Đánh giá nhận thức sau học tập Nghị quyết Hội nghị Trung ương 4 khóa XIV',
      don_vi_to_chuc    = 'Ban Tuyên giáo Tỉnh ủy Tuyên Quang',
      thoi_gian_lam_bai = 120,
      ty_le_dat         = 70,
      so_lan_toi_da     = 3,
      dao_cau_hoi       = false,   -- giữ nguyên thứ tự câu hỏi và đáp án
      tam_dung          = false,
      thu_nghiem_tu     = now(),
      mo_tu             = '2026-11-09 08:00:00+07',
      dong_luc          = '2026-11-15 22:00:00+07',
      tai_lieu          = '[{"ten": "Nghị quyết số 31-NQ/TW", "mo_ta": "Nghị quyết số 31-NQ/TW, ngày 15/10/2026 của Ban Chấp hành Trung ương Đảng khóa XIV về tăng cường xây dựng, chỉnh đốn Đảng và hệ thống chính trị trong sạch, vững mạnh toàn diện, đáp ứng yêu cầu phát triển của đất nước trong kỷ nguyên mới"}, {"ten": "Nghị quyết số 29-NQ/TW", "mo_ta": "Nghị quyết số 29-NQ/TW, ngày 15/10/2026 của Ban Chấp hành Trung ương Đảng khóa XIV về tiếp tục đổi mới, hoàn thiện phương thức lãnh đạo, cầm quyền của Đảng trong kỷ nguyên mới"}, {"ten": "Nghị quyết số 30-NQ/TW", "mo_ta": "Nghị quyết số 30-NQ/TW, ngày 15/10/2026 của Ban Chấp hành Trung ương Đảng khóa XIV về tiếp tục xây dựng đội ngũ cán bộ các cấp và đổi mới căn bản, toàn diện công tác cán bộ đáp ứng yêu cầu phát triển đất nước trong kỷ nguyên mới"}, {"ten": "Quy định số 224-QĐ/TW", "mo_ta": "Quy định số 224-QĐ/TW, ngày 14/10/2026 của Ban Chấp hành Trung ương Đảng khóa XIV về đảng viên tham gia hoạt động đầu tư, kinh doanh"}, {"ten": "Kết luận số 105-KL/TW", "mo_ta": "Kết luận số 105-KL/TW, ngày 15/10/2026 của Ban Chấp hành Trung ương Đảng khóa XIV về thu hút và trọng dụng nhân tài trong các ngành, lĩnh vực mũi nhọn, phục vụ đất nước phát triển nhanh, bền vững"}, {"ten": "Kết luận số 106-KL/TW", "mo_ta": "Kết luận số 106-KL/TW, ngày 15/10/2026 của Ban Chấp hành Trung ương Đảng khóa XIV về tình hình phát triển kinh tế - xã hội, thực hiện ngân sách nhà nước năm 2026; kế hoạch năm 2027"}]'::jsonb,
      phien_du_lieu     = 3,
      cap_nhat_luc      = now()
    where id = 1;
    raise notice 'Đã nâng cấp dữ liệu lên phiên bản 3: 65 câu hỏi, đợt 09/11 – 15/11/2026.';
  end if;
end $$;

-- Tính lại bảng xếp hạng theo cấu trúc mới (an toàn, chỉ là bộ nhớ đệm)
delete from public.bxh_cache;

-- Báo máy chủ API nạp lại cấu trúc ngay
notify pgrst, 'reload schema';
