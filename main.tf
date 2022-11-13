terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token = var.ya[0]["token"]
  cloud_id  = var.ya[0]["cloud_id"] 
  folder_id = var.ya[0]["folder_id"]
  zone  = var.ya[0]["zone_def"]
}


#============================================================================================================================
resource "yandex_vpc_network" "network-nedomika" {
  name = "network-nedomika"
}
 
resource "yandex_vpc_subnet" "priv-1-subnet-nedomika" {
  name           = "priv-1-subnet-nedomika"
  #zone           = "ru-central1-a"
  route_table_id = yandex_vpc_route_table.priv2nat.id
  network_id     = yandex_vpc_network.network-nedomika.id
  v4_cidr_blocks = ["172.16.1.0/24"]
}

resource "yandex_vpc_subnet" "priv-2-subnet-nedomika" {
  name           = "priv-2-subnet-nedomika"
  zone           =  var.ya[0]["zone_alt"]
  route_table_id = yandex_vpc_route_table.priv2nat.id
  network_id     = yandex_vpc_network.network-nedomika.id
  v4_cidr_blocks = ["172.16.2.0/24"]
}

resource "yandex_vpc_subnet" "pub-subnet-nedomika" {
  name           = "pub-subnet-nedomika"
  #zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-nedomika.id
  v4_cidr_blocks = ["172.16.254.0/24"]
}

resource "yandex_vpc_subnet" "bastion-subnet-nedomika" {
  name           = "bastion-subnet-nedomika"
  #zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-nedomika.id
  v4_cidr_blocks = ["192.168.0.0/24"]
}

############################# Создаем bastion bastion
resource "yandex_compute_instance" "bastion" {
  name = "bastion"
  hostname = "bastion.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 0.5
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8nfjfrki3b9ctrh50r"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.bastion-subnet-nedomika.id
    nat       = true

    security_group_ids = [
      yandex_vpc_security_group.bastion.id,
      yandex_vpc_security_group.egress_nat.id# Allow connections to and from the Data Proc cluster.
    ]
  }

  metadata = {
    user-data = var.user_data
  }

  scheduling_policy {
    preemptible = true
  }
 }
 
#=====nat===============================================================================================================

#Сервер nat
resource "yandex_compute_instance" "nat" {
  name = "nat"
  allow_stopping_for_update = true
  hostname = "nat.nedomika"
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 0.5
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8s7ahgh09sicem2dq7" #образ NAT-instance
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.pub-subnet-nedomika.id
    nat       = true
  }


  metadata = {
    user-data = var.user_data
  }

  scheduling_policy {
    preemptible = true
  }
 }

#==================
resource "yandex_vpc_route_table" "priv2nat" {
  name       = "priv2nat"
  network_id = yandex_vpc_network.network-nedomika.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address = yandex_compute_instance.nat.network_interface.0.ip_address
  }
}

#Сервера nginx ===========================================================================================================


resource "yandex_compute_instance" "web-1" {
  name = "web-1"
  #### фиксируем fqdn
  hostname = "web-1.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 0.5
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8nfjfrki3b9ctrh50r"
      #image_id = "fd83clk0nfo8p172omkn"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.priv-1-subnet-nedomika.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.all_ingress_ssh.id,
      yandex_vpc_security_group.egress_nat.id,
      yandex_vpc_security_group.incom_web.id

    ]
  }
 
  metadata = {
    user-data = var.user_data
  }
  
  scheduling_policy {
    preemptible = true
  }
}

resource "yandex_compute_instance" "web-2" {

  name = "web-2"
  zone = var.ya[0]["zone_alt"]
  hostname = "web-2.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 0.5
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8nfjfrki3b9ctrh50r"
      #image_id = "fd83clk0nfo8p172omkn"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.priv-2-subnet-nedomika.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.all_ingress_ssh.id,
      yandex_vpc_security_group.egress_nat.id,
      yandex_vpc_security_group.incom_web.id
    ]
  }
 
  metadata = {
    user-data = var.user_data
  }
  
  scheduling_policy {
    preemptible = true
  }
}

 
############################# Создаем таргет группу и добавляем созданные ВМ web===========================================
resource "yandex_alb_target_group" "diplom_atg" {
  name      = "diplom-atarget-group"
  #region_id = "ru-central1"
  #count = var.instance_count 
  target {
    subnet_id = yandex_vpc_subnet.priv-1-subnet-nedomika.id
    ip_address = yandex_compute_instance.web-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.priv-2-subnet-nedomika.id
    ip_address = yandex_compute_instance.web-2.network_interface.0.ip_address
  }
}

