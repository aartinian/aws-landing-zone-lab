# tag policy on the root, built from the tag standard in live/organization/tagging.yaml.
# Tag policies also apply to the management account (unlike SCPs).
locals {
  tagging = yamldecode(file("${path.module}/../organization/tagging.yaml"))

  tag_policy = {
    tags = {
      for key, values in local.tagging.tags : key => {
        # exact spelling (lowercase), child policies cannot change it
        tag_key = {
          "@@assign"                               = key
          "@@operators_allowed_for_child_policies" = ["@@none"]
        }
        tag_value = {
          "@@assign" = values
        }
        # blocks tagging operations with a value that is not allowed
        enforced_for = {
          "@@assign" = local.tagging.resource_types
        }
        # reports resources without the tag; the Terraform provider can also check it in plan
        report_required_tag_for = {
          "@@assign" = local.tagging.resource_types
        }
      }
    }
  }
}

resource "aws_organizations_policy" "tagging" {
  name        = "tag-standard"
  description = "Required tags and allowed values, from live/organization/tagging.yaml."
  type        = "TAG_POLICY"
  content     = jsonencode(local.tag_policy)
}

resource "aws_organizations_policy_attachment" "tagging" {
  policy_id = aws_organizations_policy.tagging.id
  target_id = local.root_id
}
