# solo-bootstrap

Installs chef-solo on a remote host via ssh, deploys cookbooks, and executes chef-solo with a run list.

Assumes ubuntu 16.04 (or any system with the `apt` command available)

# Before running

Set up your .ssh/config for the remote server
The user must be root or have sudo privileges with no password.

# Executing

Pass in the following arguments:

1. The ssh hostname of the server to configure
2. The json attributes for chef-solo
3. The cookbooks path on the local system

## Example

To run the example, clone this repo execute:

`./bootstrap.sh ssh-host-name /full/path/to/example/node.json /full/path/to/example/cookbooks/`

Copyright 2017 Micah Turner
