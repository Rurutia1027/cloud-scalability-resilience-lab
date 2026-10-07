resource "aws_db_subnet_group" "app" {
  name       = "${var.name_prefix}-db"
  subnet_ids = aws_subnet.nodes[*].id
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db"
  description = "MySQL reachable only from cluster workloads"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "${var.name_prefix}-db"
  }
}

# The managed node group attaches the cluster security group to its instances, so
# allowing that group covers every Pod using the node network.
resource "aws_vpc_security_group_ingress_rule" "db_from_cluster" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_eks_cluster.lab.vpc_config[0].cluster_security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL from EKS nodes"
}

resource "aws_db_instance" "app" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # Single-AZ on purpose. The experiment is about application replicas, and a
  # database failure is an accepted shared dependency for both services.
  multi_az = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
