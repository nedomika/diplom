#Создаем файл index.html.j2 для веб серверов с отображением IP адреса сервера и пудличнвми ссылками сервера Grafana и Kibana (данные из vars.tf)
resource "local_file" "index_j2" {
    content     = <<EOF
    CPU<br>
    {{ ansible_processor }}<br>
    --------------<br>
    RAM<br>
    {{ ansible_memory_mb.real.total }}<br>
    ---------------<br>
    ip <br><h1>
    {{ ansible_default_ipv4.address }}</h1><br>
    ---------------<br>
    <a href="http://${yandex_alb_load_balancer.diploma-balancer.listener[0].endpoint[0].address[0].external_ipv4_address[0].address}:80">BALANCER http server</a>
    ---------------<br>
    <a href="http://${local.exip_grafana}:3000">Grafana server</a>
    ---------------<br>
    <a href="http://${local.exip_kibana}:5601">Kibana server</a>
    EOF
    filename = "./roles/nginx/templates/index.j2"
}
### Создаем #Создаем файл host.ini для ansible с возсожностью подключения ко всем серверам через прокси ssh сервера бастион (данные из vars.tf)
### https://www.redhat.com/sysadmin/ssh-proxy-bastion-proxyjump
resource "local_file" "ssh_config" {
    content     = <<EOF
    [web]
    web-1.nedomika ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${var.password[0]["linux_user"]}@${local.exip_bastion}"'
    web-2.nedomika ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${var.password[0]["linux_user"]}@${local.exip_bastion}"'
    [monitor]
    monitor.nedomika ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${var.password[0]["linux_user"]}@${local.exip_bastion}"'
    [grafana]
    grafana.nedomika ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${var.password[0]["linux_user"]}@${local.exip_bastion}"'
    [elastic]
    elastic.nedomika ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${var.password[0]["linux_user"]}@${local.exip_bastion}"'
    [kibana]
    kibana.nedomika ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=accept-new -p 22 -W %h:%p -q ${var.password[0]["linux_user"]}@${local.exip_bastion}"'
    [bastion]
    ${local.exip_bastion}
    EOF
    filename = "./enventory.ini"
}
### Создание файла ГЛОБАЛЬНЫХ ansible переменных с паролями для сервисов и именем пользователя linux  (данные из vars.tf)
resource "local_file" "password_yml" {
    content     = <<EOF
    elastic_pass: ${var.password[0]["elastic_pass"]}
    filebeat_user: ${var.password[0]["filebeat_user"]}
    filebeat_user_role: ${var.password[0]["filebeat_user_role"]}
    filebeat_user_pass: ${var.password[0]["filebeat_user_pass"]}
    kibana_system_pass: ${var.password[0]["kibana_system_pass"]}
    grafana_password: ${var.password[0]["grafana_password"]}
    linux_user: ${var.password[0]["linux_user"]}    
    EOF
    filename = "./group_vars/all/password.yml"
}
### Создание файла ansible переменных c ID загрузочных дисков созданных в YC (для создания ссценария создания снэпшотов) (данные из vars.tf)
resource "local_file" "yc_disk_yaml" {
    content     = <<EOF
---
# vars file for roles/bastion
web_1: ${yandex_compute_instance.web-1.boot_disk.0.disk_id}
web_2: ${yandex_compute_instance.web-2.boot_disk.0.disk_id}
monitor: ${yandex_compute_instance.monitor.boot_disk.0.disk_id}
grafana: ${yandex_compute_instance.grafana.boot_disk.0.disk_id}
elastic: ${yandex_compute_instance.elastic.boot_disk.0.disk_id}
kibana: ${yandex_compute_instance.kibana.boot_disk.0.disk_id}
bastion: ${yandex_compute_instance.bastion.boot_disk.0.disk_id}
nat: ${yandex_compute_instance.nat.boot_disk.0.disk_id}
snapshot_schedule: ${var.snapshot_schedule}
EOF
    filename = "./roles/bastion/vars/main.yml"
}
### Создание файла конфигурации дл YC CLI (данные из vars.tf)
resource "local_file" "yc_config_j2" {
    content     = <<EOF
current: default
profiles:
  default:
    token: ${var.ya[0]["token"]}
    cloud-id: ${var.ya[0]["cloud_id"]}
    folder-id: ${var.ya[0]["folder_id"]}
    compute-default-zone: ${var.ya[0]["zone_def"]}
EOF
    filename = "./roles/bastion/templates/yc_config.j2"
}
### вывод в консоль всех IP адресов серверов и балансера
output "internal_ip_address_WEB-1" {
   description = "Internal IP addres of WEB servers"
  value = local.ip_web-1
}
output "internal_ip_address_WEB-2" {
   description = "Internal IP addres of WEB servers"
  value = local.ip_web-2
}
output "external_ip_address_grafana_balancer" {
  description = "External IP addres of load balancer"
  value = local.exip_lb
} 
output "internal_ip_address_monitor" {
  description = "Internal IP addres of MONITOR server"
  value = local.ip_monitor
  }
output "external_ip_address_grafana" {
  description = "External IP addres of grafana server"
  value = local.exip_grafana
}
output "internal_ip_address_grafana" {
  description = "Internal IP addres of grafana server"
  value = local.ip_grafana
}
output "internal_ip_address_Elastic" {
  description = "Internal IP addres of Elastic server"
  value = local.ip_elastic
}
output "external_ip_address_Kibana" {
  description = "External IPs addres of Kibana server"
  value = local.exip_kibana
}
output "internal_ip_address_Kibana" {
  description = "InternalIPs addressof Kibana server"
  value = local.ip_kibana
}
output "external_ip_address_bastion" {
  description = "External IP addres of Kibana server"
  value = local.exip_bastion
}