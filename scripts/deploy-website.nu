#!/usr/bin/env nu

const WEBSITE_DIR_NAME = "website"
const CLOUDFLARE_DOMAIN = "cecc.mert-kurttutan.com"
const CLOUDFLARE_ROOT_DIR = "website"
const CLOUDFLARE_BUILD_COMMAND = "npm run build"
const CLOUDFLARE_OUTPUT_DIR = "dist"
const CLOUDFLARE_INCLUDE_PATHS = ["website/*" "README.md" "docs/*"]
const CLOUDFLARE_EXCLUDE_PATHS = []
const CLOUDFLARE_DEFAULT_PROJECT_NAME = "cecc-linux"
const CLOUDFLARE_API_BASE = "https://api.cloudflare.com/client/v4"
const REPO_SOURCE_PROVIDER = "github"
const REPO_OWNER = "mert-kurttutan"
const REPO_NAME = "cecc-linux"

def command-exists [name: string] {
  (which $name | is-not-empty)
}

def repo-root [] {
  ($env.FILE_PWD | path join ".." | path expand)
}

def unquote-env-value [] {
  let value = $in
  let trimmed = ($value | str trim)

  if ($trimmed | str starts-with '"') and ($trimmed | str ends-with '"') {
    return ($trimmed | str trim --char '"')
  }

  if ($trimmed | str starts-with "'") and ($trimmed | str ends-with "'") {
    return ($trimmed | str trim --char "'")
  }

  $trimmed
}

def read-dotenv [] {
  let env_path = (repo-root | path join ".env")

  if not ($env_path | path exists) {
    return {}
  }

  open --raw $env_path
  | lines
  | where {|line|
      let trimmed = ($line | str trim)
      $trimmed != "" and not ($trimmed | str starts-with "#")
    }
  | each {|line|
      let cleaned = ($line | str trim | str replace --regex '^export\s+' '')
      let parts = ($cleaned | split row "=")

      if (($parts | length) < 2) {
        return null
      }

      let key = ($parts.0 | str trim)
      let value = ($parts | skip 1 | str join "=" | unquote-env-value)

      if not ($key =~ '^[A-Za-z_][A-Za-z0-9_]*$') {
        return null
      }

      { key: $key, value: $value }
    }
  | where {|entry| $entry != null }
  | reduce --fold {} {|entry, acc| $acc | insert $entry.key $entry.value }
}

def env-or-dotenv [name: string, dotenv: record] {
  let exported = ($env | get --optional $name | default "")

  if $exported != "" {
    return $exported
  }

  $dotenv | get --optional $name | default ""
}

def print-cloudflare-settings [] {
  print ""
  print "Cloudflare Pages Git integration settings"
  print $"  Custom domain:          ($CLOUDFLARE_DOMAIN)"
  print $"  Root directory:         ($CLOUDFLARE_ROOT_DIR)"
  print $"  Build command:          ($CLOUDFLARE_BUILD_COMMAND)"
  print $"  Build output directory: ($CLOUDFLARE_OUTPUT_DIR)"
  print "  Production branch:      main"
  print $"  Build watch includes:   (($CLOUDFLARE_INCLUDE_PATHS | str join ', '))"
  print $"  Build watch excludes:   (if ($CLOUDFLARE_EXCLUDE_PATHS | is-empty) { 'none' } else { $CLOUDFLARE_EXCLUDE_PATHS | str join ', ' })"
  print ""
  print "One-time Cloudflare setup:"
  print $"  1. Create a Pages project connected to GitHub repo ($REPO_OWNER)/($REPO_NAME)."
  print "  2. Use the settings above for build configuration."
  print "  3. Add the custom domain after the Pages project exists."
  print ""
  print "API token permission for script domain/project commands:"
  print "  Account -> Cloudflare Pages -> Edit"
  print "  Do not use Account -> Access: Custom Pages; that is a different Cloudflare product."
  print ""
  print "Attach the domain through the Pages project's Custom domains screen."
  print "Configure Build watch paths so unrelated repo changes do not trigger website builds."
}

