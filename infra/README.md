# infra: Terraform + Ansible (Tuần 3)

Terraform tạo 3 EC2 t3.small + Security Group + Elastic IP cho server, rồi tự sinh `ansible/inventory.ini`.
Ansible cài k3s (1 server, 2 agent), bật swap, gắn nhãn `region=...`, cài Helm, tạo namespace + quota.

| Node | Vai trò | Nhãn region |
|---|---|---|
| server | control plane + worker | us-east |
| agent1 | worker | eu-west |
| agent2 | worker | ap-southeast |

## 0. Chuẩn bị (Windows)
Ansible không chạy trên Windows thuần -> dùng **WSL Ubuntu** cho cả Terraform lẫn Ansible.

    wsl --install -d Ubuntu          # PowerShell (Admin), khởi động lại máy rồi mở Ubuntu

Trong Ubuntu (WSL):

    sudo apt update && sudo apt install -y python3-pip pipx unzip curl gnupg software-properties-common
    pipx install --include-deps ansible && pipx ensurepath
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform

**Quan trọng:** copy thư mục `infra` vào home của WSL (`cp -r /mnt/c/.../infra ~/infra`), KHÔNG chạy trong `/mnt/c/...`.
Ansible bỏ qua `ansible.cfg` ở thư mục ai cũng ghi được, và SSH key không chmod được trên ổ Windows.

## 1. Khóa SSH và thông tin AWS
1. Learner Lab -> **AWS Details** -> Download PEM (`labsuser.pem`).
2. Trong WSL: `mkdir -p ~/.ssh && cp /mnt/c/Users/<ban>/Downloads/labsuser.pem ~/.ssh/ && chmod 600 ~/.ssh/labsuser.pem`
3. Learner Lab -> **AWS Details -> AWS CLI: Show**, rồi dán 3 dòng vào WSL (đổi mỗi phiên lab):

       export AWS_ACCESS_KEY_ID=...
       export AWS_SECRET_ACCESS_KEY=...
       export AWS_SESSION_TOKEN=...

## 2. Terraform (state nằm trên S3)
State dùng chung giữa máy bạn và GitHub Actions, nên phải lưu trên S3.

    cd ~/config-repo/infra/terraform
    ./bootstrap-state.sh                              # tạo bucket + backend.hcl (chỉ làm 1 lần)
    cp terraform.tfvars.example terraform.tfvars      # sửa admin_cidr = "<IP-của-bạn>/32"
    terraform init -migrate-state -backend-config=backend.hcl     # trả lời "yes" để chuyển state cũ lên S3
    terraform plan        # phải thấy: KHÔNG tạo/xóa máy nào (chỉ forget local_file.inventory)
    terraform apply
    ../ansible/refresh-inventory.sh                   # ghi lại ansible/inventory.ini

Số node mỗi site nằm trong `nodes.auto.tfvars.json` (optimiser sẽ ghi file này, bạn duyệt qua Pull Request).

## 3. Ansible

    cd ~/infra/ansible
    ansible all -m ping                              # 3 node phải trả "pong"
    ansible-playbook site.yml                        # ~5-8 phút

## 4. Kiểm tra cụm

    export KUBECONFIG=~/infra/ansible/kubeconfig
    kubectl get nodes --show-labels                  # 3 node Ready, có region=us-east / eu-west / ap-southeast
    kubectl get ns                                   # có realtime-chat, web-api, analytics
    kubectl describe quota -n web-api

## Sau khi lab tắt / bật lại
- Instance bị stop; Elastic IP của server giữ nguyên, IP public của 2 agent đổi.
- Vào lại lab, export lại 3 biến AWS, rồi: `ansible/refresh-inventory.sh` (đọc IP mới từ state) và `ansible all -m ping`.
- Hết buổi: dừng instance trong console, hoặc `terraform destroy` nếu không cần nữa.

## Gỡ lỗi nhanh
- `Permission denied (publickey)`: sai đường dẫn `ssh_key_path` hoặc chưa `chmod 600`.
- `ansible.cfg` bị bỏ qua: bạn đang ở `/mnt/c/...`, hãy chuyển vào home của WSL.
- Agent không join: xem `sudo journalctl -u k3s-agent -n 50` trên agent; kiểm tra SG có rule "self" (all traffic).
- `UnauthorizedOperation`: credentials Learner Lab hết hạn, hãy export lại.

## 5. Thêm / bớt node bằng Pull Request

    sửa infra/terraform/nodes.auto.tfvars.json  ->  mở PR  ->  CI comment kết quả `terraform plan`
        ->  bạn đọc, bấm Merge (GitHub gửi email báo PR)  ->  CI chạy `terraform apply`
        ->  trên máy bạn: ansible/join-new-nodes.sh  (cài k3s, gắn nhãn region, node mới nhận pod)

Cài đặt một lần: repo cần `.github/workflows/terraform.yml`, và trong Settings -> Secrets and variables -> Actions:

| Loại | Tên | Giá trị |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | 3 giá trị từ Learner Lab (đổi mỗi phiên) |
| Variable | `TF_STATE_BUCKET` | tên bucket do `bootstrap-state.sh` in ra |
| Variable | `ADMIN_CIDR` | `IP-của-bạn/32` (cùng giá trị trong terraform.tfvars) |
| Variable | `TF_VERSION` | kết quả `terraform version` trên máy bạn (tránh lệch phiên bản state) |

Lưu ý:
- Credentials Learner Lab hết hạn: job báo lỗi thì dán bộ mới vào secrets rồi bấm Re-run.
- Bớt node: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`, sau đó merge PR; CI từ chối tự xóa máy,
  hãy chạy tay workflow (Actions -> terraform -> Run workflow, allow_destroy = true), rồi `kubectl delete node <node>`.
- Ansible không chạy trong CI vì Security Group chỉ cho IP của bạn vào SSH.
