resource "aws_emr_cluster" "emr-spark-cluster" {
  name          = "${var.user} - ${var.cluster_name}"
  applications  = ["Hadoop", "Spark", "Zeppelin"]
  release_label = "emr-5.8.0"
  service_role  = "${var.emr_service_role}"

  ec2_attributes {
    instance_profile = "${var.emr_instance_profile}"
    key_name         = "${var.key_name}"

    subnet_id                         = "${var.subnet_id}"

    emr_managed_master_security_group = "${aws_security_group.emr-cluster.id}"
    emr_managed_slave_security_group  = "${aws_security_group.emr-cluster.id}"
  }

  instance_group {
    bid_price      = "${var.master_bid_price}"
    instance_count = 1
    instance_role  = "MASTER"
    instance_type  = "${var.master_instance_type}"
    name           = "emr-master"
  }

  instance_group {
    bid_price      = "${var.worker_bid_price}"
    instance_count = "${var.worker_count}"
    instance_role  = "CORE"
    instance_type  = "${var.worker_instance_type}"
    name           = "emr-worker"
  }

  bootstrap_action {
    path = "${var.bootstrap_script}"
    name = "gdal_install"
  }

  configurations = "conf/emr-configuration.json"
}
