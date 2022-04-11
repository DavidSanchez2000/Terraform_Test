# ------------------------------------------------------------------------------
# LAUNCH A POSTGRES CLOUD SQL PRIVATE IP INSTANCE
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# CREATE COMPUTE NETWORKS
# ------------------------------------------------------------------------------
# Simple network, auto-creates subnetworks\

terraform {
  backend "remote"{
      hostname = "app.terraform.io"
      organization = "Terraform_Database"

    workspaces {
      name = "test-database"
    }
  }
}

provider "google" {
    credentials = var.GCP_SERVICES
    project = var.project
    region = var.region
    zone = var.zone
}

provider "google-beta" {
    credentials = var.GCP_SERVICES
    project = var.project
    region = var.region
    zone = var.zone
  
}

resource "google_compute_network" "private_network" {
    #provider = var.provider
    name     = var.network_name
    routing_mode = "GLOBAL"
    auto_create_subnetworks = "false"
}


# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address" {
    #provider = var.provider
    name          = "private_ip_addres"
    purpose       = "VPC_PEERING"
    address_type  = "INTERNAL"
    ip_version    = "IPV4"
    prefix_length = 20
    network       =  google_compute_network.private_network.self_link #google_compute_network.private_network.self_link
}


# Establish VPC network peering connection using the reserved address range
resource "google_service_networking_connection" "private_vpc_connection" {
   #provider = var.provider
    network                 = google_compute_network.private_network.self_link #google_compute_network.private_network.self_link
    service                 = "servicenetworking.googleapis.com"
    reserved_peering_ranges =[google_compute_global_address.private_ip_address.name]  #[google_compute_global_address.private_ip_address.name]
}

#Firewall rules
resource "google_compute_firewall" "allow_ssh" {
  name        = "allow-ssh"
  network     = google_compute_network.private_network.name
  direction   = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["ssh-enabled"]

}

# ------------------------------------------------------------------------------
# CREATE DATABASE INSTANCE WITH PRIVATE IP
# ------------------------------------------------------------------------------

resource "google_sql_database" "database" {
    #provider = var.provider
    name = "main"
    instance = google_sql_database_instance.database_primary.name # google_sql_database_instance.database_primary.name

}

resource "google_sql_database_instance" "database_primary" {
    #provider = var.provider
    name = "database-primary"
    region = var.region
    database_version = "POSTGRES_13"
    depends_on = [
    google_service_networking_connection.private_vpc_connection#google_service_networking_connection.private_vpc_connection
    ]
    settings {
        tier = "db-f1-micro"
        availability_type = "REGIONAL"
        disk_size = 10
        ip_configuration{
            ipv4_enabled = false
            private_network = google_compute_network.private_network.self_link  #google_compute_network.private_network.self_link
        }
        
    }
}

resource "google_sql_user" "database_user" {
 name = var.database_user_name
 instance = google_sql_database_instance.database_primary.name  #google_sql_database_instance.database_primary.name
 password = var.database_password 
}

