#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys

RESOURCE_GROUPS = {
    "security": {
        "aws_security_group",
        "aws_security_group_rule",
        "aws_vpc_security_group_ingress_rule",
        "aws_vpc_security_group_egress_rule",
    },
    "eks": {
        "aws_eks_cluster",
        "aws_eks_node_group",
        "aws_eks_addon",
    },
    "iam": {
        "aws_iam_role",
        "aws_iam_policy",
        "aws_iam_role_policy",
        "aws_iam_role_policy_attachment",
        "aws_eks_access_entry",
        "aws_eks_access_policy_association",
    },
}
def load_plan(plan_file):
    result = subprocess.run(
        ["terraform", "show", "-json", plan_file],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)

def inspect(plan, category):
    resources = plan.get("resource_changes", [])

    # Show detailed security group rules
    if category == "security-details":
        inspect_security_details(plan)
        return
     # Show Terraform plan summary
    if category == "summary":
        counts = {"create": 0, "update": 0, "delete": 0}

        for resource in resources:
            actions = resource["change"]["actions"]

            for action in counts:
                if action in actions:
                    counts[action] += 1

        print("Terraform Plan Summary")
        print("----------------------")
        for action, count in counts.items():
            print(f"{action}: {count}")
        return

    allowed_types = RESOURCE_GROUPS[category]
    matches = [
        resource
        for resource in resources
        if resource["type"] in allowed_types
    ]

    print(f"Terraform resources: {category}")
    print("-" * 40)

    if not matches:
        print("No matching resource changes found.")
        return

    for resource in matches:
        print(
            f"{resource['address']}: "
            f"{resource['change']['actions']}"
        )


def inspect_security_details(plan):
    print("Security Group Rule Details")
    print("-" * 60)
    
    for resource in plan.get("resource_changes", []):
        if resource["type"] not in {
            "aws_security_group_rule",
            "aws_vpc_security_group_ingress_rule",
            "aws_vpc_security_group_egress_rule",
        }:
            continue

        values = resource["change"].get("after") or {}
        unknown = resource["change"].get("after_unknown") or {}

        print(f"\nResource: {resource['address']}")
        print(f"Type: {values.get('type', resource['type'])}")
        print(f"Protocol: {values.get('protocol', values.get('ip_protocol'))}")
        print(f"From port: {values.get('from_port')}")
        print(f"To port: {values.get('to_port')}")
        print(f"CIDR: {values.get('cidr_blocks', values.get('cidr_ipv4'))}")
        print(f"Source SG: {values.get('source_security_group_id', values.get('referenced_security_group_id'))}")
        print(f"Security group ID: {values.get('security_group_id')}")
        print(f"Self-reference: {values.get('self')}")
        print(f"Unknown source SG: {unknown.get('source_security_group_id')}")
        print(f"Unknown security group ID: {unknown.get('security_group_id')}")


def main():
    parser = argparse.ArgumentParser(
        description="Inspect a Terraform plan"
    )

    parser.add_argument(
        "category",
        choices=["summary", "security-details", *RESOURCE_GROUPS.keys()],
    )

    parser.add_argument(
        "--plan",
        default="tfplan",
        help="Path to Terraform plan file",
    )

    args = parser.parse_args()

    try:
        plan = load_plan(args.plan)
        inspect(plan, args.category)
    except (subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f"Error reading Terraform plan: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()