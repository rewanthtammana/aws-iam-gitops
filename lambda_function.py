import json
import boto3
import os
import subprocess

def handler(event, context):

    # AWS clients
    iam = boto3.client('iam')
    orgs = boto3.client('organizations')

    # GitHub credentials
    github_username = "GITHUB_USERNAME"
    github_token = "GITHUB_TOKEN"
    github_repo_name = "GITHUB_REPO"

    # Clone the repo
    repo_url = f"https://{github_username}:{github_token}@github.com/{github_username}/{github_repo_name}.git"
    clone_command = f"git clone --depth 1 {repo_url} cloned_repo"
    os.system(clone_command)

    # Change directory to the cloned repo
    os.chdir("cloned_repo")

    # Set Git user.name and user.email
    os.system(f"git config user.name abcd")
    os.system(f"git config user.email abcd@gmail.com")

    # Remove existing folders
    folders_to_remove = ["roles", "policies", "scps"]
    for folder in folders_to_remove:
        os.system(f"rm -rf {folder}")

    # Create new folders and populate them
    for client, category in [(iam, "roles"), (iam, "policies"), (orgs, "scps")]:
        os.makedirs(category, exist_ok=True)
        items = []
        if category == "roles":
            paginator = client.get_paginator('list_roles')
            for page in paginator.paginate():
                items.extend(page['Roles'])
        elif category == "policies":
            paginator = client.get_paginator('list_policies')
            for page in paginator.paginate(Scope='All'):
                items.extend(page['Policies'])
        else:  # category == "scps"
            paginator = orgs.get_paginator('list_policies')
            for page in paginator.paginate(Filter='SERVICE_CONTROL_POLICY'):
                items.extend(page['Policies'])

        for item in items:
            file_name = f"{item['RoleName']}.json" if category == "roles" else f"{item['PolicyName']}.json" if category == "policies" else f"{item['Id']}.json"
            with open(f"{category}/{file_name}", "w") as f:
                json.dump(item, f, default=str, indent=4)

    # Add and commit changes
    os.system("git add .")
    commit_message = "Updated AWS configurations"
    os.system(f"git commit -m '{commit_message}'")

    # Push changes
    os.system("git push origin main")
    os.chdir("..")
    os.system("rm -rf cloned_repo")

    return {
        'statusCode': 200,
        'body': json.dumps("Successful. Check your Github! https://github.com/{0}".format("/".join([github_username, github_repo_name])))
    }

# Uncomment the next line to test the function locally
# handler(None, None)
