# Phần mềm Đánh giá nhận thức sau học tập Nghị quyết Hội nghị Trung ương 4 khóa XIV

Tỉnh ủy Tuyên Quang. Chạy trên GitHub Pages và Supabase (bản miễn phí).

## Cấu trúc thư mục

| File | Dùng để |
|---|---|
| `index.html` | Trang làm bài cho cán bộ, đảng viên (gửi link này đi) |
| `admin.html` | Trang quản trị: tổng hợp, danh sách, câu hỏi, đảng bộ, cài đặt, xuất Excel |
| `config.js` | Địa chỉ và khóa Supabase (**chỉ cần sửa file này**) |
| `assets/logo.png` | Logo búa liềm |
| `supabase/khoi_tao.sql` | Tạo CSDL, nạp sẵn 130 đảng bộ và 31 câu hỏi |
| `tools/thu_tai.mjs` | Script giả lập nhiều người thi cùng lúc |

## Các bước triển khai

### Bước 1. Tạo dự án Supabase riêng
1. Vào https://supabase.com/dashboard, bấm **New project**, đặt tên ví dụ `danhgia-nq4`, Region chọn **Southeast Asia (Singapore)**.
2. Nên tạo dự án mới, không dùng chung với các app khác của Ban, để lúc cao điểm không ảnh hưởng nhau.

### Bước 2. Tạo CSDL
1. Vào **SQL Editor**, bấm **New query**.
2. Mở file `supabase/khoi_tao.sql`, chép toàn bộ nội dung, dán vào rồi bấm **Run**. Thấy *Success* là xong.
3. File chạy lại nhiều lần cũng không mất dữ liệu.

### Bước 3. Tạo tài khoản quản trị
1. Vào **Authentication > Users > Add user > Create new user**, nhập email `ngacvantuan.hg@gmail.com` và mật khẩu, tích **Auto Confirm User**.
2. Email này đã được cấp quyền quản trị sẵn trong file SQL. Muốn thêm người quản trị khác: tạo user như trên, rồi chạy trong SQL Editor:
   ```sql
   insert into quan_tri (email) values ('email_nguoi_khac@...');
   ```
3. Nên tắt đăng ký tự do: **Authentication > Sign In / Providers > Email**, bỏ chọn **Allow new users to sign up**.

### Bước 4. Điền cấu hình
Vào **Project Settings > API** (hoặc **API Keys**), chép **Project URL** và khóa **anon public** (hoặc **publishable**) vào `config.js`:
```js
window.CAU_HINH = {
  SUPABASE_URL: "https://abcdxyz.supabase.co",
  SUPABASE_KEY: "eyJhbGciOi..."
};
```
Tuyệt đối không dùng khóa `service_role` hoặc `secret`.

### Bước 5. Đưa lên GitHub Pages
1. Tạo repository mới trên GitHub (ví dụ `danhgia-nq4`), tải toàn bộ thư mục lên. Riêng thư mục `tools` và `supabase` không bắt buộc.
2. Vào **Settings > Pages**, phần *Source* chọn **Deploy from a branch**, nhánh `main`, thư mục `/ (root)`, bấm **Save**.
3. Sau 1–2 phút có địa chỉ:
   - Trang thi: `https://<tên-tài-khoản>.github.io/danhgia-nq4/`
   - Trang quản trị: `https://<tên-tài-khoản>.github.io/danhgia-nq4/admin.html`

## Thời gian đã cài sẵn (sửa được trong trang quản trị > Cài đặt)

| Mốc | Thời gian | Trang thi |
|---|---|---|
| Trước khi chạy thử | trước 08:00 ngày 04/11/2026 | Báo "chưa bắt đầu" |
| Chạy thử | 08:00 ngày 04/11 đến 08:00 ngày 05/11 | Làm bài được, kết quả gắn nhãn **thử nghiệm** |
| Chính thức | 08:00 ngày 05/11 đến 17:00 ngày 15/11 | Làm bài, tính kết quả |
| Kết thúc | sau 17:00 ngày 15/11 | Báo "đã kết thúc" |

Trang tự mở và tự đóng theo các mốc này. Người bắt đầu làm bài trước giờ kết thúc vẫn được làm đủ 45 phút và nộp bình thường.

## Cách phần mềm hoạt động

