# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2019-04-17
### Added
- Stop script if version provided and version from plugin's main file don't match.
- Added warning when "Stable tag" is "trunk".

## [1.2.1] - 2019-04-11
### Changed
- Fixed `--svn-up-stable-tag` on OSX.
- Replaced `sed` command for Perl's search and replace, since `sed` behaves differently depending on the environment.

## [1.2.1] - 2019-04-11
### Changed
- Ignores `renovate.json` file while copying files.

### Removed
- Removed progress bar from rsync command, since seems to not work properly on OSX.

## [1.2.0] - 2019-04-02
### Added
- New `-p` or `--plugin-slug` option to allow set custom plugin slug.
- New `-o` or `--github-org` option to allow set custom GitHub organization name.

### Changed
- Improved how allows users to review all collected data, including now GitHub and wp.org repositories.
- Fixed coding standards.

## [1.1.0] - 2019-03-29
### Changed
- Improved how rsync displays progress.
- Prevent sync tag when already created on SVN.
- Fixed coding standards.

## [1.0.0] - 2019-03-28
### Added
- First stable release.

[Unreleased]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/compare/1.3.0...HEAD
[1.3.0]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/compare/1.2.2...1.3.0
[1.2.2]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/compare/1.2.1...1.2.2
[1.2.1]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/compare/1.2.0...1.2.1
[1.2.0]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/woocommerce/woocommerce-core-to-wordpress-org/releases/tag/1.0.0
