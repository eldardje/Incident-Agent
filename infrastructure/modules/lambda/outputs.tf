locals {
  placeholder_invoke_arns = {
    for key, function_name in local.function_names :
    key => "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${function_name}"
  }
}

output "function_names" {
  description = "Lambda function names keyed by logical function id."
  value       = local.function_names
}

output "invoke_arns" {
  description = "Lambda invoke ARNs keyed by logical function id. Uses placeholder ARNs when functions are not deployed."
  value = {
    for key, function_name in local.function_names :
    key => try(aws_lambda_function.functions[key].invoke_arn, local.placeholder_invoke_arns[key])
  }
}
