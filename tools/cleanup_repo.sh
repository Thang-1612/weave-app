#!/usr/bin/env bash
# Gỡ file không thuộc mã nguồn ra khỏi git. KHÔNG xóa file trên đĩa.
# Chạy ở thư mục gốc dự án, sau khi đã thêm gitignore_additions.txt vào .gitignore.
set -euo pipefail
for p in node_modules .firebase box_context.txt card_context.txt \
         shape_context.txt shape_kind.txt shape_matches.txt; do
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1 || [ -n "$(git ls-files "$p" 2>/dev/null)" ]; then
    git rm -r --cached -q "$p" && echo "đã gỡ khỏi git: $p"
  fi
done
echo "Xong. Kiểm tra bằng: git status"
