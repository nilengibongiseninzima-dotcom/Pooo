# DigitalOcean Variables
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

# Oracle Cloud Variables
variable "tenancy_ocid" {
  description = "Oracle Tenancy OCID"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "Oracle User OCID"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Oracle API Key Fingerprint"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to Oracle Private Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Oracle Cloud Region"
  type        = string
  default     = "eu-frankfurt-1" # Close to South Africa
}
