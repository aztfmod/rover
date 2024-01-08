#!/usr/bin/python3
import requests

def get_latest_version(repo_name):
    # Fetch tags from Docker Hub
    response = requests.get(f"https://registry.hub.docker.com/v2/repositories/{repo_name}/tags?page_size=1000")
    tags = [tag['name'] for tag in response.json()['results']]

    # Filter out release candidates, beta versions, alpha versions and only consider tags with "-github" suffix
    filtered_tags = [tag for tag in tags if "-github" in tag and all(s not in tag for s in ("-rc", "-beta", "-alpha"))]

    # Extract version numbers and find the tag with the greatest one
    latest_tag = max(filtered_tags, key=lambda tag: list(map(int, tag.split('-')[0].split('.'))))

    return latest_tag.split("-github")[0].strip()


def get_latest_rover_agent_version():
    return get_latest_version("aztfmod/rover-agent")


if __name__ == "__main__":
    print(get_latest_rover_agent_version())

