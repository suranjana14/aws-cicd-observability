locals {
  name       = "${var.service_name}-${var.environment}"
  enable_ecs = var.ecs_cluster_name != ""
  enable_alb = var.alb_arn_suffix != "" && var.target_group_arn_suffix != ""
}

data "aws_region" "current" {}

################################################################################
# Logs
################################################################################

resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.environment}/${var.service_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

# Backup signal that does not depend on EMF parsing: count 5xx straight from the JSON logs.
resource "aws_cloudwatch_log_metric_filter" "http_5xx" {
  name           = "${local.name}-http-5xx"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "{ $.status >= 500 }"

  metric_transformation {
    name          = "LogFiltered5xx"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
    dimensions = {
      Service = "$.Service"
    }
  }
}

resource "aws_cloudwatch_query_definition" "slowest_requests" {
  name            = "${local.name}/slowest-requests"
  log_group_names = [aws_cloudwatch_log_group.app.name]
  query_string    = <<-EOT
    fields @timestamp, Route, status, Latency, request_id, version, color
    | sort Latency desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "errors_by_version" {
  name            = "${local.name}/errors-by-version"
  log_group_names = [aws_cloudwatch_log_group.app.name]
  query_string    = <<-EOT
    filter status >= 500
    | stats count(*) as errors by version, color, Route
    | sort errors desc
  EOT
}

################################################################################
# Notifications
################################################################################

# CloudWatch alarms cannot publish to a topic encrypted with the AWS-managed
# alias/aws/sns key, so encryption uses a customer-managed key when one is
# supplied (its key policy must allow cloudwatch.amazonaws.com kms:Decrypt +
# kms:GenerateDataKey*).
resource "aws_sns_topic" "alarms" {
  name              = "${local.name}-alarms"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "alarms_topic" {
  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "alarms" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.alarms_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alarm_emails)
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

################################################################################
# Application alarms (from EMF metrics)
################################################################################

resource "aws_cloudwatch_metric_alarm" "errors_5xx" {
  alarm_name          = "${local.name}-5xx-errors"
  alarm_description   = "5xx responses above threshold. Runbook: runbooks/high-error-rate.md"
  namespace           = var.metric_namespace
  metric_name         = "Errors5xx"
  dimensions          = { Service = var.service_name }
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = var.error_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "latency_p99" {
  alarm_name          = "${local.name}-latency-p99"
  alarm_description   = "p99 latency above ${var.latency_p99_threshold_ms} ms. Runbook: runbooks/high-latency.md"
  namespace           = var.metric_namespace
  metric_name         = "Latency"
  dimensions          = { Service = var.service_name }
  extended_statistic  = "p99"
  period              = var.alarm_period_seconds
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = var.latency_p99_threshold_ms
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

# Error *rate* via metric math, so a traffic spike alone does not page anyone.
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${local.name}-error-rate"
  alarm_description   = "5xx error rate above 2% of requests. Runbook: runbooks/high-error-rate.md"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 2
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags

  metric_query {
    id          = "rate"
    expression  = "IF(requests > 0, 100 * errors / requests, 0)"
    label       = "5xx error rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = var.metric_namespace
      metric_name = "Errors5xx"
      dimensions  = { Service = var.service_name }
      period      = var.alarm_period_seconds
      stat        = "Sum"
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = var.metric_namespace
      metric_name = "Requests"
      dimensions  = { Service = var.service_name }
      period      = var.alarm_period_seconds
      stat        = "Sum"
    }
  }
}

################################################################################
# Container + load balancer alarms (optional)
################################################################################

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  count = local.enable_ecs ? 1 : 0

  alarm_name          = "${local.name}-ecs-cpu-high"
  alarm_description   = "Service CPU above 80%. Runbook: runbooks/container-saturation.md"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 4
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  count = local.enable_ecs ? 1 : 0

  alarm_name          = "${local.name}-ecs-memory-high"
  alarm_description   = "Service memory above 85%. Runbook: runbooks/container-saturation.md"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 4
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = local.enable_alb ? 1 : 0

  alarm_name          = "${local.name}-unhealthy-targets"
  alarm_description   = "Unhealthy targets behind the ALB. Runbook: runbooks/failed-deployment.md"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = var.tags
}

# One page-worthy signal that the deploy pipeline (CodeDeploy / rollout) watches for auto-rollback.
resource "aws_cloudwatch_composite_alarm" "service_unhealthy" {
  alarm_name        = "${local.name}-service-unhealthy"
  alarm_description = "Composite: error rate OR p99 latency breached. Used as the deployment rollback trigger."
  alarm_rule        = "ALARM(\"${aws_cloudwatch_metric_alarm.error_rate.alarm_name}\") OR ALARM(\"${aws_cloudwatch_metric_alarm.latency_p99.alarm_name}\")"
  alarm_actions     = [aws_sns_topic.alarms.arn]
  ok_actions        = [aws_sns_topic.alarms.arn]
  tags              = var.tags
}

################################################################################
# Dashboard
################################################################################

locals {
  region = data.aws_region.current.name

  app_widgets = [
    {
      type = "metric", x = 0, y = 0, width = 12, height = 6
      properties = {
        title  = "Requests and 5xx"
        region = local.region
        stat   = "Sum"
        period = 60
        metrics = [
          [var.metric_namespace, "Requests", "Service", var.service_name],
          [var.metric_namespace, "Errors5xx", "Service", var.service_name, { color = "#d62728" }],
        ]
      }
    },
    {
      type = "metric", x = 12, y = 0, width = 12, height = 6
      properties = {
        title  = "Latency (p50 / p90 / p99)"
        region = local.region
        period = 60
        metrics = [
          [var.metric_namespace, "Latency", "Service", var.service_name, { stat = "p50" }],
          ["...", { stat = "p90" }],
          ["...", { stat = "p99" }],
        ]
        annotations = {
          horizontal = [{ label = "p99 alarm", value = var.latency_p99_threshold_ms }]
        }
      }
    },
    {
      type = "alarm", x = 0, y = 6, width = 24, height = 3
      properties = {
        title = "Alarm status"
        alarms = [
          aws_cloudwatch_metric_alarm.errors_5xx.arn,
          aws_cloudwatch_metric_alarm.error_rate.arn,
          aws_cloudwatch_metric_alarm.latency_p99.arn,
          aws_cloudwatch_composite_alarm.service_unhealthy.arn,
        ]
      }
    },
    {
      type = "log", x = 0, y = 9, width = 24, height = 6
      properties = {
        title  = "Recent 5xx (Logs Insights)"
        region = local.region
        query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, Route, status, Latency, version, color | filter status >= 500 | sort @timestamp desc | limit 20"
        view   = "table"
      }
    },
  ]

  ecs_widgets = local.enable_ecs ? [
    {
      type = "metric", x = 0, y = 15, width = 24, height = 6
      properties = {
        title  = "Container CPU / memory (Container Insights)"
        region = local.region
        stat   = "Average"
        period = 60
        metrics = [
          ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
          [".", "MemoryUtilization", ".", ".", ".", "."],
        ]
      }
    },
  ] : []
}

resource "aws_cloudwatch_dashboard" "service" {
  dashboard_name = local.name
  dashboard_body = jsonencode({ widgets = concat(local.app_widgets, local.ecs_widgets) })
}
