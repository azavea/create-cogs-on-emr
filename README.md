#  Create COGs using EMR

This project lets you create COGs from other raster files, using Apache Spark and AWS's Elastic Map Reduce.

## Setting up the code

In `src/create_cogs.py`, you'll need to define the `get_input_and_output_paths` method to
create a list of tuples `(input_uri, output_uri)` that map input images to output paths.
Either of these paths can be local or on S3.

`gdal_cog_commands` is where the commands for creating a cog live - if you want to modify
how the COG is made, e.g. changing compression or resampling method options, that's where
you should make changes.

## Creating the EMR cluster
Use `make` to spin up an EMR cluster using [terraform](https://github.com/hashicorp/terraform).

- [Requirements](#requirements)
- [Makefile](#makefile)
- [Running](#running)

### Requirements

- [Terraform 0.11](https://github.com/hashicorp/terraform/releases/tag/v0.11.5) or later.
- [aws-cli](https://aws.amazon.com/cli/)
- Set the environment variable `AWS_PROFILE` to your [target profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-multiple-profiles.html).

### Settings

[terraform/variables.tf](terraform/variables.tf) contains the full set of variables
which can be specified to modify an EMR deployment. Only those not
provided defaults need to be specified, and these can be found within
[tfvars.tpl](tfvars.tpl) - be sure to make a copy of this template and remove
'tpl' from the filename.

You'll also have to edit the `COG_EMR_S3_PREFIX` in the `options.mk` file. This is where on S3
the python script is uploaded to so that EMR can run it.

The `options.mk` also settings should be edited when required to tune spark performance.


### Makefile

The Makefile commands you'' generally run are:

```shell
> make upload-code
> make create-cluster
> make run
> make proxy
> make terminate-cluster
```

- `make upload-code` will upload the python script and bootstrap.sh script to the location specified
in the `Makefile` as `COG_EMR_S3_PREFIX`
- `make create-cluster` will create the the cluster and use the `bootstrap.sh` that was just uploaded.
- `make run` Will run the COG create job.
- `make proxy` Will create a ssh tunnel, required to access the UIs as [described here.](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-connect-master-node-proxy.html)
- `make terminate-cluster` kills the cluster after you are done with it.

Here is a list of all the commands:

| Command               | Description
|-----------------------|------------------------------------------------------------|
|terraform-init         |`terraform init` - Initialize terraform                     |
|terraform-plan         |`terraform plan` - Create the cluster plan.                 |
|validate-cluster       |`terraform validate - Validate terraform                    |
|create-cluster         |`terraform` init, if it's the first run                     |
|upload-code            |Upload the code so it can be run by EMR.                    |
|run                    |Runs the pyspark job                                        |
|ssh                    |SSH into a running EMR cluster                              |
|proxy                  |Creates a ssh tunnel to the EMR cluster, needed for UIs     |
|terminate-cluster        |Destroy a running EMR cluster                             |
|print-vars             |Print out env vars for diagnostic and debug purposes        |

Long startup times (15 minutes or more) probably indicates that you have
chosen a spot price that is too low.

If you want to see the UIs such as the Resource Manager, which can take you to the Spark UI for
running jobs, you'll have to jump through some setup hoops, [described here.](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-connect-master-node-proxy.html)

This cluster will have a running Zeppelin interface, which you can run python and Scala code through.

### Running the Job

Upload the code with `make upload-code` before you run, or after you make changes to the python script.

Use `make run` to run

## Don't forget to tear down your cluster!

This happens a lot, so __make sure to call "make terminate-cluster" to tear down your cluster after use__.
Alternatively you can terminate the cluster through the AWS UI.
