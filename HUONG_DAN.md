# Phần mềm Đánh giá nhận thức sau học tập Nghị quyết Hội nghị Trung ương 4 khóa XIV

Ban Tuyên giáo Tỉnh ủy Tuyên Quang. Chạy trên GitHub Pages và Supabase (gói Pro, máy chủ Small). **Phiên bản 3.1.**

## Cấu trúc thư mục

| File | Dùng để |
|---|---|
| `index.html` | Trang làm bài, kèm bảng xếp hạng (gửi link này đi) |
| `index.html#bang-xep-hang` | Trang Bảng xếp hạng (toàn bộ đảng bộ, bấm vào để xem từng cá nhân) |
| `index.html#trinh-chieu` | Màn hình trình chiếu bảng xếp hạng (TV, máy chiếu), tự làm mới 2 phút/lần |
| `admin.html` | Trang quản trị |
| `config.js` | Kết nối Supabase (đã điền sẵn) |
| `assets/` | Logo ngành Tuyên giáo, hoa văn trống đồng, hình nền Cột cờ Lũng Cú – Cây đa Tân Trào |
| `supabase/khoi_tao.sql` | Tạo và nâng cấp CSDL |
| `tools/CHAY_THU_TAI.bat` | Bấm đúp để thử tải |

## CẬP NHẬT PHIÊN BẢN 3.1 (05/11/2026)

Dành cho máy đã nâng cấp lên phiên bản 3. **Không xóa dữ liệu nào.**

1. Supabase > **SQL Editor > New query**: dán toàn bộ file `supabase/khoi_tao.sql` mới, bấm **Run** (chạy lại an toàn, chỉ thêm bảng đếm lượt truy cập và 2 hàm mới).
2. Lên GitHub, tải lên **thay thế** `index.html`, `admin.html` và thêm file mới `assets/trong-dong.webp`. File `config.js` giữ nguyên.
3. Mở trang, bấm Ctrl+F5.

Thay đổi:
- Thanh trên cùng có 2 tab **Trang chủ** và **Bảng xếp hạng**.
- Trang chủ có khối **Thống kê** (lượt truy cập, số người tham gia, số đơn vị kết nối, bài đã nộp, tỷ lệ đạt) và khối **Xếp hạng tham gia** (10 đơn vị đông người tham gia nhất).
- Trang **Bảng xếp hạng**: vinh danh 3 đơn vị dẫn đầu, bảng đủ 130 đảng bộ (lọc theo nhóm, tìm kiếm). Bấm vào đảng bộ để xem danh sách cá nhân xếp theo số câu đúng (bằng nhau thì ai làm nhanh hơn xếp trên). Muốn ẩn danh sách cá nhân thì bỏ chọn ô **"Công khai danh sách cá nhân"** trong Cài đặt.
- Danh mục tài liệu thu gọn, bấm để sổ xuống; ghi theo thể thức "Nghị quyết số 31-NQ/TW, ngày 15/10/2026 của…".
- Màn hình trình chiếu chuyển sang địa chỉ `index.html#trinh-chieu`.
- **Lượt truy cập** tính mỗi phiên trình duyệt một lần. Khi bấm **Xóa toàn bộ dữ liệu thử nghiệm**, lượt truy cập cũng được đếm lại từ 0.

## NÂNG CẤP LÊN PHIÊN BẢN 3 (làm một lần, trước 08:00 ngày 09/11)

1. Supabase > **SQL Editor > New query**: dán toàn bộ file `supabase/khoi_tao.sql`, bấm **Run**. Thấy dòng *"Đã nâng cấp dữ liệu lên phiên bản 3"* là xong. Lần chạy đầu tiên này sẽ:
   - thay toàn bộ câu hỏi bằng **bộ 65 câu** thuộc 6 chuyên đề;
   - đặt lại cài đặt: Ban Tuyên giáo Tỉnh ủy Tuyên Quang; 120 phút; đạt từ 70% (46/65 câu); tối đa 3 lần, lấy kết quả cao nhất; không đảo câu hỏi, đáp án; chạy thử **ngay từ lúc nâng cấp**; chính thức **08:00 ngày 09/11 đến 22:00 ngày 15/11/2026**;
   - nạp danh mục 6 tài liệu;
   - **xóa toàn bộ bài thi cũ** (đều là dữ liệu thử).

   Danh sách 130 đảng bộ và tài khoản quản trị giữ nguyên. Các lần chạy lại về sau **không xóa, không ghi đè gì**.
2. Lên GitHub, xóa file cũ `assets/logo.png`, rồi tải lên **thay thế** các file: `index.html`, `admin.html`, toàn bộ thư mục `assets/` (các file logo `logo-tuyen-giao-…` và `nen-tuyen-quang.svg`). File `config.js` giữ nguyên.
3. Mở trang thi, bấm Ctrl+F5. Thấy logo Tuyên giáo, nhãn "Đang chạy thử" và 65 câu là đúng.

