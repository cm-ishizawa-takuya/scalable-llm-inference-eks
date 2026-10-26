variable "gpu_instance_types" {
  description = "EC2 instance types the GPU NodePool may launch."
  type        = list(string)
  default     = ["g4dn.xlarge"]
}

variable "gpu_capacity_types" {
  description = "Capacity types in order of preference. Karpenter picks spot before on-demand when both are allowed."
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "gpu_limit" {
  description = "Maximum number of GPUs the NodePool may hold at once. Caps the cost of a runaway scale-out."
  type        = number
  default     = 2
}

variable "consolidate_after" {
  description = "How long a GPU node may sit empty before Karpenter removes it."
  type        = string
  default     = "1m"
}
