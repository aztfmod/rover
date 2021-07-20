Rover CLI Commands & Flags

---

## SYNOPSIS

```shell
Usage: rover <command> <switches>
  commands:
    login         Start the interactive login process to get access to your azure subscription. Performs an az login.
    logout        Clear out login information related to the azure subscription. Performs an az logout.
    ci            Invoke the continuous integration workflow.
    cd            Invoke the continuous deployment workflow.
    landingzone   Commands for managing landing zones.
      list        Lists out all landing zones ( rover landingzone list)
    workspace     Commands for managing workspaces.
      list        List workspaces
      create      Create a new workspace
      delete      Delete a workspace

  switches:
    -sc | --symphony-config   <path>        (ci workflow) Path to a symphony.yml file.
    -ct | --ci-task-name      <task name>   (ci workflow) CI Tool to invoke. If omitted all tools are run, if provided only that tool is run.
     -b | --base-dir                        (ci workflow) Base directory for paths in symphony.yml.
     -d | --debug                           Show debug (verbose) logs
        | --log-severity        <degree>      This is the desired log degree. It can be set to FATAL,ERROR, WARN, INFO, DEBUG or VERBOSE         
    -lz | --landingzone                     Path to a landing zone
     -a | --action                          Terraform action to perform (plan, apply , destroy)
     -c | --cloud                           Name of the Azure Cloud to use (AzurePublic, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud) or specific AzureStack name.
   -env | --environment       <env name>    Name of the Environment to deploy.
     -l | -level              <level>       Level to associate landing zone to (0,1,2,3,4)
           -tfstate           <name>        Name of the state file to use.
           -launchpad                       Flag that indicates that the current deployment is a launchpad.
           -var-folder        <path>        Path to the folder containing configurations for the lz.

```

See [Continuous Integration document](CONTINOUS_INTEGRATION.md) for examples on running CI.