## Bảng xếp hạng

- **Cách xếp:** theo **số người tham gia** của đảng bộ (mỗi người chỉ tính một lần), cùng số người thì so **tổng số câu trả lời đúng** (kết quả cao nhất của mỗi người).
- **Hiển thị ở 4 chỗ:**
  1. **Trang chủ**: 10 đơn vị dẫn đầu; nút "Xem toàn bộ danh sách đơn vị" mở tab **Bảng xếp hạng** (đủ 130 đảng bộ, bấm vào từng đảng bộ để xem cá nhân).
  2. **Màn hình kết quả**: báo cho người vừa thi biết đảng bộ của mình đang xếp thứ mấy.
  3. **Màn hình trình chiếu** `…/index.html#trinh-chieu`: chữ to, tự làm mới, dùng cho giao ban hoặc màn hình tại hội trường.
  4. **Trang quản trị** và **file Excel** (sheet "Xếp hạng", có bình quân câu đúng/người và tỷ lệ đạt).
- Số liệu tự cập nhật **2 phút một lần**, nên dù đông người xem cũng không làm nặng máy chủ.
- Danh sách cá nhân (họ tên, chức vụ, đơn vị, số câu đúng, đạt/chưa đạt) chỉ hiện khi bật "Công khai danh sách cá nhân" trong Cài đặt (mặc định bật).
- Trong thời gian chạy thử, bảng hiện số liệu thử và có ghi chú "số liệu chạy thử".

## Cách phần mềm hoạt động

- Câu hỏi hiện **theo từng chuyên đề** (6 văn bản), **giữ nguyên thứ tự câu hỏi và phương án A/B/C** như trong bộ đề (câu 1 đến câu 65). Muốn đảo thứ tự câu thì bật ô "Đảo thứ tự câu hỏi" trong Cài đặt.
- Trên máy tính, danh sách câu hỏi nằm bên phải, chia theo chuyên đề. Trên điện thoại, mỗi màn một câu, danh sách câu nằm phía dưới. Trên máy tính có thể dùng phím ← → để chuyển câu, phím A/B/C để chọn đáp án.
- **Đáp án chỉ nằm trên máy chủ**, máy chủ chấm điểm.
- **Tối đa 3 lần làm bài.** Tổng hợp lấy kết quả cao nhất. Cùng một người được nhận diện bằng họ tên + đảng bộ + đơn vị.
- **Bài đang làm được lưu trên máy.** Mất mạng thì có dấu báo "Mất mạng – bài vẫn được lưu". Lúc nộp bài tự thử lại khi mạng chập chờn. Còn 10 phút và 5 phút thì có nhắc nhở, hết 120 phút thì tự nộp.
- Nút **Mã QR trang** tạo mã QR để in hoặc gửi cho các chi bộ quét.

## Trang quản trị

- **Tổng hợp:** số tham gia, đạt, không đạt theo 130 đảng bộ (tách lãnh đạo, không lãnh đạo), kèm bảng xếp hạng.
- **Câu hỏi:** thêm, sửa, bật/tắt câu hỏi; xem tỷ lệ trả lời đúng; chấm lại khi sửa đáp án. Muốn thêm câu vào một chuyên đề thì ô "Chuyên đề" phải gõ **đúng tên** chuyên đề đó (có sẵn danh sách gợi ý).
- **Cài đặt:** thời gian, tỷ lệ đạt, số lần, mốc giờ, **danh mục tài liệu** (mỗi dòng một văn bản, dạng `Tên ngắn | Tên đầy đủ`), tạm dừng khẩn cấp, xóa dữ liệu thử.
- **Xuất Excel:** gồm các sheet Tổng hợp, Xếp hạng, Theo câu hỏi, và tùy chọn kèm Danh sách.

## Trước ngày thi

1. Nâng cấp như mục trên, rồi làm thử trên điện thoại thật (Android, iPhone, mở link trong Zalo) và trên máy tính.
2. Chạy `tools/CHAY_THU_TAI.bat` một lượt.
3. Xong: vào Cài đặt > **Xóa toàn bộ dữ liệu thử nghiệm**. Mốc chính thức 08:00 ngày 09/11 đã được cài sẵn.

## Trong thời gian thi

- Mỗi ngày xuất Excel một lần để lưu. Gói Pro còn có sao lưu tự động hằng ngày.
- Gặp sự cố: bật **Tạm dừng khẩn cấp** trong Cài đặt. Không bấm Pause hay Restart trong Supabase, và không đổi cấp máy chủ.
- Sau 22:00 ngày 15/11: xuất Excel lưu trữ. Chu kỳ tính phí Supabase kết thúc ngày 30/11. Nếu không dùng tiếp, hạ máy chủ về Micro rồi hạ gói về Free trước ngày đó.
