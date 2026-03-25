resource "aws_sns_topic" "incident_alarm_topic" {
  name = "${var.name_prefix}-incident-alarms"
  tags = var.tags
}
