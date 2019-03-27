# WooCommerce Core to WordPress.org

Deploy script used for deploying WooCommerce amongst other things.

## Install

```bash
git clone https://github.com/woocommerce/woocommerce-core-to-wordpress-org.git
```

## Setup

Create a `.settings` file in this project's root directory, and fill `GITHUB_ACCESS_TOKEN`.

You can base on [`.settings-sample`](https://github.com/woocommerce/woocommerce-core-to-wordpress-org/blob/master/.settings-sample).

```bash
cd woocommerce-core-to-wordpress-org
cp .settings-sample .settings
```

For more details about GitHub acess tokens, check ["Creating a personal access token for the command line"](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line).

## Options

| Options                       | Description                             |
|-------------------------------|-----------------------------------------|
| `-h` or `--help`              | Shows help message                      |
| `-g` or `--skip-gh`           | Skip GitHub release/tag creation        |
| `-s` or `--skip-svn`          | Skip release on SVN                     |
| `-t` or `--svn-tag-only`      | Release only a SVN tag                  |
| `-u` or `--svn-up-stable-tag` | Update "Stable tag" in trunk/readme.txt |

## Examples

**Regular deploy on GitHub (release/tag) and WordPress.org repository:**

```bash
./release.sh
```

**Release a "Stable tag" on GitHub and WordPress.org repository, while in `beta` or `RC`:**

```bash
./release.sh -t -u
```

Note: Used while in `beta` or `RC`, e.g: latest release on wp.org repository is `3.6.0-beta.1`, but you need to `3.5.10`. Running this command will only create a new tag on the repository and update the "Stable tag" in `trunk/readme.txt`
