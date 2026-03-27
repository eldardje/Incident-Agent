output "topic_arn" {
  description = "ARN of the incident alarm SNS topic."
  value       = aws_sns_topic.incident_alarm_topic.arn
}
