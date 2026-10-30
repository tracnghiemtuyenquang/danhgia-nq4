-- =====================================================================
--  PHẦN MỀM ĐÁNH GIÁ NHẬN THỨC SAU HỌC TẬP NGHỊ QUYẾT
--  Hội nghị Trung ương 4 khóa XIV — Tỉnh ủy Tuyên Quang
--  File khởi tạo CSDL: chạy MỘT LẦN trong Supabase > SQL Editor
--  (chạy lại cũng được: các bảng giữ nguyên, hàm được cập nhật,
--   dữ liệu mẫu chỉ nạp khi bảng còn trống)
-- =====================================================================

-- ---------- 1. BẢNG ----------

create table if not exists public.cau_hinh (
  id                int primary key default 1 check (id = 1),
  ten_dot           text not null default 'Đánh giá nhận thức sau học tập Nghị quyết Hội nghị Trung ương 4 khóa XIV',
  don_vi_to_chuc    text not null default 'Tỉnh ủy Tuyên Quang',
  thoi_gian_lam_bai int  not null default 45 check (thoi_gian_lam_bai between 1 and 300),   -- phút
  ty_le_dat         int  not null default 70 check (ty_le_dat between 1 and 100),            -- %
  thu_nghiem_tu     timestamptz,          -- bắt đầu chạy thử (dữ liệu đánh dấu "thử nghiệm")
  mo_tu             timestamptz,          -- bắt đầu chính thức
  dong_luc          timestamptz,          -- kết thúc
  dao_cau_hoi       boolean not null default true,
  cho_thi_lai       boolean not null default true,
  tam_dung          boolean not null default false,   -- khóa khẩn cấp
  thong_bao         text,
  cap_nhat_luc      timestamptz not null default now()
);

create table if not exists public.dang_bo (
  id         serial primary key,
  ten        text not null,
  nhom       text not null default 'Đảng ủy các xã, phường',
  thu_tu     int  not null default 0,
  hoat_dong  boolean not null default true
);

create table if not exists public.cau_hoi (
  id           serial primary key,
  thu_tu       int  not null default 0,
  chuyen_de    text,
  noi_dung     text not null,
  a            text not null,
  b            text not null,
  c            text,
  d            text,
  dap_an       char(1) not null check (dap_an in ('A','B','C','D')),
  hoat_dong    boolean not null default true,
  ghi_chu      text,
  cap_nhat_luc timestamptz not null default now()
);

create table if not exists public.bai_thi (
  id            uuid primary key default gen_random_uuid(),
  ho_ten        text not null,
  chuc_vu       text not null,
  don_vi        text not null,
  dang_bo_id    int  not null references public.dang_bo(id),
  lanh_dao      boolean not null,
  khoa_nguoi    text not null,                 -- họ tên + đảng bộ + đơn vị (chuẩn hóa) để lọc trùng
  thu_nghiem    boolean not null default false,
  bat_dau       timestamptz not null default now(),
  nop_luc       timestamptz,
  ds_cau_hoi    int[] not null,
  tra_loi       jsonb,
  so_cau_dung   int,
  tong_so_cau   int not null,
  dat           boolean,
  thoi_gian_giay int,
  qua_gio       boolean not null default false
);
create index if not exists bai_thi_dang_bo_idx on public.bai_thi (dang_bo_id);
create index if not exists bai_thi_khoa_idx    on public.bai_thi (khoa_nguoi);
create index if not exists bai_thi_nop_idx     on public.bai_thi (nop_luc) where nop_luc is not null;

create table if not exists public.quan_tri (
  email text primary key
);

-- ---------- 2. BẢO MẬT (RLS) ----------
-- Người thi KHÔNG đọc/ghi trực tiếp bảng nào; chỉ gọi các hàm bên dưới.
-- Đáp án chỉ nằm trong CSDL, không bao giờ gửi xuống trình duyệt người thi.

alter table public.cau_hinh enable row level security;
alter table public.dang_bo  enable row level security;
alter table public.cau_hoi  enable row level security;
alter table public.bai_thi  enable row level security;
alter table public.quan_tri enable row level security;

revoke all on public.cau_hinh, public.dang_bo, public.cau_hoi, public.bai_thi, public.quan_tri from anon;

create or replace function public.la_quan_tri()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.quan_tri
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

do $$
declare t text;
begin
  foreach t in array array['cau_hinh','dang_bo','cau_hoi','bai_thi'] loop
    execute format('drop policy if exists qt_toan_quyen on public.%I', t);
    execute format('create policy qt_toan_quyen on public.%I for all to authenticated using (public.la_quan_tri()) with check (public.la_quan_tri())', t);
  end loop;
  drop policy if exists qt_xem on public.quan_tri;
  create policy qt_xem on public.quan_tri for select to authenticated using (public.la_quan_tri());
end $$;

grant select, insert, update, delete on public.cau_hinh, public.dang_bo, public.cau_hoi, public.bai_thi to authenticated;
grant select on public.quan_tri to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ---------- 3. HÀM DÙNG CHUNG ----------

