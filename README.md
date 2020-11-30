
# Module `terraform-google-network-vpc`

Core Version Constraints:
* `>= 0.13`

Provider Requirements:
* **google (`hashicorp/google`):** (any version)
* **google-beta:** (any version)

## Input Variables
* `environment` (required): Company environment for which the resources are created (e.g. dev, tst, acc, prd, all).
* `network_name` (required): Name of the VPC
* `owner` (required): Owner of the resource. This variable is used to set the 'owner' label. Will be used as default for each subnet, but can be overridden using the subnet settings.
* `project` (required): Company project name.
* `route_defaults` (required): Default settings to be used for your routes so you don't need to provide them for each route separately.
* `routes` (required): Map of custom routes to be created.
* `service_networking_connection` (required): map for private_ip_address settings to use for creation of a service_networking_connection
* `subnet_defaults` (required): Default settings to be used for your subnets so you don't need to provide them for each subnet separately.
* `subnets` (required): Map of subnets to be created. The key will be used for the subnet name so it should describe the subnet purpose. The value can be a map with keys to override default settings.
* `vpc_peer_defaults` (required): Default settings to be used for your vpc peers so you don't need to provide them for each vpc peer separately.
* `vpc_peers` (required): Map of VPC Peers to be created. The key will be used for the name.

## Output Values
* `compute_global_addresses`: Compute global addresses created for service networking connections
* `map`: outputs for all google_compute_subnetwork created
* `route_defaults`: The generic defaults used for subnet settings
* `subnet_defaults`: The generic defaults used for subnet settings
* `vpc`: The generated VPC network url
* `vpc_id`: The generated VPC network id
* `vpc_peer_defaults`: The generic defaults used for subnet settings

## Managed Resources
* `google_compute_global_address.map` from `google`
* `google_compute_network.vpc` from `google`
* `google_compute_network_peering.map` from `google`
* `google_compute_route.map` from `google`
* `google_compute_subnetwork.map` from `google-beta`
* `google_compute_subnetwork_iam_policy.map` from `google`
* `google_service_networking_connection.map` from `google-beta`

## Data Resources
* `data.google_iam_policy.map` from `google`

## Creating a new release
After adding your changed and committing the code to GIT, you will need to add a new tag.
```
git tag vx.x.x
git push --tag
```
If your changes might be breaking current implementations of this module, make sure to bump the major version up by 1.

If you want to see which tags are already there, you can use the following command:
```
git tag --list
```
Required APIs
=============
For the VPC services to deploy, the following APIs should be enabled in your project:
 * cloudresourcemanager.googleapis.com
 * compute.googleapis.com
 * servicenetworking.googleapis.com

Testing
=======
This module comes with [terratest](https://github.com/gruntwork-io/terratest) scripts for both unit testing and integration testing.
A Makefile is provided to run the tests using docker, but you can also run the tests directly on your machine if you have terratest installed.

### Run with make
Make sure to set GOOGLE_CLOUD_PROJECT to the right project and GOOGLE_CREDENTIALS to the right credentials json file
You can now run the tests with docker:
```
make test
```

### Run locally
From the module directory, run:
```
cd test && TF_VAR_owner=$(id -nu) go test
```
