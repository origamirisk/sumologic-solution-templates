# This TF is solely used to create common IAM Role
# 1. Create an IAM role with assume role policy to trust sumologic org.
# 2. Add CloudTrail Policy
# 3. Add ELB policy
# 4. Add CloudWatch metrics policy
# 5. Add Root Cause sources policy

## TODO: Add support for GovCloud. Need to be able to optionally create an AWS User that can assume the role. The assume_role_policy will need to be updated to allow the AWS User to assume the role.
## TODO: Update the SumoLogic sources authentication to use the AWS User credentials instead of the role credentials when GovCloud is enabled.
resource "aws_iam_user" "sumologic_iam_user" {
  for_each = toset(local.create_iam_user ? ["sumologic_iam_user"] : [])

  name = "SumoLogic-Aws-Observability-Module-${random_string.aws_random.id}"
  path = "/"
}

resource "aws_iam_access_key" "sumologic_iam_access_key" {
  for_each = toset(local.create_iam_user ? ["sumologic_iam_access_key"] : [])

  user = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
}

resource "aws_iam_role" "sumologic_iam_role" {
  for_each = toset(local.create_iam_role ? ["sumologic_iam_role"] : [])

  name = "SumoLogic-Aws-Observability-Module-${random_string.aws_random.id}"
  path = "/"

  assume_role_policy = data.aws_partition.current.partition == "aws-us-gov" ? templatefile("${path.module}/templates/iam_assume_role_policy_gov.tmpl", {
    AWS_PARTITION  = data.aws_partition.current.partition,
    AWS_ACCOUNT_ID = local.aws_account_id,
    SUMO_IAM_USER  = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
    }) : templatefile("${path.module}/templates/iam_assume_role_policy.tmpl", {
    AWS_PARTITION         = data.aws_partition.current.partition,
    SUMO_LOGIC_ACCOUNT_ID = local.sumo_account_id,
    ENVIRONMENT           = data.sumologic_caller_identity.current.environment,
    SUMO_LOGIC_ORG_ID     = var.sumologic_organization_id
  })

  # assume_role_policy = templatefile("${path.module}/templates/iam_assume_role_policy.tmpl", {
  #   AWS_PARTITION         = data.aws_partition.current.partition,
  #   SUMO_LOGIC_ACCOUNT_ID = local.sumo_account_id,
  #   ENVIRONMENT           = data.sumologic_caller_identity.current.environment,
  #   SUMO_LOGIC_ORG_ID     = var.sumologic_organization_id
  # })
}

# Sumo Logic CloudTrail Source Policy Attachment
resource "aws_iam_policy" "cloudtrail_policy" {
  for_each = toset(local.create_cloudtrail_source && local.create_iam_role ? ["cloudtrail_policy"] : [])
  #for_each = toset(var.collect_cloudtrail_logs && local.create_iam_role ? ["cloudtrail_policy"] : [])

  policy = templatefile("${path.module}/templates/iam_s3_source_policy.tmpl", {
    AWS_PARTITION = data.aws_partition.current.partition,
    BUCKET_NAME   = local.create_cloudtrail_bucket ? local.common_bucket_name : var.cloudtrail_source_details.bucket_details.bucket_name
  })
}

resource "aws_iam_role_policy_attachment" "cloudtrail_policy_attach" {
  for_each = toset(local.create_cloudtrail_source && local.create_iam_role ? ["cloudtrail_policy_attach"] : [])
  #for_each = toset(var.collect_cloudtrail_logs && local.create_iam_role ? ["cloudtrail_policy_attach"] : [])

  policy_arn = aws_iam_policy.cloudtrail_policy["cloudtrail_policy"].arn
  role       = aws_iam_role.sumologic_iam_role["sumologic_iam_role"].name
}

resource "aws_iam_user_policy_attachment" "cloudtrail_policy_attach" {
  for_each = toset(local.create_cloudtrail_source && local.create_iam_user ? ["cloudtrail_policy_attach"] : [])

  policy_arn = aws_iam_policy.cloudtrail_policy["cloudtrail_policy"].arn
  user       = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
}

# Sumo Logic ELB Source Policy Attachment
resource "aws_iam_policy" "elb_policy" {
  for_each = toset(local.create_elb_source && local.create_iam_role ? ["elb_policy"] : [])

  policy = templatefile("${path.module}/templates/iam_s3_source_policy.tmpl", {
    AWS_PARTITION = data.aws_partition.current.partition,
    BUCKET_NAME   = local.create_elb_bucket ? local.common_bucket_name : var.elb_source_details.bucket_details.bucket_name
  })
}

