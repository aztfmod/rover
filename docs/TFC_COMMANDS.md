# How to get started with TFC/TFE state storage

## Workspace configuration

You can use Terraform Cloud or Terraform Enterprise to support CAF Terraform landing zones state files. 

Current support is for level greater than 1 (composition must be done with a launchpad stored on CAF Azure Storage Account).

For a landing zone in a given level, we can read and compose from Terraform state files on CAF Azure Storage account for the lower level. We are planning to support composition from lower levels stored on TFC/TFE storage in a future update.

### Workspace Execution Mode

Please make you select the Execution Mode to be ```local``` in Terraform Cloud or Terraform Enterprise Configuration, this is currently the only supported method.

## Steps to enable configuration

1. Login to Terraform Cloud/Enterprise

```bash
terraform login
```

2. Export the token and environment information

The following commands allow you to define the configuration for your TFC organization, hostname and the name of the workspace where to store the Terraform state files

```bash
export TERRAFORM_CONFIG="$HOME/.terraform.d/credentials.tfrc.json"
export TFC_organization="contoso" #name of your TFC/TFE organization.
export TFC_hostname="tfc.contoso.local" #optional, only for TFE.
export TF_VAR_workspace"networking-virtualwan-vwan-level2" #name of the workspace where to store the state file.
```

3. Run your ```rover``` command

For any particular rover command you are using, add the ```-tfc``` parameter to switch to TFC/TFE storage instead of CAF Azure Storage hierarchy.
 
```bash
rover ... -tfc 
```

## Workspace Creation

You can create your Terraform Cloud organization and workspaces manually, or if you are looking after an automated way to create them, you can use the [CAF Terraform TFC/TFE Addon](https://github.com/Azure/caf-terraform-landingzones/tree/master/caf_solution/add-ons/terraform_cloud).