create or replace function public.chuan_hoa(p text)
returns text language sql immutable as $$
  select lower(regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g'));
$$;

-- Trạng thái đợt: chua_mo | thu_nghiem | dang_mo | da_ket_thuc | tam_dung
create or replace function public.trang_thai_dot()
returns text language sql stable security definer set search_path = public as $$
  select case
    when c.tam_dung then 'tam_dung'
    when c.dong_luc is not null and now() >= c.dong_luc then 'da_ket_thuc'
    when c.mo_tu is not null and now() >= c.mo_tu then 'dang_mo'
    when c.thu_nghiem_tu is not null and now() >= c.thu_nghiem_tu then 'thu_nghiem'
    else 'chua_mo'
  end
  from public.cau_hinh c where c.id = 1;
$$;

-- ---------- 4. HÀM CHO NGƯỜI THI (anon) ----------

-- 4.1 Thông tin công khai + danh sách đảng bộ (1 lần gọi khi mở trang)
create or replace function public.thong_tin_dot()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ten_dot', c.ten_dot,
    'don_vi_to_chuc', c.don_vi_to_chuc,
    'thoi_gian_lam_bai', c.thoi_gian_lam_bai,
    'ty_le_dat', c.ty_le_dat,
    'cho_thi_lai', c.cho_thi_lai,
    'so_cau', (select count(*) from public.cau_hoi where hoat_dong),
    'thu_nghiem_tu', c.thu_nghiem_tu,
    'mo_tu', c.mo_tu,
    'dong_luc', c.dong_luc,
    'thong_bao', c.thong_bao,
    'trang_thai', public.trang_thai_dot(),
    'bay_gio', now(),
    'dang_bo', coalesce((
      select jsonb_agg(jsonb_build_object('id', d.id, 'ten', d.ten, 'nhom', d.nhom) order by d.thu_tu, d.id)
      from public.dang_bo d where d.hoat_dong), '[]'::jsonb)
  )
  from public.cau_hinh c where c.id = 1;
$$;

