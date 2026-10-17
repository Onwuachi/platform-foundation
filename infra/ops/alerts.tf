##############################
# Platform alerts (free tier)
# SNS email topic + EC2 status-check alarm for ops-01.
# Lives in the ops module so aws_instance.ops.id is in scope and the
# alarm follows the instance across rehydrates (the instance ID changes).
#
# Prerequisite (one time, outside Terraform):
#   aws ssm put-parameter --name /platform/alerts/email --type String \
#     --value '<your email>' --region us-east-1
##############################
data "aws_ssm_parameter" "alert_email" {
  name = "/platform/alerts/email"
}

resource "aws_sns_topic" "platform_alerts" {
  name = "platform-alerts"
}

# Stays "Pending confirmation" until the link in the confirmation email is clicked
resource "aws_sns_topic_subscription" "platform_alerts_email" {
  topic_arn = aws_sns_topic.platform_alerts.arn
  protocol  = "email"
  endpoint  = data.aws_ssm_parameter.alert_email.value
}

# Basic (5-minute) EC2 metrics are free; one alarm is inside the free 10.
# treat_missing_data = notBreaching keeps `platform down` (intentional stop)
# from paging. Trade-off: this catches hung/impaired instances, not a stopped one.
resource "aws_cloudwatch_metric_alarm" "ops_status_check" {
  alarm_name          = "ops-01-status-check-failed"
  alarm_description   = "ops-01 failed an EC2 system or instance status check"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = aws_instance.ops.id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.platform_alerts.arn]
  ok_actions          = [aws_sns_topic.platform_alerts.arn]
}
