provider "google" {
  project = "xxxxxxxxxxxxxxxx"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# Variables
variable "region" {
  default = "us-central1"
}

# Backend Instances
resource "google_compute_instance" "backend" {
  count        = 2
  name         = "backend-${count.index}"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  tags = ["backend"]

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    echo "Hello from Backend ${count.index}" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOT
}

# Load Balancer
resource "google_compute_address" "lb_address" {
  name = "load-balancer-address"
}

resource "google_compute_target_pool" "lb_pool" {
  name        = "backend-pool"
  instances   = google_compute_instance.backend[*].self_link
  health_checks = [google_compute_http_health_check.lb_health_check.self_link]
}

resource "google_compute_http_health_check" "lb_health_check" {
  name               = "health-check"
  request_path       = "/"
  port               = 80
  check_interval_sec = 10
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3
}

resource "google_compute_forwarding_rule" "lb_forwarding_rule" {
  name       = "load-balancer"
  target     = google_compute_target_pool.lb_pool.self_link
  port_range = "80"
  ip_address = google_compute_address.lb_address.address
}

# Firewall Rules
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["backend"]
}

# Outputs
output "lb_ip_address" {
  description = "Load Balancer IP Address"
  value       = google_compute_address.lb_address.address
}

output "backend_instances" {
  description = "Backend Instance External IPs"
  value       = google_compute_instance.backend[*].network_interface[0].access_config[0].nat_ip
}