-- 4.2 Bắt đầu làm bài: ghi thông tin, trả về đề (KHÔNG có đáp án)
create or replace function public.bat_dau_thi(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  c        public.cau_hinh;
  tt       text := public.trang_thai_dot();
  v_ten    text := btrim(regexp_replace(coalesce(p->>'ho_ten',''),  '\s+', ' ', 'g'));
  v_cv     text := btrim(regexp_replace(coalesce(p->>'chuc_vu',''), '\s+', ' ', 'g'));
  v_dv     text := btrim(regexp_replace(coalesce(p->>'don_vi',''),  '\s+', ' ', 'g'));
  v_db     int;
  v_ld     boolean;
  v_khoa   text;
  v_ds     int[];
  v_id     uuid;
  v_bd     timestamptz;
begin
  select * into c from public.cau_hinh where id = 1;
  if tt = 'tam_dung'    then raise exception 'TAM_DUNG: Đợt đánh giá đang tạm dừng. Đề nghị đồng chí quay lại sau.'; end if;
  if tt = 'chua_mo'     then raise exception 'CHUA_MO: Đợt đánh giá chưa bắt đầu.'; end if;
  if tt = 'da_ket_thuc' then raise exception 'DA_KET_THUC: Đợt đánh giá đã kết thúc.'; end if;

  begin v_db := (p->>'dang_bo_id')::int; exception when others then v_db := null; end;
  v_ld := case p->>'lanh_dao' when 'true' then true when 'false' then false else null end;

  if length(v_ten) < 4 or length(v_ten) > 100 then raise exception 'DU_LIEU: Họ và tên không hợp lệ.'; end if;
  if length(v_cv)  < 2 or length(v_cv)  > 200 then raise exception 'DU_LIEU: Chức vụ không hợp lệ.'; end if;
  if length(v_dv)  < 2 or length(v_dv)  > 200 then raise exception 'DU_LIEU: Đơn vị công tác không hợp lệ.'; end if;
  if v_ld is null then raise exception 'DU_LIEU: Chưa chọn có giữ chức vụ lãnh đạo, quản lý hay không.'; end if;
  if v_db is null or not exists (select 1 from public.dang_bo where id = v_db and hoat_dong)
    then raise exception 'DU_LIEU: Chưa chọn đảng bộ.'; end if;

  v_khoa := public.chuan_hoa(v_ten) || '|' || v_db || '|' || public.chuan_hoa(v_dv);

  if not c.cho_thi_lai and tt = 'dang_mo' and exists (
      select 1 from public.bai_thi
      where khoa_nguoi = v_khoa and nop_luc is not null and not thu_nghiem)
    then raise exception 'DA_THI: Đồng chí đã hoàn thành bài đánh giá trong đợt này.'; end if;

  select array_agg(id order by thu_tu, id) into v_ds from public.cau_hoi where hoat_dong;
  if v_ds is null then raise exception 'CHUA_CO_DE: Chưa có câu hỏi.'; end if;

  insert into public.bai_thi (ho_ten, chuc_vu, don_vi, dang_bo_id, lanh_dao, khoa_nguoi,
                              thu_nghiem, ds_cau_hoi, tong_so_cau)
  values (v_ten, v_cv, v_dv, v_db, v_ld, v_khoa, tt = 'thu_nghiem', v_ds, cardinality(v_ds))
  returning id, bat_dau into v_id, v_bd;

  return jsonb_build_object(
    'id', v_id,
    'bat_dau', v_bd,
    'bay_gio', now(),
    'thoi_gian_giay', c.thoi_gian_lam_bai * 60,
    'dao_cau_hoi', c.dao_cau_hoi,
    'thu_nghiem', tt = 'thu_nghiem',
    'cau_hoi', (
      select jsonb_agg(jsonb_build_object(
               'id', q.id, 'chuyen_de', q.chuyen_de, 'noi_dung', q.noi_dung,
               'a', q.a, 'b', q.b, 'c', q.c, 'd', q.d) order by q.thu_tu, q.id)
      from public.cau_hoi q where q.id = any(v_ds))
  );
end;
$$;

-- 4.3 Nộp bài: chấm điểm trên máy chủ. Gọi lại nhiều lần vẫn an toàn (trả kết quả cũ).
create or replace function public.nop_bai(p_id uuid, p_tra_loi jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  b      public.bai_thi;
  c      public.cau_hinh;
  v_tl   jsonb;
  v_dung int;
  v_giay int;
begin
  select * into c from public.cau_hinh where id = 1;
  select * into b from public.bai_thi where id = p_id for update;
  if not found then raise exception 'KHONG_THAY: Không tìm thấy bài làm.'; end if;

  if b.nop_luc is null then
    -- chỉ giữ câu trả lời hợp lệ của đúng các câu trong đề
    select coalesce(jsonb_object_agg(k, upper(v)), '{}'::jsonb) into v_tl
    from jsonb_each_text(coalesce(p_tra_loi, '{}'::jsonb)) as e(k, v)
    where k ~ '^\d+$' and k::int = any(b.ds_cau_hoi) and upper(v) in ('A','B','C','D');

    select count(*) into v_dung from public.cau_hoi q
    where q.id = any(b.ds_cau_hoi) and v_tl ->> q.id::text = q.dap_an;

    v_giay := extract(epoch from now() - b.bat_dau)::int;

    update public.bai_thi set
      nop_luc = now(), tra_loi = v_tl, so_cau_dung = v_dung,
      dat = v_dung * 100 >= c.ty_le_dat * b.tong_so_cau,
      thoi_gian_giay = v_giay,
      qua_gio = v_giay > c.thoi_gian_lam_bai * 60 + 300
    where id = p_id
    returning * into b;
  end if;

  return jsonb_build_object(
    'so_cau_dung', b.so_cau_dung,
    'tong_so_cau', b.tong_so_cau,
    'dat', b.dat,
    'ty_le_dat', c.ty_le_dat,
    'can_dat', ceil(c.ty_le_dat * b.tong_so_cau / 100.0)::int,
    'ho_ten', b.ho_ten,
    'nop_luc', b.nop_luc,
    'thu_nghiem', b.thu_nghiem
  );
end;
$$;

-- ---------- 5. HÀM CHO QUẢN TRỊ ----------

create or replace function public.kiem_tra_quan_tri()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.la_quan_tri() then raise exception 'KHONG_CO_QUYEN: Tài khoản không có quyền quản trị.'; end if;
end;
$$;

-- Lượt tốt nhất của mỗi người (đã nộp). Cùng người = cùng họ tên + đảng bộ + đơn vị.
create or replace function public.ds_tot_nhat(p_thu_nghiem boolean)
returns setof public.bai_thi language sql stable security definer set search_path = public as $$
  select distinct on (khoa_nguoi) *
  from public.bai_thi
  where nop_luc is not null and thu_nghiem = p_thu_nghiem
  order by khoa_nguoi, so_cau_dung desc, nop_luc asc;
$$;
revoke execute on function public.ds_tot_nhat(boolean) from public, anon;

-- 5.1 Tổng hợp theo đảng bộ (tách lãnh đạo / không lãnh đạo)
create or replace function public.qt_thong_ke(p_thu_nghiem boolean default false)
returns table (
  dang_bo_id int, ten text, nhom text, thu_tu int,
  tham_gia bigint, tham_gia_ld bigint,
  dat bigint, dat_ld bigint,
  khong_dat bigint, khong_dat_ld bigint,
  so_luot bigint
) language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.kiem_tra_quan_tri();
  return query
  with tn as (select * from public.ds_tot_nhat(p_thu_nghiem)),
       luot as (select b.dang_bo_id, count(*) n from public.bai_thi b
                where b.nop_luc is not null and b.thu_nghiem = p_thu_nghiem group by b.dang_bo_id)
  select d.id, d.ten, d.nhom, d.thu_tu,
         count(tn.id),
         count(tn.id) filter (where tn.lanh_dao),
         count(tn.id) filter (where tn.dat),
         count(tn.id) filter (where tn.dat and tn.lanh_dao),
         count(tn.id) filter (where not tn.dat),
         count(tn.id) filter (where not tn.dat and tn.lanh_dao),
         coalesce(max(luot.n), 0)
  from public.dang_bo d
  left join tn   on tn.dang_bo_id = d.id
  left join luot on luot.dang_bo_id = d.id
  group by d.id, d.ten, d.nhom, d.thu_tu
  order by d.thu_tu, d.id;
end;
$$;

-- 5.2 Tổng quan nhanh
create or replace function public.qt_tong_quan(p_thu_nghiem boolean default false)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r jsonb;
begin
  perform public.kiem_tra_quan_tri();
  select jsonb_build_object(
    'so_nguoi',      (select count(*) from public.ds_tot_nhat(p_thu_nghiem)),
    'so_dat',        (select count(*) from public.ds_tot_nhat(p_thu_nghiem) t where t.dat),
    'so_luot_nop',   (select count(*) from public.bai_thi where nop_luc is not null and thu_nghiem = p_thu_nghiem),
    'dang_lam',      (select count(*) from public.bai_thi where nop_luc is null and thu_nghiem = p_thu_nghiem
                        and bat_dau > now() - interval '1 hour'),
    'bo_do',         (select count(*) from public.bai_thi where nop_luc is null and thu_nghiem = p_thu_nghiem
                        and bat_dau <= now() - interval '1 hour'),
    'diem_tb',       (select round(avg(so_cau_dung)::numeric, 2) from public.ds_tot_nhat(p_thu_nghiem)),
    'so_thu_nghiem', (select count(*) from public.bai_thi where thu_nghiem),
    'theo_ngay',     coalesce((select jsonb_agg(jsonb_build_object('ngay', s.ngay, 'so_luot', s.n) order by s.ngay) from (
                        select to_char(nop_luc at time zone 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') ngay, count(*) n
                        from public.bai_thi where nop_luc is not null and thu_nghiem = p_thu_nghiem
                        group by 1) s), '[]'::jsonb),
    'trang_thai',    public.trang_thai_dot(),
    'bay_gio',       now()
  ) into r;
  return r;
end;
$$;

-- 5.3 Tỷ lệ trả lời đúng từng câu (lượt tốt nhất của mỗi người)
create or replace function public.qt_thong_ke_cau_hoi(p_thu_nghiem boolean default false)
returns table (cau_hoi_id int, thu_tu int, chuyen_de text, noi_dung text, dap_an char(1), hoat_dong boolean,
               so_tra_loi bigint, so_dung bigint, so_a bigint, so_b bigint, so_c bigint, so_d bigint, bo_trong bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.kiem_tra_quan_tri();
  return query
  with tn as (select * from public.ds_tot_nhat(p_thu_nghiem))
  select q.id, q.thu_tu, q.chuyen_de, q.noi_dung, q.dap_an, q.hoat_dong,
         count(tn.id),
         count(tn.id) filter (where tn.tra_loi ->> q.id::text = q.dap_an),
         count(tn.id) filter (where tn.tra_loi ->> q.id::text = 'A'),
         count(tn.id) filter (where tn.tra_loi ->> q.id::text = 'B'),
         count(tn.id) filter (where tn.tra_loi ->> q.id::text = 'C'),
         count(tn.id) filter (where tn.tra_loi ->> q.id::text = 'D'),
         count(tn.id) filter (where tn.id is not null and tn.tra_loi ->> q.id::text is null)
  from public.cau_hoi q
  left join tn on q.id = any(tn.ds_cau_hoi)
  group by q.id
  order by q.thu_tu, q.id;
end;
$$;

-- 5.4 Danh sách người tham gia (phân trang, tìm kiếm)
create or replace function public.qt_danh_sach(
  p_thu_nghiem boolean default false,
  p_tim text default null,
  p_dang_bo int default null,
  p_ket_qua text default null,       -- 'dat' | 'khong_dat' | null
  p_lanh_dao boolean default null,
  p_tat_ca_luot boolean default false,
  p_tu int default 0,
  p_so int default 50)
returns table (id uuid, ho_ten text, chuc_vu text, don_vi text, dang_bo_id int, dang_bo text,
               lanh_dao boolean, so_cau_dung int, tong_so_cau int, dat boolean,
               bat_dau timestamptz, nop_luc timestamptz, thoi_gian_giay int, qua_gio boolean,
               so_lan bigint, tong bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.kiem_tra_quan_tri();
  return query
  with nguon as (
    select b.* from public.bai_thi b
    where p_tat_ca_luot and b.thu_nghiem = p_thu_nghiem
    union all
    select t.* from public.ds_tot_nhat(p_thu_nghiem) t where not p_tat_ca_luot
  ),
  dem as (select b.khoa_nguoi, count(*) n from public.bai_thi b
          where b.nop_luc is not null and b.thu_nghiem = p_thu_nghiem group by b.khoa_nguoi),
  loc as (
    select n.*, d.ten as ten_db, d.thu_tu as tt_db, coalesce(dem.n, 0) as n_lan
    from nguon n
    join public.dang_bo d on d.id = n.dang_bo_id
    left join dem on dem.khoa_nguoi = n.khoa_nguoi
    where (p_tim is null or p_tim = '' or public.chuan_hoa(n.ho_ten || ' ' || n.don_vi || ' ' || n.chuc_vu) like '%' || public.chuan_hoa(p_tim) || '%')
      and (p_dang_bo is null or n.dang_bo_id = p_dang_bo)
      and (p_lanh_dao is null or n.lanh_dao = p_lanh_dao)
      and (p_ket_qua is null or (p_ket_qua = 'dat' and n.dat) or (p_ket_qua = 'khong_dat' and n.dat = false))
  )
  select l.id, l.ho_ten, l.chuc_vu, l.don_vi, l.dang_bo_id, l.ten_db, l.lanh_dao, l.so_cau_dung, l.tong_so_cau,
         l.dat, l.bat_dau, l.nop_luc, l.thoi_gian_giay, l.qua_gio, l.n_lan, count(*) over ()
  from loc l
  order by l.tt_db, l.dang_bo_id, l.ho_ten, l.bat_dau
  offset greatest(p_tu, 0) limit least(greatest(p_so, 1), 1000);
end;
$$;

-- 5.5 Chấm lại toàn bộ (dùng khi sửa đáp án sau khi đã có người thi)
create or replace function public.qt_cham_lai()
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  perform public.kiem_tra_quan_tri();
  with diem as (
    select b.id,
           (select count(*) from public.cau_hoi q
             where q.id = any(b.ds_cau_hoi) and b.tra_loi ->> q.id::text = q.dap_an)::int as dung
    from public.bai_thi b where b.nop_luc is not null
  )
  update public.bai_thi b set
    so_cau_dung = diem.dung,
    dat = diem.dung * 100 >= (select ty_le_dat from public.cau_hinh where id = 1) * b.tong_so_cau
  from diem where diem.id = b.id;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 5.6 Xóa dữ liệu thử nghiệm
create or replace function public.qt_xoa_thu_nghiem()
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  perform public.kiem_tra_quan_tri();
  delete from public.bai_thi where thu_nghiem;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Quyền gọi hàm
revoke execute on function public.qt_thong_ke(boolean), public.qt_tong_quan(boolean),
  public.qt_thong_ke_cau_hoi(boolean), public.qt_cham_lai(), public.qt_xoa_thu_nghiem(),
  public.qt_danh_sach(boolean, text, int, text, boolean, boolean, int, int) from public, anon;
grant execute on function public.qt_thong_ke(boolean), public.qt_tong_quan(boolean),
  public.qt_thong_ke_cau_hoi(boolean), public.qt_cham_lai(), public.qt_xoa_thu_nghiem(),
  public.qt_danh_sach(boolean, text, int, text, boolean, boolean, int, int), public.la_quan_tri() to authenticated;
grant execute on function public.thong_tin_dot(), public.bat_dau_thi(jsonb), public.nop_bai(uuid, jsonb) to anon, authenticated;

-- ---------- 6. DỮ LIỆU BAN ĐẦU ----------

insert into public.cau_hinh (id, thu_nghiem_tu, mo_tu, dong_luc)
values (1, '2026-11-04 08:00:00+07', '2026-11-05 08:00:00+07', '2026-11-15 17:00:00+07')
on conflict (id) do nothing;

-- Tài khoản quản trị: thêm email đã tạo trong Authentication > Users
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

-- Bộ câu hỏi (31 câu từ file gốc; câu thừa đang tắt)
insert into public.cau_hoi (thu_tu, chuyen_de, noi_dung, a, b, c, d, dap_an, hoat_dong, ghi_chu)
select * from (values
(1, 'Nghị quyết số 31-NQ/TW', 'Quan hệ giữa “kiên định” và “đổi mới” được thể hiện như thế nào trong tư duy chỉ đạo của Nghị quyết?', 'Kiên định mục tiêu và nguyên tắc là nền tảng; đổi mới chỉ cần đặt ra ở cách tổ chức thực hiện, không nhất thiết phát triển nhận thức và lý luận.', 'Đổi mới phải đi trước để đáp ứng thực tiễn; khi yêu cầu phát triển thay đổi có thể chủ động điều chỉnh các nguyên tắc nền tảng.', 'Kiên định và vận dụng, phát triển sáng tạo chủ nghĩa Mác-Lênin, tư tưởng Hồ Chí Minh, lý luận về đường lối đổi mới, mục tiêu độc lập dân tộc và chủ nghĩa xã hội, các nguyên tắc tổ chức, hoạt động của Đảng. Trên nền tảng đó, không ngừng đổi mới tư duy, phát triển lý luận, tổng kết thực tiễn, nâng cao năng lực dự báo và kiến tạo tầm nhìn dài hạn.', null, 'C', true, null),
(2, 'Nghị quyết số 31-NQ/TW', 'Phương án nào thể hiện đúng nhất bước phát triển trong việc xây dựng Đảng “thật sự là đạo đức, là văn minh” theo Nghị quyết?', 'Chuyển các giá trị vì nước, vì dân, cần, kiệm, liêm chính, chí công vô tư, trung thực, nêu gương từ yêu cầu tu dưỡng, rèn luyện thành chuẩn mực bắt buộc trong ứng xử, ra quyết định, sử dụng quyền lực và kỷ luật thực thi công vụ.', 'Đặt trọng tâm vào giáo dục, tự giác tu dưỡng và các phong trào nêu gương; các chuẩn mực về hành vi, quyết định và sử dụng quyền lực sẽ hình thành từ quá trình rèn luyện.', 'Xây dựng hệ thống văn hóa lãnh đạo, văn hóa cầm quyền, văn hóa quản lý và văn hóa liêm chính như bốn thành tố độc lập ngang nhau; đánh giá chủ yếu qua việc tuân thủ quy tắc ứng xử.', null, 'A', true, null),
(3, 'Nghị quyết số 31-NQ/TW', 'Theo Nghị quyết, khi phân cấp nhiệm vụ cho cấp sát việc, sát dân, phương án nào bảo đảm đồng bộ nhất giữa trao quyền và trách nhiệm?', 'Giao rõ nhiệm vụ, tăng nguồn lực nhưng vẫn yêu cầu cấp dưới xin ý kiến cấp trên trước các quyết định thuộc thẩm quyền để giảm rủi ro.', 'Trao quyền quyết định và yêu cầu cấp dưới tự chịu trách nhiệm; hoạt động kiểm tra, giám sát chủ yếu tiến hành sau khi phát sinh khó khăn, sai phạm.', 'Trao đủ thẩm quyền, nguồn lực và trách nhiệm giải trình; cấp trên tập trung định hướng, tiêu chuẩn, kiểm tra, giám sát, cấp dưới chủ động quyết định và chịu trách nhiệm theo thẩm quyền. Kiểm soát quyền lực xuyên suốt từ giao quyền, thực hiện quyền đến kiểm tra, giám sát.', null, 'C', true, null),
(4, 'Nghị quyết số 31-NQ/TW', 'Việc khuyến khích, bảo vệ cán bộ dám nghĩ, dám làm, dám chịu trách nhiệm vì lợi ích chung phải tuân theo nguyên tắc nào?', 'Phân biệt sai phạm do vụ lợi, cố ý làm trái với rủi ro phát sinh trong đổi mới sáng tạo; việc bảo vệ phải căn cứ động cơ trong sáng, vì lợi ích chung, đúng thẩm quyền và có kiểm soát, không bao che hoặc miễn trừ trách nhiệm.', 'Ưu tiên bảo vệ người có sáng kiến và có động cơ tích cực; chỉ xem xét trách nhiệm khi chứng minh được mục đích vụ lợi.', 'Chỉ bảo vệ các quyết định sáng tạo đã đạt kết quả dự kiến; trường hợp chưa đạt kết quả phải xử lý trách nhiệm như các vi phạm thông thường.', null, 'A', true, null),
(5, 'Nghị quyết số 31-NQ/TW', 'Một chủ trương được đánh giá là đúng nhưng triển khai chậm, không tạo chuyển biến rõ. Theo tinh thần đổi mới của Nghị quyết, khâu nào phải được thay đổi căn bản?', 'Quản trị xuyên suốt từ xác định vấn đề, chuẩn bị quyết sách, thể chế hóa đến giao người, thẩm quyền, nguồn lực, tổ chức thực hiện, kiểm tra, phản hồi, điều chỉnh; đo kết quả và quy trách nhiệm đến cùng.', 'Tăng cường quán triệt, tuyên truyền và ban hành văn bản hướng dẫn kịp thời, đồng thời giao cấp dưới chủ động lựa chọn biện pháp thực hiện.', 'Tổ chức thêm các đợt kiểm tra cuối kỳ, tổng hợp kết quả và rút kinh nghiệm để hoàn thiện việc ban hành nghị quyết ở nhiệm kỳ sau.', null, 'A', true, null),
(6, 'Nghị quyết số 29-NQ/TW', 'Theo Nghị quyết, Đảng thực hiện phương thức lãnh đạo chủ yếu bằng những phương thức nào?', 'Bằng hoạt động quản lý hành chính, điều hành trực tiếp và quyết định thay các cơ quan nhà nước.', 'Bằng Cương lĩnh, đường lối, chủ trương, định hướng chiến lược; công tác tư tưởng, tuyên truyền, vận động; công tác tổ chức, cán bộ; kiểm tra, giám sát, kiểm soát quyền lực; vai trò tiên phong, gương mẫu của cán bộ, đảng viên.', 'Chủ yếu bằng việc phân bổ nguồn lực, ban hành pháp luật và trực tiếp tổ chức thực hiện mọi nhiệm vụ phát triển kinh tế - xã hội.', null, 'B', true, null),
(7, 'Nghị quyết số 29-NQ/TW', 'Quan điểm của Nghị quyết về mối quan hệ giữa quyền lãnh đạo và trách nhiệm chính trị được xác định như thế nào?', 'Quyền lãnh đạo thuộc về tập thể; cá nhân chỉ chịu trách nhiệm chính trị khi có vi phạm pháp luật.', 'Cấp trên chịu trách nhiệm thay cho cấp dưới đối với mọi nhiệm vụ đã phân cấp, phân quyền.', 'Quyền lãnh đạo gắn với trách nhiệm chính trị; thẩm quyền đến đâu, trách nhiệm đến đó.', null, 'C', true, null),
(8, 'Nghị quyết số 29-NQ/TW', 'Mục tiêu tổng quát về đổi mới phương thức lãnh đạo, cầm quyền của Đảng được Nghị quyết xác định theo hướng nào?', 'Tập trung thống nhất mọi hoạt động quản lý, điều hành vào cấp ủy để bảo đảm sự lãnh đạo toàn diện.', 'Khoa học, dân chủ, pháp quyền, hiện đại, vì lợi ích quốc gia - dân tộc và vì Nhân dân.', 'Ưu tiên hoàn thiện tổ chức bộ máy trước, việc đổi mới phương thức lãnh đạo được thực hiện sau khi bộ máy ổn định.', null, 'B', true, null),
(9, 'Nghị quyết số 29-NQ/TW', 'Việc vận hành thực chất cơ chế “Đảng lãnh đạo, Nhà nước quản lý, Nhân dân làm chủ” đòi hỏi điều gì?', 'Đảng xác định đường lối, định hướng chiến lược, quyết định vấn đề lớn theo thẩm quyền; Nhà nước kịp thời thể chế hóa, quản lý, điều hành, kiến tạo phát triển; Nhân dân thực hiện quyền làm chủ, tham gia xây dựng Đảng, xây dựng Nhà nước, giám sát hoạt động của hệ thống chính trị và thụ hưởng thành quả phát triển.', 'Đảng trực tiếp thực hiện các công việc quản lý, điều hành; Nhà nước chủ yếu làm nhiệm vụ tham mưu và báo cáo.', 'Mặt trận Tổ quốc Việt Nam thay cơ quan nhà nước tổ chức thực hiện chính sách và giải quyết công việc hành chính cho Nhân dân.', null, 'A', true, null),
(10, 'Nghị quyết số 29-NQ/TW', 'Nghị quyết yêu cầu kiểm soát quyền lực được giao bằng những phương thức nào?', 'Bằng thể chế, quy chế, quy trình, dữ liệu, công khai, minh bạch và trách nhiệm giải trình; kiểm soát cả hành vi lạm quyền, vượt quyền và tình trạng né, không tránh thực hiện đầy đủ thẩm quyền, trách nhiệm.', 'Chủ yếu bằng kiểm tra định kỳ sau khi nhiệm vụ đã kết thúc, hạn chế kiểm tra trong quá trình thực hiện.', 'Tập trung kiểm soát cán bộ cấp dưới, không đặt ra yêu cầu kiểm soát đối với cơ quan tham mưu và người đứng đầu.', null, 'A', true, null),
(11, 'Nghị quyết số 30-NQ/TW', 'Theo Nghị quyết, việc đổi mới nội dung đánh giá cán bộ phải bảo đảm nguyên tắc nào?', 'Phẩm chất chính trị, tư tưởng, đạo đức, liêm chính, kỷ luật.', 'Năng lực thực tiễn, sản phẩm, kết quả, hiệu quả, mức độ cống hiến.', 'Bảo đảm toàn diện, thực chất về phẩm chất chính trị, tư tưởng, đạo đức, liêm chính, kỷ luật; năng lực thực tiễn, sản phẩm, kết quả, hiệu quả, mức độ cống hiến, uy tín trong tổ chức và trước Nhân dân.', null, 'C', true, null),
(12, 'Nghị quyết số 30-NQ/TW', 'Về hoàn thiện đồng bộ chức danh, nhiệm vụ, vị trí việc làm, Nghị quyết yêu cầu phải bảo đảm đồng thời hai mặt nào?', 'Cơ cấu chức danh và tiêu chuẩn cán bộ. Không vì cơ cấu mà hạ thấp tiêu chuẩn; không đặt ra tiêu chuẩn hình thức làm thu hẹp nguồn cán bộ.', 'Không hạ thấp tiêu chuẩn về bằng cấp, đồng thời nâng cao tiêu chuẩn về kinh nghiệm thực tiễn.', 'Bảo đảm tiêu chuẩn chung của Đảng, đồng thời cho phép mỗi cấp ủy quy định thêm tiêu chuẩn riêng phù hợp đặc thù.', null, 'A', true, null),
(13, 'Nghị quyết số 30-NQ/TW', 'Nghị quyết xác định chỉ tiêu đến năm 2030, việc xây dựng đội ngũ cán bộ cần đạt là gì?', 'Tỷ lệ cán bộ hoàn thành xuất sắc nhiệm vụ và tỷ lệ cán bộ đạt chuẩn chức danh.', 'Mức độ hoàn thành các chỉ tiêu về cơ cấu cán bộ trẻ, cán bộ nữ, cán bộ là người dân tộc thiểu số.', 'Bảo đảm cơ cấu cán bộ hợp lý; tiếp tục nâng tỷ lệ cán bộ trẻ, cán bộ nữ, cán bộ là người dân tộc thiểu số, chuyên gia, nhà khoa học, nhân tài phù hợp với mô hình tổ chức chính quyền địa phương 2 cấp.', null, 'C', true, null),
(14, 'Nghị quyết số 30-NQ/TW', 'Việc bố trí cán bộ phải bảo đảm yêu cầu gì?', 'Căn cứ yêu cầu thực tế để xác định.', 'Bảo đảm cơ cấu hợp lý, năng lực và sở trường, đúng người, đúng việc.', 'Thực hiện theo quy trình và báo cáo cấp có thẩm quyền.', null, 'B', true, null),
(15, 'Nghị quyết số 30-NQ/TW', 'Sau khi đã phân cấp, phân quyền trong công tác cán bộ, trách nhiệm của cấp trên được Nghị quyết xác định là gì?', 'Thẩm định lại hồ sơ nhân sự trước khi cấp dưới ban hành quyết định.', 'Không làm thay việc đã phân cấp; tập trung kiểm tra, giám sát, hậu kiểm và cảnh báo rủi ro.', 'Cho ý kiến bằng văn bản đối với những trường hợp nhân sự quan trọng thuộc thẩm quyền cấp dưới.', null, 'B', true, null),
(16, 'Quy định số 224-QĐ/TW', 'Nhận định nào dưới đây phản ánh đúng phạm vi điều chỉnh của Quy định số 224-QĐ/TW về đảng viên tham gia hoạt động đầu tư kinh doanh?', 'Chỉ quy định quyền sở hữu tài sản của đảng viên ngoài khu vực công.', 'Chỉ quy định thủ tục kê khai và xin chấp thuận trước khi đảng viên đầu tư kinh doanh.', 'Quy định về chủ trương, nguyên tắc, giới hạn, quyền, trách nhiệm và kiểm soát xung đột lợi ích đối với đảng viên tham gia hoạt động đầu tư kinh doanh.', null, 'C', true, null),
(17, 'Quy định số 224-QĐ/TW', 'Quy định số 224-QĐ/TW điều chỉnh việc tham gia hoạt động đầu tư kinh doanh đối với nhóm đảng viên nào?', 'Đảng viên trong và ngoài khu vực công, với quyền và giới hạn tương ứng theo chức danh, vị trí, nhiệm vụ.', 'Chỉ đảng viên là viên chức.', 'Chỉ đảng viên ngoài khu vực công.', null, 'A', true, null),
(18, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, hoạt động đầu tư kinh doanh của đảng viên được phân thành những nhóm nào?', 'Hoạt động chuyên môn và khai thác tài sản tạo thu nhập; đầu tư kinh doanh nhưng không đầu tư thành lập tổ chức kinh tế và không chi phối, quản lý, điều hành.', 'Đầu tư kinh doanh có đầu tư thành lập tổ chức kinh tế hoặc có chi phối nhưng không quản lý, điều hành; đầu tư kinh doanh có tham gia quản lý, điều hành, kể cả trường hợp có đầu tư thành lập tổ chức kinh tế hoặc có chi phối.', 'Cả A và B.', null, 'C', true, 'File gốc chưa ghi đáp án — tạm để C (Cả A và B), cần phòng chuyên môn xác nhận'),
(19, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, đảng viên là người quản lý doanh nghiệp nhà nước, người đại diện phần vốn nhà nước được làm gì mà không phải xin chấp thuận?', 'Được thực hiện hoạt động chuyên môn và khai thác tài sản tạo thu nhập; đầu tư kinh doanh nhưng không đầu tư thành lập tổ chức kinh tế và không chi phối, quản lý, điều hành; mua, nhận, nắm giữ cổ phần, phần vốn góp và thực hiện quyền cổ đông, thành viên tại doanh nghiệp do mình quản lý hoặc đại diện phần vốn nhà nước theo quy định của pháp luật; việc thực hiện quyền đối với phần vốn cá nhân phải tách bạch với chức trách quản lý, đại diện phần vốn nhà nước và bảo đảm kiểm soát xung đột lợi ích.', 'Được tự mình thành lập và trực tiếp điều hành tổ chức kinh tế ngoài khu vực công trong mọi lĩnh vực.', 'Được đầu tư kinh doanh trong ngành, lĩnh vực có lợi ích liên quan trực tiếp đến doanh nghiệp nhà nước do mình quản lý, không cần điều kiện nào.', null, 'A', true, null),
(20, 'Quy định số 224-QĐ/TW', 'Theo Quy định số 224-QĐ/TW, đảng viên không còn công tác trong khu vực công sau khi thôi công tác, nghỉ hưu không được thực hiện hoạt động nào?', 'Các hoạt động bị hạn chế có liên quan đến lĩnh vực, công việc đã phụ trách trong phạm vi và thời hạn theo quy định của pháp luật.', 'Hoạt động chuyên môn và khai thác tài sản tạo thu nhập hợp pháp.', 'Đầu tư thành lập tổ chức kinh tế trong lĩnh vực không bị hạn chế theo pháp luật.', null, 'A', true, null),
(21, 'Kết luận số 105-KL/TW', 'Theo Kết luận, nhân tài được nhận thức như thế nào?', 'Là người có phẩm chất, tố chất, năng lực nổi trội và tư duy sáng tạo; có sản phẩm, thành tích hoặc đóng góp đặc biệt, có tính đột phá, tạo ra giá trị và tác động tích cực; có khả năng đảm nhiệm, giải quyết hiệu quả nhiệm vụ quan trọng, mới, khó, phức tạp.', 'Là người có bằng cấp cao, học hàm, học vị và nhiều năm giữ chức vụ lãnh đạo, quản lý trong cơ quan nhà nước.', 'Là người được cơ quan có thẩm quyền tuyển dụng vào biên chế và xếp ở ngạch chuyên môn cao nhất.', null, 'A', true, 'Đã sửa lỗi chính tả "đảm niệm" thành "đảm nhiệm"'),
(22, 'Kết luận số 105-KL/TW', 'Việc thu hút và trọng dụng nhân tài phải đặt trong tổng thể nào và lấy nội dung nào làm định hướng cao nhất?', 'Đặt trong tổng thể phát triển đất nước và nhu cầu tăng số lượng người có học hàm, học vị trong khu vực công.', 'Đặt trong tổng thể chiến lược phát triển đất nước, lấy lợi ích quốc gia, dân tộc làm định hướng cao nhất.', 'Đặt trong tổng thể phát triển đất nước và mở rộng đồng đều chính sách nhân tài cho tất cả ngành, lĩnh vực và địa phương.', null, 'B', true, null),
(23, 'Kết luận số 105-KL/TW', 'Mục tiêu đến năm 2030 về Chỉ số năng lực cạnh tranh nhân tài toàn cầu của Việt Nam là gì?', 'Thuộc nhóm 20 quốc gia dẫn đầu thế giới.', 'Thuộc nhóm 03 nước đứng đầu Đông Nam Á.', 'Đứng đầu châu Á về Chỉ số năng lực cạnh tranh nhân tài toàn cầu.', null, 'B', true, null),
(24, 'Kết luận số 105-KL/TW', 'Mức ngân sách nhà nước dành cho công tác nhân tài được Kết luận định hướng như thế nào?', 'Khoảng 0,05% GDP hằng năm, bố trí ngoài nguồn lực dành cho khoa học, công nghệ.', 'Khoảng 0,1% GDP hằng năm trong tổng nguồn lực dành cho khoa học, công nghệ, đổi mới sáng tạo và chuyển đổi số.', 'Khoảng 1% GDP hằng năm, phân bổ bình quân cho các bộ, ngành, địa phương.', null, 'B', true, null),
(25, 'Kết luận số 105-KL/TW', 'Nhân tài phải được đánh giá chủ yếu dựa trên căn cứ nào?', 'Bằng cấp, học hàm, học vị, chức vụ quản lý và thâm niên công tác.', 'Vị trí công tác, độ tuổi, cơ quan công tác và số năm giữ chức vụ.', 'Kết quả thực hiện nhiệm vụ, chất lượng sản phẩm và giá trị tạo ra.', null, 'C', true, null),
(26, 'Kết luận số 106-KL/TW', 'Hội nghị lần thứ tư Ban Chấp hành Trung ương Đảng khóa XIV xác định năm 2027 là năm như thế nào?', 'Năm bản lề, tạo nền tảng cho cả giai đoạn phát triển 2026 - 2030.', 'Năm tăng tốc, bứt phá, tạo đà, tạo thế, tạo lực để thực hiện thắng lợi Nghị quyết Đại hội XIV của Đảng.', 'Năm củng cố, ổn định, tạo tiền đề cho giai đoạn tăng tốc từ năm 2028.', null, 'B', true, null),
(27, 'Kết luận số 106-KL/TW', 'Mục tiêu tăng trưởng kinh tế năm 2027 được Trung ương thống nhất là:', 'Phấn đấu tăng trưởng khoảng 8,5%, ưu tiên giữ vững ổn định kinh tế vĩ mô.', 'Phấn đấu tăng trưởng từ 10% trở lên, chấp nhận lạm phát cao hơn mục tiêu để hỗ trợ tăng trưởng.', 'Phấn đấu tăng trưởng từ 10% trở lên, gắn với giữ vững ổn định kinh tế vĩ mô, kiểm soát lạm phát, bảo đảm các cân đối lớn.', null, 'C', true, null),
(28, 'Kết luận số 106-KL/TW', 'Trung ương đồng ý phấn đấu thu ngân sách nhà nước năm 2027 tăng khoảng bao nhiêu so với ước thực hiện năm 2026?', 'Khoảng 9,1%.', 'Khoảng 12%.', 'Khoảng 15%.', null, 'A', true, null),
(29, 'Kết luận số 106-KL/TW', 'Trung ương yêu cầu tạo đột phá thực chất, chuyển mạnh sang tạo sản phẩm, kết quả và giá trị cụ thể, lượng hóa đóng góp vào tăng trưởng đối với lĩnh vực nào?', 'Mở rộng tín dụng và tăng mạnh vốn đầu tư công.', 'Khoa học, công nghệ, đổi mới sáng tạo, chuyển đổi số.', 'Khai thác tài nguyên và thu hút vốn đầu tư nước ngoài.', null, 'B', false, 'Câu thừa trong file gốc (đánh số nhầm "Câu 6", bộ đề có 31 câu) — đang TẮT để đủ 30 câu'),
(30, 'Kết luận số 106-KL/TW', 'Trong dự toán ngân sách nhà nước năm 2027, Trung ương yêu cầu tiết kiệm ngay khi phân bổ ngân sách từ đầu năm như thế nào?', 'Tiết kiệm 5% chi đầu tư công để bổ sung cho các dự án trọng điểm, cấp thiết và 10% chi thường xuyên (ngoài tiết kiệm tạo nguồn cải cách tiền lương, các khoản chi lương, có tính chất tiền lương và các khoản chi cho con người) để bổ sung nguồn chi an sinh xã hội.', 'Tiết kiệm 10% chi đầu tư công để bổ sung dự phòng ngân sách và 5% chi thường xuyên để bổ sung nguồn cải cách tiền lương.', 'Tiết kiệm 5% chi thường xuyên để bổ sung cho các dự án trọng điểm, cấp thiết, không tiết kiệm chi đầu tư công.', null, 'A', true, null),
(31, 'Kết luận số 106-KL/TW', 'Trong trường hợp có biến động hoặc ban hành thêm chính sách tác động tới thu ngân sách nhà nước, Trung ương cho phép đánh giá việc hoàn thành nhiệm vụ tài chính - ngân sách nhà nước năm 2027 của Trung ương và địa phương theo cách nào?', 'Theo dự toán Quốc hội quyết định từ đầu năm, không điều chỉnh trong năm.', 'Theo dự toán điều chỉnh.', 'Theo số thực hiện năm 2026 cộng mức tăng thu dự kiến.', null, 'B', true, 'File gốc chưa ghi đáp án — tạm để B, cần phòng chuyên môn xác nhận')
) v
where not exists (select 1 from public.cau_hoi);
