# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

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

[0.10.0]: https://github.com/tredly/tredly-build/compare/v0.9.0...v0.10.0