def ensure-website-dir [repo_dir: string] {
  let website_dir = ($repo_dir | path join $WEBSITE_DIR_NAME)

  if not ($website_dir | path exists) {
    error make {
      msg: $"Website directory not found: ($website_dir)"
    }
  }

  $website_dir
}

def ensure-required-tools [] {
  for tool in [npm git] {
    if not (command-exists $tool) {
      error make {
        msg: $"Required command not found: ($tool)"
      }
    }
  }
}

def ensure-cloudflare-tools [] {
  if not (command-exists curl) {
    error make {
      msg: "Required command not found: curl"
    }
  }
}

def cloudflare-auth [] {
  let dotenv = (read-dotenv)
  let account_id = (env-or-dotenv CLOUDFLARE_ACCOUNT_ID $dotenv)
  let token = (env-or-dotenv CLOUDFLARE_API_TOKEN $dotenv)

  if $account_id == "" {
    error make {
      msg: "CLOUDFLARE_ACCOUNT_ID is not set."
      help: "Set CLOUDFLARE_ACCOUNT_ID in repo-root .env, or export it before using domain subcommands."
    }
  }

  if $token == "" {
    error make {
      msg: "CLOUDFLARE_API_TOKEN is not set."
      help: "Set CLOUDFLARE_API_TOKEN in repo-root .env, or export a token with Pages Read/Write permissions."
    }
  }

  { account_id: $account_id, token: $token }
}

def pages-domains-url [account_id: string, project_name: string] {
  $"($CLOUDFLARE_API_BASE)/accounts/($account_id)/pages/projects/($project_name)/domains"
}

def pages-projects-url [account_id: string] {
  $"($CLOUDFLARE_API_BASE)/accounts/($account_id)/pages/projects"
}

def project-create-body [
  project_name: string
  branch: string
  repo_owner: string
  repo_name: string
  repo_id: string
  owner_id: string
  without_source: bool
] {
  mut body = {
    name: $project_name
    production_branch: $branch
    build_config: {
      build_command: $CLOUDFLARE_BUILD_COMMAND
      destination_dir: $CLOUDFLARE_OUTPUT_DIR
      root_dir: $CLOUDFLARE_ROOT_DIR
    }
  }

  if $without_source {
    return $body
  }

  mut source_config = {
    owner: $repo_owner
    repo_name: $repo_name
    production_branch: $branch
    production_deployments_enabled: true
    preview_deployment_setting: "all"
    pr_comments_enabled: true
    path_includes: $CLOUDFLARE_INCLUDE_PATHS
    path_excludes: $CLOUDFLARE_EXCLUDE_PATHS
  }

  if $repo_id != "" {
    $source_config = ($source_config | insert repo_id $repo_id)
  }

  if $owner_id != "" {
    $source_config = ($source_config | insert owner_id $owner_id)
  }

  $body | insert source {
    type: $REPO_SOURCE_PROVIDER
    config: $source_config
  }
}

def cloudflare-request [
  method: string
  url: string
  --body: any
] {
  ensure-cloudflare-tools
  let auth = (cloudflare-auth)
  let body_json = if $body == null { "" } else { $body | to json --raw }

  let response = if $method == "GET" {
    ^curl -sS -X GET $url -H $"Authorization: Bearer ($auth.token)" | complete
  } else {
    ^curl -sS -X $method $url -H "Content-Type: application/json" -H $"Authorization: Bearer ($auth.token)" -d $body_json | complete
  }

  if $response.exit_code != 0 {
    error make {
      msg: $"Cloudflare API request failed: ($method) ($url)"
      help: ($response.stderr | str trim)
    }
  }

  let parsed = ($response.stdout | from json)

  if not ($parsed.success? | default false) {
    let errors = (
      $parsed.errors?
      | default []
      | each {|err|
          let code = ($err.code? | default "")
          let message = ($err.message? | default ($err | to json --raw))

          if ($code | into string) == "" {
            $message
          } else {
            $"code=($code) message=($message)"
          }
        }
      | str join "; "
    )

    let help = if ($errors | str contains "code=10000") {
      $"($errors). Check that the token has Account -> Cloudflare Pages -> Edit for the target account. Account -> Access: Custom Pages is not enough."
    } else {
      $errors
    }

    error make {
      msg: $"Cloudflare API rejected request: ($method) ($url)"
      help: $help
    }
  }

  $parsed
}

