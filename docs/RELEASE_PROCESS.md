# Quy trình Build & Release Portmaster

Tài liệu nội bộ quy định các bước release phiên bản mới. AI agent/developer đọc và thực hiện tuần tự khi được yêu cầu "release bản mới".

---

## 1. Nguyên tắc cốt lõi

- **Chỉ git tag dạng `v*` mới kích hoạt tạo GitHub Release** (job `publish-release` trong `.github/workflows/release.yml` có điều kiện `if: startsWith(github.ref, 'refs/tags/v')`).
- Push nhánh `development` hay `main` **chỉ build test artifact**, KHÔNG tạo GitHub Release.
- Tag phải trỏ vào commit đã hoàn tất thay đổi. Không được reuse tag cũ.
- Format tag: `v<Major>.<Minor>.<Patch>` (ví dụ: `v2.2.12`, `v2.2.13`).

---

## 2. Các bước thực hiện Release

### Bước 1: Kiểm tra trạng thái Git
Đảm bảo working directory sạch và đã pull mới nhất:
```bash
git status
git fetch --tags origin
```

### Bước 2: Kiểm tra phiên bản mới nhất hiện tại
Lấy tag mới nhất trên remote:
```bash
git tag -l "v*" --sort=-v:refname | head -n 5
```
Ví dụ: tag mới nhất là `v2.2.12` → bản tiếp theo sẽ là `v2.2.13`.

### Bước 3: Cập nhật dependency nếu có sửa file Go
Nếu sửa `go.mod` (nâng/hạ version thư viện), bắt buộc đồng bộ `go.sum` trước khi commit:
```bash
docker run --rm -u $(id -u):$(id -g) -e HOME=/tmp \
  -v "$(pwd)":/work -w /work golang:1.26-alpine \
  sh -c "go mod tidy"
```
Verify build local qua Docker:
```bash
docker run --rm -u $(id -u):$(id -g) -e HOME=/tmp \
  -v "$(pwd)":/work -w /work golang:1.26-alpine \
  sh -c "go build -o /dev/null ./cmds/portmaster-core"
```

### Bước 4: Commit và push code lên nhánh làm việc
```bash
git add -A
git commit -m "feat/fix: <mô tả thay đổi>"
git push origin development
```

### Bước 5: Tạo tag và push tag để kích hoạt Release
```bash
# Thay X bằng số patch kế tiếp (ví dụ v2.2.13)
NEXT_TAG="v2.2.13"

git tag $NEXT_TAG
git push origin $NEXT_TAG
```

### Bước 6: Kiểm tra xác nhận
```bash
git ls-remote --tags origin $NEXT_TAG
```

Sau khi push tag, GitHub Actions sẽ:
1. `Build Core Artifacts` (Earthly: portmaster-core, start, hub, tauri app)
2. `Build Linux Package (deb/rpm)`
3. `Build Windows Package (NSIS)`
4. `Publish GitHub Release`: Tải tất cả file `.deb`, `.rpm`, `.exe`, `.msi`, `.zip` lên GitHub Release tương ứng với tag.

---

## 3. Checklist cho AI agent trước khi trả lời user

- [ ] Đã xác định đúng tag kế tiếp (tăng patch version).
- [ ] Working tree clean, commit đầy đủ cả `go.mod` và `go.sum` (nếu có thay đổi Go deps).
- [ ] Push code lên branch trước, push tag sau.
- [ ] Kiểm tra `git ls-remote --tags origin` để chắc chắn tag đã lên remote.
- [ ] Cung cấp cho user link/tên tag vừa push để user theo dõi trên GitHub Actions.
