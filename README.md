# Tredly

0.9.0 Apr 21 2016

## What is Tredly

Tredly is a suite of products to enable developers to spend less time on sysadmin tasks and more time developing. Tredly is a full stack container solution for FreeBSD with the following main components:

### Tredly-Host
The server technology to run the containers, built on FreeBSD. Tredly Host contains a number of inbuilt functions:

  * Layer 7 Proxy (HTTP/HTTPS proxy)
  * Layer 4 Proxy (TCP Proxy)
  * DNS

### Tredly-Build

Validates and Builds containers on Tredly-Host

## Install Tredly-Host

1. Install FreeBSD (**10.3 or above**) Root on ZFS.

	* Select all defaults except:
    	* Deselect Ports (Tredly uses pkgs for everything)
    	* Select System source code (we will use this later for custom kernel)
    	* Select Auto (ZFS) as partitioning

    Wait for it to complete and reboot

2. Log in as root and add user that isn't root for SSH access (username can be anything)

    * `pw useradd -n tredly -s /bin/tcsh -m`
    * `passwd tredly`
    * Add user to Wheel Group so they can su to root: `pw groupmod wheel -m tredly`

3. SSH into Host using new user
    * Allow key access via SSH instead of password
        1. mkdir ~/.ssh && vi ~/.ssh/authorized_keys
        2. Get your SSH key from your local computer
            * vim ~/.ssh/id_rsa.pub
4. Change user to root to complete installation: `su -`
5. Install Git so you can install Tredly-Host
    * `pkg install -y git`
6. Install Tredly-Host
    * `cd /tmp && git clone https://github.com/tredly/tredly-host.git`
    * Install Tredly-host: `cd /tmp/tredly-host && sh install.sh`
    * This will take some time (depending on the speed of your machine and internet connection) as Tredly-Host uses Tredly-Build and a number of other pieces of software. **Note that this step may also re-compile your kernel for VIMAGE support if it is not found within your current kernel.**

## Configuring Tredly-Host

Tredly-Host can be configured in a number of ways, depending on what you are trying to achieve. We recommend you read the wiki article https://github.com/tredly/tredly-host/wiki/Tredly-Overview to understand the options you can configure in Tredly.


## Tredly-Host Commands

* Destroy all Partitions
    - `tredly destroy partitions`
    - `confirm=yes`

* Create a Partition
    - `tredly create partition [PartitionName] CPU=[int] RAM=[int] HDD=[int] ipv4Whitelist=[ip1],[ip2]...[ip]`
    - Please note that CPU and RAM limits are yet to be implmented.

* Modify a Partition
    - `tredly modify partition <PartitionName> partitionName=<newPartitionName> CPU=<int> RAM=<int>m/g HDD=<int>m/g ipv4Whitelist=<ip1>,<ip2>,<ip3>`

* Destroy an entire Partition
    - `tredly destroy partition <PartitionName>`
    - confirm=yes

* Destroy all the containers on a Partition
    - `tredly destroy containers  <PartitionName>`
    - confirm=yes

* List all Partitions on the Host
    - `tredly list partitions`

* List all containers on a Partition
    - `tredly list containers <PartitionName>`
    - `--sortBy=<Heading>`

* List all containers running on the Host
    - `tredly list containers`

* Create a container on the default partition
    - `tredly create container --path=<PathToContainer>`

* Create a container on a specific partition
    - `tredly create container <partitionName> --path=<PathToContainer>`

* Destroy a container
    - `tredly destroy container UUID`
    - `confirm=yes`

* Replace a container
    - `tredly replace container <partitionName> ContainerUUID(optional) --path=<PathToContainer>`

* Validate a container
    - `tredly validate container --path=<PathToContainer>`

* List all containers within a containerGroup
    - `tredly list containers <partitionName> <containerGroup>`

* Console access to a container
    - `tredly console <ContainerUUID>`


## Container examples

You can download a number of container examples from **[https://github.com/tredly](https://github.com/tredly)**.

These examples are there to give you a good starting point for your own containers. New containers are being added regularly.

## Future Plans

Tredly was built to allow the **[Vuid Business Software Platform](https://www.vuid.com)** to exist. We are currently in the process of porting Tredly so that it can be used by anyone, not just Vuid. Some functionality listed in this section may already exist BUT the work to make it usable by anyone is still ongoing.

Tredly-Host functions will be containerised and an API added to each to allow easier updating and scalability. Tredly-Host will be also given its own API so one or more Tredly-Hosts can be managed from a central management console or web interface.

Tredly-Build will be given its own API so that you can push containers directly to it and have them built on push.

## Contributing

We encourage you to contribute to Tredly. Please check out the [Contributing documentation](https://github.com/tredly/tredly-host/blob/master/CONTRIBUTING.md) for guidelines about how to get involved.

## License

Tredly is released under the [GNU General Public License v3](http://www.gnu.org/licenses/gpl-3.0.en.html).

## Other Information

Tredly example containers are available from https://github.com/tredly.

Tredly and its components are being actively developed. For more information please check both https://github.com/tredly and https://github.com/vuid-com as well as https://twitter.com/vuid_com for Tredly update notifications.