def ensure-clean-worktree [] {
  let status = (^git status --porcelain=v1 | str trim)

  if $status != "" {
    error make {
      msg: "Refusing to push with uncommitted changes."
      help: "Commit or stash local changes first, then rerun with --push."
    }
  }
}

def main [
  --skip-check
  --skip-build
  --settings-only
  --push (-p)
  --remote: string = "origin"
  --branch: string = "main"
] {
  let repo_dir = (repo-root)
  let website_dir = (ensure-website-dir $repo_dir)

  print-cloudflare-settings

  if $settings_only {
    return
  }

  ensure-required-tools

  print $"Website directory: ($website_dir)"
  cd $website_dir

  if not $skip_check {
    print "Running website checks..."
    ^npm run check
  }

  if not $skip_build {
    print "Building website static files..."
    ^npm run build
  }

  if $push {
    cd $repo_dir

    let current_branch = (^git branch --show-current | str trim)
    if $current_branch != $branch {
      error make {
        msg: $"Refusing to push from branch ($current_branch)."
        help: $"Switch to ($branch), or pass --branch ($current_branch) if that is intentional."
      }
    }

    ensure-clean-worktree

    print $"Pushing ($branch) to ($remote). Cloudflare Pages will deploy the pushed commit."
    ^git push $remote $branch
  } else {
    print ""
    print "Local validation finished."
    print "Commit and push main when ready; Cloudflare Pages will build and deploy from Git."
  }
}

def "main domain list" [
  --project-name: string = $CLOUDFLARE_DEFAULT_PROJECT_NAME
  --json
] {
  let auth = (cloudflare-auth)
  let response = (cloudflare-request GET (pages-domains-url $auth.account_id $project_name))

  if $json {
    print ($response.result | to json)
    return
  }

  let domains = ($response.result? | default [])

  if ($domains | is-empty) {
    print $"No custom domains found for Pages project: ($project_name)"
    return
  }

  $domains
  | select name status zone_tag
  | table
}

def "main domain get" [
  --project-name: string = $CLOUDFLARE_DEFAULT_PROJECT_NAME
  --domain: string = $CLOUDFLARE_DOMAIN
  --json
] {
  let auth = (cloudflare-auth)
  let url = $"(pages-domains-url $auth.account_id $project_name)/($domain)"
  let response = (cloudflare-request GET $url)

  if $json {
    print ($response.result | to json)
    return
  }

  let result = $response.result
  print $"Domain:  ($result.name)"
  print $"Status:  ($result.status)"
  print $"Project: ($project_name)"

  let verification_status = ($result.verification_data?.status? | default "")
  if $verification_status != "" {
    print $"Verification: ($verification_status)"
  }

  let error_message = ($result.error_message? | default "")
  if $error_message != "" {
    print $"Error: ($error_message)"
  }
}

def "main domain add" [
  --project-name: string = $CLOUDFLARE_DEFAULT_PROJECT_NAME
  --domain: string = $CLOUDFLARE_DOMAIN
  --json
] {
  let auth = (cloudflare-auth)
  let response = (
    cloudflare-request POST
      (pages-domains-url $auth.account_id $project_name)
      --body { name: $domain }
  )

  if $json {
    print ($response.result | to json)
    return
  }

  let result = $response.result
  print $"Added custom domain to Pages project: ($project_name)"
  print $"Domain: ($result.name)"
  print $"Status: ($result.status)"

  let txt_name = ($result.txt_name? | default "")
  let txt_value = ($result.txt_value? | default "")
  if $txt_name != "" and $txt_value != "" {
    print ""
    print "Cloudflare returned TXT verification data:"
    print $"  Name:  ($txt_name)"
    print $"  Value: ($txt_value)"
  }
}

