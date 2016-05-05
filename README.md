# Tredly

- Version: 0.10.0
- Date: May 5 2016
- [Release notes](https://github.com/tredly/tredly-host/blob/master/CHANGELOG.md)
- [GitHub repository](https://github.com/tredly/tredly-host)

## Overview

Tredly is a suite of products to enable developers to spend less time on sysadmin tasks and more time developing. Tredly is a full stack container solution for FreeBSD. It has two main components: Tredly-Host and Tredly-Build.

### Tredly-Host
The server technology to run the containers, built on FreeBSD. Tredly Host contains a number of inbuilt features:

  * Layer 7 Proxy (HTTP/HTTPS proxy)
  * Layer 4 Proxy (TCP Proxy)
  * DNS

### Tredly-Build

Validates and Builds containers on Tredly-Host

You can find out more information about Tredly at **<http://www.tredly.com>**

## Requirements

To install Tredly, your server must be running **FreeBSD 10.3 (or above) as Root-on-ZFS**. Further details can be found at the [Tredly Docs site](http://www.tredly.com/docs/?p=31).

## Installation

### Via Git

1. Clone the Tredly-Host repository to the desired location (we suggest `/usr/local/etc`):

```
    git clone git://github.com/tredly/tredly-host.git /usr/local/etc
    cd /usr/local/etc//tredly-host
```

1. Follow the steps outlined here <http://www.tredly.com/docs/?p=31> to complete the installation.

## Configuration

Tredly-Host can be configured in a number of ways, depending on what you are trying to achieve. We recommend you read the wiki article <http://www.tredly.com/docs/?cat=4> to understand the options you can configure in Tredly.


## Usage

Tredly-Host incoperates a number of commands for manipulating partitions and their containers. To see a full list of these commands, go to the **[Tredly docs website](http://www.tredly.com/docs/?p=9)**


## Container examples

You can download a number of container examples from **<https://github.com/tredly>**. These examples are there to give you a good starting point for building your own containers.

## Future Plans

Tredly was built to allow the **[Vuid Business Software Platform](https://www.vuid.com)** to exist.  Tredly is currently in a pre-1.0 state, and development is occurring rapidly.

Tredly-Host already has the [Tredly API](https://github.com/tredly/tredly-api), which simpifies updating containers and improves scalability, and [Tredly CLI](https://github.com/tredly/tredly-cli), which provides remote access to a Tredly Host. Both products are in active development.


## Contributing

We encourage you to contribute to Tredly. Please check out the [Contributing documentation](https://github.com/tredly/tredly-host/blob/master/CONTRIBUTING.md) for guidelines about how to get involved.

## License

Tredly is released under the [MIT License](http://www.opensource.org/licenses/MIT).

## Other Information

Tredly example containers are available from <https://github.com/tredly>.

Tredly and its components are being actively developed. For more information please check both <https://github.com/tredly> and <https://twitter.com/tredly_com> for Tredly update notifications.
