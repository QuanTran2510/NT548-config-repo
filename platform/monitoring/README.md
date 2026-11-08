# Monitoring (Prometheus + Grafana)

| What | Where | Port |
|---|---|---|
| Prometheus (UI, /targets) | pod on ap-southeast | NodePort 30900 |
| Grafana (dashboard "Placement optimiser vs cluster") | pod on ap-southeast | NodePort 30300 |
| node-exporter | every node (DaemonSet) | 9100 |
| kube-state-metrics | ap-southeast | 8080 |

Open `http://<server public ip>:30300` (user `admin`, password = the `grafana-admin` secret). The Security Group only lets
`admin_cidr` in. The RAM these pods request is reserved in the model (`reserved_mi` of ap-southeast in
`po/data.py`): if you change resources here, change it there too.