def "main project list" [
  --json
] {
  let auth = (cloudflare-auth)
  let response = (cloudflare-request GET (pages-projects-url $auth.account_id))

  if $json {
    print ($response.result | to json)
    return
  }

  let projects = ($response.result? | default [])

  if ($projects | is-empty) {
    print "No Cloudflare Pages projects found for this account."
    return
  }

  $projects
  | select name subdomain production_branch created_on
  | table
}

def "main project create" [
  --project-name: string = $CLOUDFLARE_DEFAULT_PROJECT_NAME
  --branch: string = "main"
  --repo-owner: string = $REPO_OWNER
  --repo-name: string = $REPO_NAME
  --repo-id: string = ""
  --owner-id: string = ""
  --without-source
  --json
] {
  let auth = (cloudflare-auth)
  let body = (
    project-create-body
      $project_name
      $branch
      $repo_owner
      $repo_name
      $repo_id
      $owner_id
      $without_source
  )
  let response = (
    cloudflare-request POST
      (pages-projects-url $auth.account_id)
      --body $body
  )

  if $json {
    print ($response.result | to json)
    return
  }

  let project = $response.result
  print $"Created Pages project: ($project.name)"
  print $"Subdomain:         ($project.subdomain? | default 'unknown')"
  print $"Production branch: ($project.production_branch? | default $branch)"
  print $"Root directory:    ($CLOUDFLARE_ROOT_DIR)"
  print $"Build command:     ($CLOUDFLARE_BUILD_COMMAND)"
  print $"Output directory:  ($CLOUDFLARE_OUTPUT_DIR)"

  if not $without_source {
    print $"Source:            ($REPO_SOURCE_PROVIDER):($repo_owner)/($repo_name)"
  }
}

def "main project get" [
  --project-name: string = $CLOUDFLARE_DEFAULT_PROJECT_NAME
  --json
] {
  let auth = (cloudflare-auth)
  let url = $"(pages-projects-url $auth.account_id)/($project_name)"
  let response = (cloudflare-request GET $url)

  if $json {
    print ($response.result | to json)
    return
  }

  let project = $response.result
  print $"Project:           ($project.name)"
  print $"Subdomain:         ($project.subdomain? | default 'unknown')"
  print $"Production branch: ($project.production_branch? | default 'unknown')"
  print $"Created:           ($project.created_on? | default 'unknown')"

  let build_config = ($project.build_config? | default {})
  if not ($build_config | is-empty) {
    print ""
    print "Build config:"
    print $"  Root directory: ($build_config.root_dir? | default '')"
    print $"  Build command:  ($build_config.build_command? | default '')"
    print $"  Destination:    ($build_config.destination_dir? | default '')"
  }
}

def "main token verify" [
  --json
] {
  ensure-cloudflare-tools
  let auth = (cloudflare-auth)
  let response = (
    ^curl -sS -X GET $"($CLOUDFLARE_API_BASE)/user/tokens/verify"
      -H $"Authorization: Bearer ($auth.token)"
    | complete
  )

  if $response.exit_code != 0 {
    error make {
      msg: "Cloudflare token verification request failed."
      help: ($response.stderr | str trim)
    }
  }

  let parsed = ($response.stdout | from json)

  if $json {
    print ($parsed | to json)
    return
  }

  if not ($parsed.success? | default false) {
    let errors = (
      $parsed.errors?
      | default []
      | each {|err|
          let code = ($err.code? | default "")
          let message = ($err.message? | default ($err | to json --raw))

          if ($code | into string) == "" {
            $message
          } else {
            $"code=($code) message=($message)"
          }
        }
      | str join "; "
    )

    error make {
      msg: "Cloudflare token verification failed."
      help: $errors
    }
  }

  let result = $parsed.result
  print "Cloudflare token is valid."
  print $"Status: ($result.status? | default 'unknown')"
  print $"Token id: ($result.id? | default 'unknown')"
}
