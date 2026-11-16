variable "name" {
  description = "Name of the Lambda function, its roles and its schedule."
  type        = string
  default     = "weather-ingest"
}

variable "source_dir" {
  description = "Directory with the Python package (contains weather_ingest/)."
  type        = string
}

variable "stations" {
  description = "SwissMetNet station codes to ingest, e.g. [\"klo\", \"bas\"]."
  type        = list(string)

  validation {
    condition = (
      length(var.stations) > 0
      && alltrue([for s in var.stations : can(regex("^[a-z]{3}$", s))])
    )
    error_message = "Stations must be three lowercase letters, e.g. klo."
  }
}

variable "schedule_expression" {
  description = "When the ingest runs, in the time zone below."
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "schedule_timezone" {
  description = "Time zone of the schedule expression."
  type        = string
  default     = "Europe/Zurich"
}

variable "retention_days" {
  description = "Days after which stored files expire."
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "Days to keep the Lambda logs."
  type        = number
  default     = 14
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket. The data is public and can be fetched again."
  type        = bool
  default     = false
}
