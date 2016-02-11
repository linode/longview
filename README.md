Linode Longview
===============

## Overview
Longview is a system level statistics collection and graphing service, powered by the Longview open source software agent that can be installed onto any Linux system. The Longview agent collects system statistics and sends them to us, where we store the data and present it in beautiful and meaningful ways.

### Preview

The Linode Manager allows you to interact with data collected and analyze your system's resource usage. You can drill into individual servers:

![Longview preview](http://i.imgur.com/mLC8MvK.png "Linode Longview")

Linode Longview also gives you a high-level view of your fleet and lets you sort your servers' resource usage by the metrics that matter to you:

![Longview preview](https://forum.linode.com/images/longview/z6RVTUv.gif "Linode Longview")

### Features

* Compatibility with Linux-based operating systems, Linode and non-Linode.
* An open-source software agent
* Up-to-the-minute information about each system
* Overview dashboard for all systems
* Zoomable graphs with contextual tooltips
* Overall stats for CPU, memory, disk IO, listening services, active connections, network transfer, system details, and more
* Per-process statistics including process count, IO, memory, and CPU usage
* Longview Pro includes unlimited data retention and up to 1 minute resolution
* Longview Free includes 12 hours of data retention and 5 minute resolution

### Linode Docs on Longview

The [Linode Guide & Tutorials](https://linode.com/docs) contains more information on Longview's features at: [Longview](https://www.linode.com/docs/platform/longview/)

## Requirements

### Perl

The Longview client requires perl 5.8 or higher.

### Kernel

The Longview client should be running with a 2.6 or higher kernel. 

### Operating system

The Longview client can be installed on any system running Linux. Linode provides packages for Debian, Ubuntu, CentOS, and Fedora. A tagged release tarball is provided for systems without a pre-rolled package.

## Client usage

### Installation

The client is normally installed by running a one-liner provided by the Linode Manager, which will automatically detect your operating system and drop your client's API key onto the filesystem.

The client installs itself to /opt/linode/longview and will drop the API key under /etc/linode/longview.key.

Alternately, you can obtain a full copy of the repository, which will allow the Extras/install-dependencies.sh script to install (using cpanm) all required perl modules in a lib directory in your local copy of the repository.

### Running the Longview client

The Longview client runs automatically after being installed and configures itself to run at boot time. You can also start it by running:

    service longview start

The client logs information to /var/log/linode/longview.log. The Longview client logs error messages by default. If you'd like more verbose logs, you can manually start the client in debug mode by running:

    /opt/linode/longview/Linode/Longview.pl debug

The client will daemonize itself and print each stage of data collection to the log file, along with the response received by the server. This can be extremely helpful in diagnosing restrictive firewall issues and assisting Linode support in getting Longview to cooperate on any system.

### Stopping the Longview client

The Longview client can be stopped in a similar fashion to starting it:

    service longview stop

This will halt data collection and the graphs on the Linode Manager's "Longview" tab will not continue to update.

#### Removing the Longview client

The client will stop itself once you remove it from the Linode Manager. You can uninstall it by using your package manager. 
