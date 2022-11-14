##Созданем группы безопасности
  resource "yandex_vpc_security_group" "bastion" {
  name        = "bastion security group"
  description = "bastion security group"
  network_id  = yandex_vpc_network.network-nedomika.id
###### proxy ssh bastion
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24","172.16.254.0/24"]
    port      = 22
  }
}
###### входящий от бастиона ssh
  resource "yandex_vpc_security_group" "all_ingress_ssh" {
  name        = "all_ingress_ssh"
  description = "all_ingress_ssh"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["${local.ip_bastion}/32"]
    port           = 22
  }
}
### исходящий трафик для репозитариев через nat 
  resource "yandex_vpc_security_group" "egress_nat" {
  name        = "egress_nat"
  description = "egress_nat"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["0.0.0.0/0"]
    port      = 80
  }

  egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["0.0.0.0/0"]
    port      = 443 
  }
}

###### внешний вход на grafana
  resource "yandex_vpc_security_group" "incom_grafana" {
  name        = "local_internet_grafana"
  description = "local_internet_grafana"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }

  egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24","172.16.254.0/24"]
    from_port      = 0
    to_port        = 65535
  }
}
###### внешний вход на kibana
  resource "yandex_vpc_security_group" "incom_kibana" {
  name        = "ingress_kibana"
  description = "ingress_kibana"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }
    egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24","172.16.254.0/24"]
    from_port      = 0
    to_port        = 65535
  }
}

###### локальный трафик Прометиуса

  resource "yandex_vpc_security_group" "incom_monitor" {
  name        = "incom_monitor"
  description = "incom_monitor"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["${local.ip_grafana}/32"]
    port      = 9090
  }
    egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24","172.16.254.0/24"]
    from_port      = 0
    to_port        = 65535
  }
}
###### локальный трафик веб серверов
resource "yandex_vpc_security_group" "incom_web" {
  name        = "incom_web"
  description = "incom_web"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["${local.ip_monitor}/32"]
    port      = 9100
  }
  ingress  {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["${local.ip_monitor}/32"]
    port      = 4040
  }
  ingress {#########################
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["0.0.0.0/0"]
    port      = 80
  }
  egress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["172.16.1.0/24", "172.16.2.0/24","172.16.254.0/24"]
    from_port      = 0
    to_port        = 65535
  }
}
###### локальный трафик веб elastic

  resource "yandex_vpc_security_group" "incom_elastic" {
  name        = "incom_elastic"
  description = "incom_elastic"
  network_id  = yandex_vpc_network.network-nedomika.id
  
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["${local.ip_web-1}/32","${local.ip_web-2}/32"]
    port      = 9200
  }
  ingress {
    protocol       = "TCP"
    description    = " "
    v4_cidr_blocks = ["${local.ip_kibana}/32"]
    port      = 9200
  }
}