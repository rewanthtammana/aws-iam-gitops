import json
import boto3
import os
from github import Github, InputGitTreeElement
from base64 import b64decode

def handler(event, context):

    # AWS clients
    iam = boto3.client('iam')
    orgs = boto3.client('organizations')

    # GitHub credentials
    github_username = "GITHUB_USERNAME"

    # Get it from KMS
    github_token = "GITHUB_TOKEN"

    # GitHub repo name
    github_repo_name = "GITHUB_REPO"

    # GitHub client
    g = Github(github_username, github_token)
    user = g.get_user()

    # Create new repo
    try:
        repo = user.create_repo(github_repo_name, private=True)
        file_content = "Hello, World!"
        repo.create_file("README.md", "Initial commit", file_content)
    except Exception as e:
        print(f"Could not create repo: {e}")
        repo = user.get_repo(github_repo_name)

    parent_commit_sha = repo.get_branch(branch="main").commit.sha
    parent_commit = repo.get_git_commit(sha=parent_commit_sha)
    latest_tree = parent_commit.tree

    # # Get all tree elements from the latest commit
    all_tree_elements = latest_tree.tree

    # Folders to delete
    folders_to_delete = ["roles", "policies", "scps"]

    # Filter out the tree elements that are in the folders to delete
    new_tree_elements = [el for el in all_tree_elements if not any(el.path.startswith(folder) for folder in folders_to_delete)]

    input_git_tree_elements = [
        InputGitTreeElement(
            path=el.path,
            mode=el.mode,
            type=el.type,
            sha=el.sha,
        )
        for el in new_tree_elements
    ]

    # Fetch and upload AWS info to GitHub
    for client, category in [(iam, "roles"), (iam, "policies"), (orgs, "scps")]:
        print("Working on ", client, category)
        items = []
        # Get info from AWS
        if category == "roles":
            items = client.list_roles()["Roles"]
            # paginator = client.get_paginator('list_roles')
            # for page in paginator.paginate():
            #     items.extend(page['Roles'])
        elif category == "policies":
            items = client.list_policies(Scope='All')["Policies"]
            # # print('ignore policies')
            # paginator = client.get_paginator('list_policies')
            # for page in paginator.paginate(Scope='All'):
            #     items.extend(page['Policies'])
        else:  # category == "scps"
            items = client.list_policies(Filter='SERVICE_CONTROL_POLICY')["Policies"]
            # paginator = orgs.get_paginator('list_policies')
            # for page in paginator.paginate(Filter='SERVICE_CONTROL_POLICY'):
            #     items.extend(page['Policies'])
        print(len(items), category)
        for item in items:
            # Create new file with item info (actually a Git blob)
            blob = repo.create_git_blob(json.dumps(item, default=str, indent=4), "utf-8")
            # print(item)
            if category == 'roles':
                tree_element = InputGitTreeElement(path=f"{category}/{item['RoleName']}.json", mode="100644", type="blob", sha=blob.sha)
            elif category == 'policies':
                tree_element = InputGitTreeElement(path=f"{category}/{item['PolicyName']}.json", mode="100644", type="blob", sha=blob.sha)
            elif category == 'scps':
                tree_element = InputGitTreeElement(path=f"{category}/{item['Id']}.json", mode="100644", type="blob", sha=blob.sha)
            else:
                print(">>>>>>>>>>>>.")
                print(item)
                exit()
            input_git_tree_elements.append(tree_element)

    new_tree = repo.create_git_tree(tree=input_git_tree_elements)

    if new_tree.sha == latest_tree.sha:
        print('nothing changed')
        return

    # Then use this parent_commit in the create_git_commit call
    commit = repo.create_git_commit(message=f"Add random", tree=new_tree, parents=[parent_commit])
    repo.get_git_ref(ref="heads/main").edit(sha=commit.sha)
    print("done")

    return {
        'statusCode': 200,
        'body': json.dumps("Successful. Check your Github! https://github.com/{0}".format("/".join([github_username, github_repo_name])))
    }
