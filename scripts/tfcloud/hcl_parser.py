import argparse
import json
import re
import sys
from typing import Dict

# Define constants
LANDINGZONE_REGEX = r'landingzone\s*=\s*{([\s\S]*)}'
TFSTATES_REGEX = r'[tfstates|remote_tfstates]\s*=\s*{([\s\S]*)}'
BACKEND_TYPE_REGEX = r'^\s*backend_type\s+=\s+"(.+?)"'
LEVEL_REGEX = r'level\s+=\s+"(.+?)"'
KEY_REGEX = r'^\s*key\s+=\s+"(.+?)"'
GLOBAL_SETTINGS_KEY_REGEX = r'^\s*global_settings_key\s+=\s+"(.+?)"'
TFSTATE_REGEX = r'([\w-]+)\s+=\s+{(.+?)}'
LEVEL_VALUE_REGEX = r'level\s+=\s+"(.+?)"'
TFSTATE_FILE_REGEX = r'tfstate\s+=\s+"(.+?)"'


def extract_value(regex: str, data: str, default: str = None) -> str:
    """
    Extracts a single value from a string using regular expressions.
    If the value is not found, returns the default value.
    """
    match = re.search(regex, data, re.MULTILINE)
    return match.group(1) if match else default

def calculate_level(current_level: str, level: str) -> str:
    """
    Calculate the remote tfstate level based on the current_level and the level value set in the tfstates object.
    """
    if level == "current":
      return current_level
    else:
      num = int(current_level.split('level')[1])  # extract the 'level' nnumeric part
      num -= 1
      return f"level{num}"


def extract_landingzone_dict(data: str) -> Dict[str, str]:
    """
    Extracts the landingzone object from the data string and converts it to a dictionary.
    """
    landingzone_str = extract_value(LANDINGZONE_REGEX, data, default='')
    backend_type = extract_value(BACKEND_TYPE_REGEX, landingzone_str, default='azurerm')
    level = extract_value(LEVEL_REGEX, landingzone_str, default='level0')
    key = extract_value(KEY_REGEX, landingzone_str)
    global_settings_key = extract_value(GLOBAL_SETTINGS_KEY_REGEX, landingzone_str)
    tfstates_dict = extract_tfstates(landingzone_str, level)
    landingzone_dict = {
      "landingzone": {
        "backend_type": backend_type,
        "level": level,
        "key": key,
        "tfstates": tfstates_dict
      }
    }
    # Verify optional global_settings_key mapping is valid
    if global_settings_key is not None:
      if global_settings_key not in tfstates_dict.keys():
          raise ValueError(f"Error: global_settings_key '{global_settings_key}' is not a valid key in tfstates_dict. List of keys found for remote_tfstates: {tfstates_dict.keys()}")
      else:
          landingzone_dict['landingzone']['global_settings_key'] = global_settings_key

    return landingzone_dict

def extract_tfstates(landingzone_str: str, current_level: str) -> Dict[str, Dict[str, str]]:
    """
    Extracts the tfstates object from the landingzone string and converts it to a dictionary.
    """
    tfstates_map = extract_value(TFSTATES_REGEX, landingzone_str, default='{}')
    tfstates_dict = {}

    for tfstate in re.finditer(TFSTATE_REGEX, tfstates_map, flags=re.DOTALL):
        name = tfstate.group(1)
        level = extract_value(LEVEL_REGEX, tfstate.group(2), default='current')
        tfstate_file = extract_value(TFSTATE_FILE_REGEX, tfstate.group(2))
        tfstates_dict[name] = {
          "level": level,
          "tfstate": tfstate_file,
          "tfcloud_workspace_name": "{}_{}_{}".format(args.env, calculate_level(current_level, level), tfstate_file.split('.tfstate')[0])
        }

    return tfstates_dict

if __name__ == '__main__':
    # Parse command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-input", required=True, help="Path to input file")
    parser.add_argument("-env", required=True, help="Name of the CAF environment")
    args = parser.parse_args()

    # Read input file
    with open(args.input, "r") as f:
        data = f.read()

    # Remove comments
    data = re.sub(r'^\s*#.*\n', '', data, flags=re.MULTILINE)

    # Extract values from the landingzone object
    landingzone_dict = extract_landingzone_dict(data)

    # Print the JSON string to standard output
    json_string = json.dumps(landingzone_dict, indent=2)
    print(json_string)



# This script processes an input landingzone variable and convert it to json
#
# python3 ./.devcontainer/hcl2json.py -input /tf/caf/landingzones/caf_launchpad/scenario/300-private-endpoints-with-bootstrap-azdo/level1/azdo_agent_levels/landingzone.tfvars -env vip -tfstate vip_launchpad | jq
#

# landingzone = {
#   backend_type        = "azurerm"
#   global_settings_key = "launchpad"
#   level               = "level1"
#   key                 = "azdo_agent_levels"
#   tfstates = {
#     launchpad = {
#       level   = "lower"
#       tfstate = "caf_launchpad.tfstate"
#     }
#     gitops_connectivity = {
#       level   = "current"
#       tfstate = "gitops_connectivity.tfstate"
#     }
#     azdo-azure-terraform-prod-caf-configuration = {
#       level   = "current"
#       tfstate = "azdo-azure-terraform-iac-dev-caf-configuration.tfstate"
#     }
#     application_devops_msi = {
#       level   = "current"
#       tfstate = "application_devops_msi.tfstate"
#     }
#   }
# }

# output:

# {
#   "landingzone": {
#     "backend_type": "azurerm",
#     "level": "level1",
#     "key": "launchpad",
#     "tfstates": {
#       "launchpad": {
#         "level": "lower",
#         "tfstate": "caf_launchpad.tfstate",
#         "tfcloud_workspace_name": "vip_level0_caf_launchpad"
#       },
#       "gitops_connectivity": {
#         "level": "current",
#         "tfstate": "gitops_connectivity.tfstate",
#         "tfcloud_workspace_name": "vip_level1_gitops_connectivity"
#       },
#       "azdo-azure-terraform-prod-caf-configuration": {
#         "level": "current",
#         "tfstate": "azdo-azure-terraform-iac-dev-caf-configuration.tfstate",
#         "tfcloud_workspace_name": "vip_level1_azdo-azure-terraform-iac-dev-caf-configuration"
#       },
#       "application_devops_msi": {
#         "level": "current",
#         "tfstate": "application_devops_msi.tfstate",
#         "tfcloud_workspace_name": "vip_level1_application_devops_msi"
#       }
#     },
#     "global_settings_key": "launchpad"
#   }
# }