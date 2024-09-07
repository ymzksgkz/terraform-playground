variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_id" {
  type      = string
  nullable  = false
}

variable "common_tags" {
  type      = map(string)
  default   = {
    Name = "terraform"
    Env  = "dev"
  }
}