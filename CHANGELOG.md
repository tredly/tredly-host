# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.10.4] - 2016-05-20
#### Added
- Added ability to whitelist api access before installing
- Added random password retrieval from tredly api and display to user at end of installation (tredly/tredly-host#31, tredly/tredly-host#35)
- Added all menu options to install config file
- Added unattended install option to install config file (tredly/tredly-host#41)

#### Changed
- IPFW rule that did nothing and has been commented out since last version

#### Fixed
- Disabled TSO operating system wide, not just on BCE nics (tredly/tredly-host#39)

## [0.10.3] - 2016-05-13
#### Fixed
- Allow dot characters in hostname (tredly/tredly-build#39)

#### Changed
- Installation throws an error if the hostname length is longer than 255 characters
- Improved regular expression matching for hostnames.

## [0.10.2] - 2016-05-12
#### Added
- Automatically whitelisting IP addresses of Tredly Command Center
- Interactive menu is now available upon start of install
- Validation of kernel source before compiling.
- `conf/install.conf` added; contains paths to repositories and branches used during installation
- Added host wide default 404 page for layer 7 proxy
- Speed improvement by copying `src.txz` from Tredly init when recompiling kernel

#### Changed
- Setting up `rc.conf` before anything else to prevent error messages
- Change ARP timeout from 20 minutes to 30 seconds (tredly/tredly-build#36)
- Host IPFW tables are referenced in IPFW rules to simplify updating rules and to prevent disconnecting of active sessions.
- Improved layout for `ipfw.vars`

## [0.10.0] - 2016-05-05
#### Added
- Changed default private subnet to 10.99.0.0/16
- Added .gitignore
- Add pipe checks to pkg install in installation script
- Added firewall rule for Tredly API
- Added installer for Tredly API

#### Changed
- Updated documentation for contribution.
- Updated README to include link to CONTRIBUTING.md
- Updates for websockets, add pipefail.
- Changed SSH to be password auth instead of PKI
- Update ssh instructions in README
- Updated the way proxying is set up by the layer 7 proxy
- Moved Tredly-Host overview in README to http://tredly.com/docs
- Change default private subnet to 10.99.0.0/16

#### Removed
- Removal of sslconfig directory

## 0.9.0 - 2016-04-21
#### Added
- Initial release of Tredly

[0.10.4]: https://github.com/tredly/tredly-host/compare/v0.10.3...v0.10.4
[0.10.3]: https://github.com/tredly/tredly-host/compare/v0.10.2...v0.10.3
[0.10.2]: https://github.com/tredly/tredly-host/compare/v0.10.0...v0.10.2
[0.10.0]: https://github.com/tredly/tredly-host/compare/v0.9.0...v0.10.0
