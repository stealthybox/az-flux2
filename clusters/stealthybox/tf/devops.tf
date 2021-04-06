# resource "azuredevops_project" "tf-control" {
#   name = "tf-control"
# }

# resource "azuredevops_git_repository" "tf-control" {
#   name = "tf-control"
#   project_id     = azuredevops_project.tf-control.id
#   default_branch = "main"
#   initialization {
#     init_type = "Clean"
#   }
# }