- **Đáp án không bao giờ gửi xuống điện thoại người thi.** Máy chủ chấm điểm. Người thi không đọc được bảng nào, chỉ gọi được 3 hàm: xem thông tin đợt, bắt đầu làm bài, nộp bài.
- **Mỗi người chỉ có 2 lần ghi vào CSDL:** lúc bắt đầu và lúc nộp. Vì thế bản Supabase miễn phí chịu được 10.000–20.000 người thi rải trong 11 ngày.
- **Bài đang làm được lưu ngay trên điện thoại.** Lỡ tắt trình duyệt hay mất mạng, mở lại trang là làm tiếp, đồng hồ vẫn chạy theo giờ máy chủ.
- **Nộp bài tự thử lại** tối đa 6 lần nếu mạng chập chờn. Nộp trùng không bị tính hai lần.
- **Hết 45 phút** thì tự nộp, câu chưa làm tính là sai.
- **Thi lại:** mặc định cho phép. Tổng hợp lấy **lần có điểm cao nhất** của mỗi người (cùng một người = trùng họ tên + đảng bộ + đơn vị công tác). Có thể tắt ở trang Cài đặt.
- **Đảo thứ tự câu hỏi** cho từng người, giữ nguyên thứ tự phương án A/B/C (vì có câu "Cả A và B").
- **Đạt yêu cầu:** đúng từ 70% số câu trở lên, tức 21/30 câu. Sửa được ở trang Cài đặt.

## Trang quản trị

- **Tổng hợp:** số người tham gia, đạt, không đạt, mỗi mục tách lãnh đạo và không lãnh đạo, theo từng đảng bộ (6 đảng ủy trực thuộc và 124 xã, phường). Có nút chuyển giữa dữ liệu *Chính thức* và *Thử nghiệm*.
- **Xuất Excel** gồm 3 sheet: *Tổng hợp* theo đảng bộ, *Danh sách* từng người, *Theo câu hỏi* (tỷ lệ trả lời đúng từng câu). Font Times New Roman, khổ A4 ngang.
- **Câu hỏi:** thêm, sửa, xóa, bật/tắt. Câu nào đang bật mới vào đề. Sửa đáp án khi đã có người thi thì phần mềm hỏi có **chấm lại toàn bộ** không.
- **Đảng bộ:** sửa tên, thêm, ẩn khỏi danh sách chọn.
- **Cài đặt:** thời gian, tỷ lệ đạt, thông báo trên trang thi, **tạm dừng khẩn cấp**, xóa dữ liệu thử nghiệm.

## Việc cần làm trước ngày 04/11

1. **Phòng chuyên môn xác nhận các điểm trong bộ câu hỏi** (đã ghi chú ⚠ ngay trên từng câu trong trang quản trị):
   - Câu 18: file gốc không có đáp án, đang tạm để **C** ("Cả A và B").
   - Câu 30: file gốc không có đáp án, đang tạm để **B** ("Theo dự toán điều chỉnh").
   - File gốc có **31 câu** (một câu đánh số nhầm "Câu 6" nằm giữa câu 28 và 29). Câu này đang **tắt** để đề đủ 30 câu.
   - Ngưỡng đạt: file yêu cầu ghi 21/30 (70%), file câu hỏi ghi 20/30. Phần mềm đang để **21/30**.
   - Câu 21: đã sửa "đảm niệm" thành "đảm nhiệm".
2. **Chạy thử ngay bây giờ** (không cần đợi 04/11): vào Cài đặt, đặt *Bắt đầu chạy thử* về giờ hiện tại rồi bấm Lưu. Mở trang thi trên vài điện thoại thật (Android, iPhone, cả Zalo) để làm thử.
3. **Thử tải** (cần Node.js 18 trở lên), trong lúc đang ở chế độ thử nghiệm:
   ```
   cd tools
   node thu_tai.mjs --url https://abcdxyz.supabase.co --key <anon key> --so 2000 --dong-thoi 100
   ```
   Nếu 95% lượt nộp dưới khoảng 1–2 giây và không có lỗi là ổn.
4. Thử xong: Cài đặt > **Xóa toàn bộ dữ liệu thử nghiệm**, rồi đặt lại *Bắt đầu chạy thử* là 08:00 ngày 04/11.

## Trong thời gian thi

- **Mỗi ngày xuất Excel một lần** để lưu bản sao (bản free của Supabase không có sao lưu tự động).
- Gặp sự cố, bật **Tạm dừng khẩn cấp** trong Cài đặt: trang thi khóa ngay, người đang làm dở vẫn nộp được bài.
- Supabase bản free tự tạm dừng dự án nếu **7 ngày** không có truy cập. Trong thời gian thi không lo việc này, nhưng nếu dựng xong mà để lâu mới thi thì vào trang quản trị một lần trước ngày thi.