############################# Создаем бэкенд группу и добавляем таргет группу

resource "yandex_alb_backend_group" "diplom_abg" {
  name      = "diplom-abackend-group"

  http_backend {
    name = "test-http-backend"
    weight = 1
    port = 80
    target_group_ids = ["${yandex_alb_target_group.diplom_atg.id}"]
    load_balancing_config {
      panic_threshold = 50
    }    
    healthcheck {
      timeout = "1s"
      interval = "1s"
      http_healthcheck {
        path  = "/"
      }
    }
  }
}

############################# Создаем HTTP-роутер
resource "yandex_alb_http_router" "diplom-hr" {
  name   = "diplom-http-router"
  labels = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}
############################# Создаем вирт хост для балансера
resource "yandex_alb_virtual_host" "diploma-vh" {
  name           = "diplom-virtual-host"
  http_router_id = yandex_alb_http_router.diplom-hr.id
  route {
    name = "diplom-route"
    http_route {
      http_route_action {
        backend_group_id = "${yandex_alb_backend_group.diplom_abg.id}"
        timeout          = "3s"
      }
    }
  }
}   

############################# Создаем L7-балансировщик
resource "yandex_alb_load_balancer" "diploma-balancer" {
  name        = "diploma-load-balancer"

  network_id  = yandex_vpc_network.network-nedomika.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.pub-subnet-nedomika.id
    }
  }

  listener {
    name = "diploma-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [ 80 ]
    }    
    http {
      handler {
        http_router_id = yandex_alb_http_router.diplom-hr.id
      }
    }
  }    
}
############################# Создаем Сервер Prometheus
resource "yandex_compute_instance" "monitor" {
  name = "monitor"
  hostname = "monitor.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 0.5
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8nfjfrki3b9ctrh50r"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.priv-1-subnet-nedomika.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.all_ingress_ssh.id,
      yandex_vpc_security_group.egress_nat.id,
      yandex_vpc_security_group.incom_monitor.id

      
    ]
  }
 
  metadata = {
    user-data = var.user_data
  }
  scheduling_policy {
    preemptible = true
  }
 }
 
############################# Создаем Сервер Grafana
resource "yandex_compute_instance" "grafana" {
  name = "grafana"
  hostname = "grafana.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 1
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd8nfjfrki3b9ctrh50r"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.pub-subnet-nedomika.id
    nat       = true
    security_group_ids = [
      yandex_vpc_security_group.all_ingress_ssh.id,
      yandex_vpc_security_group.egress_nat.id,
      yandex_vpc_security_group.incom_grafana.id
    ]
  }
 
  metadata = {
    user-data = var.user_data
  }

  scheduling_policy {
    preemptible = true
  }
 }

############################# Создаем Сервер Elasticsearc
resource "yandex_compute_instance" "elastic" {
  name = "elastic"
  hostname = "elastic.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 1
  }
 
  boot_disk {
    initialize_params {
      image_id = "fd83clk0nfo8p172omkn"
      #image_id = "fd8nfjfrki3b9ctrh50r"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.priv-1-subnet-nedomika.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.all_ingress_ssh.id,
      yandex_vpc_security_group.egress_nat.id,
      yandex_vpc_security_group.incom_elastic.id
    ]
  }
 
  metadata = {
    user-data = var.user_data
  }

  scheduling_policy {
    preemptible = true
  }
 }
############################# Создаем Сервер kibana
resource "yandex_compute_instance" "kibana" {
  name = "kibana"
  hostname = "kibana.nedomika"
  allow_stopping_for_update = true
  platform_id = "standard-v2"
  resources {
    core_fraction = 5
    cores  = 2
    memory = 1
  }
 
  boot_disk {
    initialize_params {
      #image_id = "fd8nfjfrki3b9ctrh50r"
      image_id = "fd83clk0nfo8p172omkn"
    }
  }
 
  network_interface {
    subnet_id = yandex_vpc_subnet.pub-subnet-nedomika.id
    nat       = true
    security_group_ids = [
      yandex_vpc_security_group.all_ingress_ssh.id,
      yandex_vpc_security_group.egress_nat.id,
      yandex_vpc_security_group.incom_kibana.id
    ]
  }
 
  metadata = {
    user-data = var.user_data
  }

  scheduling_policy {
    preemptible = true
  }
 }

###############

