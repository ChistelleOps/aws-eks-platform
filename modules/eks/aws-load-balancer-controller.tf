# IAM permissions for AWS Load Balancer Controller
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "platform-aws-load-balancer-controller"
  description = "Allow AWS Load Balancer Controller to manage AWS load balancers"

  policy = file("${path.module}/../../iam/aws-load-balancer-controller-policy.json")
}

# IAM role trust policy for EKS Pod Identity
data "aws_iam_policy_document" "load_balancer_controller_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM role for the controller
resource "aws_iam_role" "load_balancer_controller" {
  name               = "platform-aws-load-balancer-controller-role"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_trust.json
}

# Attach the IAM policy
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

# Associate the IAM role with the Kubernetes service account
resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name = module.eks.cluster_name

  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"

  role_arn = aws_iam_role.load_balancer_controller.arn

  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller
  ]
}