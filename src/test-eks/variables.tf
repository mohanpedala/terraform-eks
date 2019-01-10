variable "env" {
  description = "Name of the environment"
  type        = "string"
}

variable "cluster-name" {
  description = "Name of EKS-Cluster"
  type        = "string"
}

variable "tag-name" {
  description = "Resource Tags"
  type        = "string"
}

variable "instance-type" {
  description = "Type of instances which should be created"
  type        = "string"
}
