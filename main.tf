# ------------------------------------------------------------------------------
# Google VPC Network
# ------------------------------------------------------------------------------
module "google-vpc-pg1" {
  source = "git::https://github.com/joeriverhavert/terraform-modules.git//google-cloud/google-vpc-network"

  name        = "sbx-pg1"
  description = "SBX Playground 1 VPC"

  subnets = {
    "sbx-pg1-subnet" = {
      description   = "SBX Playground 1 Subnet"
      ip_cidr_range = "172.16.0.0/18"
      stack_type    = "IPV4_ONLY"
    }
  }

  firewall-rules = {
    "allow-imcp" = {
      description = "Allow IMCP traffic"

      allow = {
        protocol = "icmp"
      }

      source_ranges = ["172.18.0.0/18"]
    },
    "allow-ssh-cloudshell" = {
      description = "Allow ssh connections from the cloudshell."

      allow = {
        protocol = "TCP"
        ports    = ["22"]
      }

      source_ranges = ["35.235.240.0/20"]
    }
  }

  router = {
    name        = "vpc-pg1-sbx-router"
    description = "VPC Playground 1 SBX Router"
    enable_nat  = false
    bgp = {
      asn = 64514
    }
  }

  region  = var.region
  project = var.project
}


module "google-vpc-pg2" {
  source = "git::https://github.com/joeriverhavert/terraform-modules.git//google-cloud/google-vpc-network"

  name        = "lab-pg2"
  description = "LAB Playground 2 VPC"

  subnets = {
    "lab-pg2-subnet" = {
      description   = "LAB Playground 2 Subnet"
      ip_cidr_range = "172.18.0.0/18"
      stack_type    = "IPV4_ONLY"
    }
  }

  firewall-rules = {
    "allow-imcp" = {
      description = "Allow IMCP traffic"

      allow = {
        protocol = "icmp"
      }

      source_ranges = ["172.16.0.0/18"]
    },
    "allow-ssh-cloudshell" = {
      description = "Allow ssh connections from the cloudshell."

      allow = {
        protocol = "TCP"
        ports    = ["22"]
      }

      source_ranges = ["35.235.240.0/20"]
    }
  }

  router = {
    name        = "vpc-pg2-lab-router"
    description = "VPC Playground 2 LAB Router"
    enable_nat  = false
    bgp = {
      asn = 64515
    }
  }

  region  = var.peer_region
  project = var.peer_project
}

# # ------------------------------------------------------------------------------
# # Google HA VPN
# # ------------------------------------------------------------------------------
module "google-ha-vpn-pg1" {
  source = "git::https://github.com/joeriverhavert/terraform-modules.git//google-cloud/google-ha-vpn"

  name    = "ha-vpn-pg1"
  network = module.google-vpc-pg1.network.id
  router  = module.google-vpc-pg1.router.name

  gateway_name = "ha-vpn-gateway-pg1"
  peer_gateway = module.google-ha-vpn-pg2.ha_vpn_gateway.self_link

  tunnels = {
    "tunnel1" = {
      bgp = {
        ip_address      = "169.254.36.149"
        peer_ip_address = "169.254.36.150"
      }
      gateway_interface = 0
      shared_secret   = "joerihasasecret"
    },
    "tunnel2" = {
      bgp = {
        ip_address      = "169.254.46.149"
        peer_ip_address = "169.254.46.150"
      }
      gateway_interface = 1
      shared_secret = "joerihasanothersecret"
    }
  }

  router_peer = {
    peer_asn                  = 64515
    advertised_route_priority = 0
  }

  region  = var.region
  project = var.project
}

module "google-ha-vpn-pg2" {
  source = "git::https://github.com/joeriverhavert/terraform-modules.git//google-cloud/google-ha-vpn"

  name    = "ha-vpn-pg2"
  network = module.google-vpc-pg2.network.id
  router  = module.google-vpc-pg2.router.name

  gateway_name = "ha-vpn-gateway-pg2"
  peer_gateway = module.google-ha-vpn-pg1.ha_vpn_gateway.self_link

  tunnels = {
    "tunnel1" = {
      bgp = {
        ip_address      = "169.254.36.150"
        peer_ip_address = "169.254.36.149"
      }
      gateway_interface = 0
      shared_secret   = "joerihasasecret"
    },
    "tunnel2" = {
      bgp = {
        ip_address      = "169.254.46.150"
        peer_ip_address = "169.254.46.149"
      }
      gateway_interface = 1
      shared_secret = "joerihasanothersecret"
    }
  }

  router_peer = {
    peer_asn                  = 64514
    advertised_route_priority = 0
  }

  region  = var.peer_region
  project = var.peer_project
}

# # ------------------------------------------------------------------------------
# # Google Test Instances
# # ------------------------------------------------------------------------------
resource "google_compute_instance" "pg1-instance" {
  name         = "pg1-instance"
  machine_type = "n2-standard-2"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = module.google-vpc-pg1.network.id
    subnetwork = module.google-vpc-pg1.subnetworks["sbx-pg1-subnet"].id
  }

  project = var.project
}

resource "google_compute_instance" "pg2-instance" {
  name         = "pg2-instance"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = module.google-vpc-pg2.network.id
    subnetwork = module.google-vpc-pg2.subnetworks["lab-pg2-subnet"].id
  }
  
  project = var.peer_project
}