# Sumo Logic Classic LB Source Policy Attachment
resource "aws_iam_policy" "classic_lb_policy" {
  for_each = toset(local.create_classic_lb_source && local.create_iam_role ? ["classic_lb_policy"] : [])

  policy = templatefile("${path.module}/templates/iam_s3_source_policy.tmpl", {
    AWS_PARTITION = data.aws_partition.current.partition,
    BUCKET_NAME   = local.create_classic_lb_bucket ? local.common_bucket_name : var.classic_lb_source_details.bucket_details.bucket_name
  })
}

# Attaching ALB policy to IAM role
resource "aws_iam_role_policy_attachment" "elb_policy_attach" {
  for_each = toset(local.create_elb_source && local.create_iam_role ? ["elb_policy_attach"] : [])
  #for_each = toset(var.collect_elb_logs && local.create_iam_role ? ["elb_policy_attach"] : [])

  policy_arn = aws_iam_policy.elb_policy["elb_policy"].arn
  role       = aws_iam_role.sumologic_iam_role["sumologic_iam_role"].name
}

resource "aws_iam_user_policy_attachment" "elb_policy_attach" {
  for_each = toset(local.create_elb_source && local.create_iam_user ? ["elb_policy_attach"] : [])

  policy_arn = aws_iam_policy.elb_policy["elb_policy"].arn
  user       = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
}

# Attaching Classic LB policy to IAM role
resource "aws_iam_role_policy_attachment" "classic_lb_policy_attach" {
  for_each = toset(local.create_classic_lb_source && local.create_iam_role ? ["classic_lb_policy_attach"] : [])

  policy_arn = aws_iam_policy.classic_lb_policy["classic_lb_policy"].arn
  role       = aws_iam_role.sumologic_iam_role["sumologic_iam_role"].name
}

resource "aws_iam_user_policy_attachment" "classic_lb_policy_attach" {
  for_each = toset(local.create_classic_lb_source && local.create_iam_user ? ["classic_lb_policy_attach"] : [])

  policy_arn = aws_iam_policy.classic_lb_policy["classic_lb_policy"].arn
  user       = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
}

# Sumo Logic CloudWatch Metrics Source Policy Attachment
resource "aws_iam_policy" "cw_metrics_policy" {
  for_each = toset(local.create_metric_source && local.create_iam_role ? ["cw_metrics_policy"] : [])

  policy = templatefile("${path.module}/templates/iam_cw_metrics_source_policy.tmpl", {})
}

resource "aws_iam_role_policy_attachment" "cw_metrics_policy_attach" {
  for_each = toset(local.create_metric_source && local.create_iam_role ? ["cw_metrics_policy_attach"] : [])

  policy_arn = aws_iam_policy.cw_metrics_policy["cw_metrics_policy"].arn
  role       = aws_iam_role.sumologic_iam_role["sumologic_iam_role"].name
}

resource "aws_iam_user_policy_attachment" "cw_metrics_policy_attach" {
  for_each = toset(local.create_metric_source && local.create_iam_user ? ["cw_metrics_policy_attach"] : [])

  policy_arn = aws_iam_policy.cw_metrics_policy["cw_metrics_policy"].arn
  user       = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
}

# Sumo Logic Root Cause Source Policy Attachment
resource "aws_iam_policy" "root_cause_policy" {
  for_each = toset(local.create_root_cause_source && local.create_iam_role ? ["root_cause_policy"] : [])

  policy = templatefile("${path.module}/templates/iam_rootcause_source_policy.tmpl", {})
}

resource "aws_iam_role_policy_attachment" "root_cause_policy_attach" {
  for_each = toset(local.create_root_cause_source && local.create_iam_role ? ["root_cause_policy_attach"] : [])

  policy_arn = aws_iam_policy.root_cause_policy["root_cause_policy"].arn
  role       = aws_iam_role.sumologic_iam_role["sumologic_iam_role"].name
}

resource "aws_iam_user_policy_attachment" "root_cause_policy_attach" {
  for_each = toset(local.create_root_cause_source && local.create_iam_user ? ["root_cause_policy_attach"] : [])

  policy_arn = aws_iam_policy.root_cause_policy["root_cause_policy"].arn
  user       = aws_iam_user.sumologic_iam_user["sumologic_iam_user"].name
}
