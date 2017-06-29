variable "internal_subnets" {
  description = "List of internal subnets"
  type = "list"
}

variable "external_subnet_ids" {
  description = "List of external subnets ids"
  type = "list"
}

variable "internal_nat_eip_ids" {
  description = "List of EIP ids for NAT GWs"
  type = "list"
}

variable "internal_route_table_ids" {
  description = "List of internal route table ids"
  type = "list"
}

resource "aws_nat_gateway" "main" {
  count = "${length(var.internal_subnets)}"
  allocation_id = "${element(var.internal_nat_eip_ids, count.index)}"
  subnet_id = "${element(var.external_subnet_ids, count.index)}"
}

resource "aws_route" "internal" {
  count = "${length(compact(var.internal_subnets))}"
  route_table_id = "${element(var.internal_route_table_ids, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${element(aws_nat_gateway.main.*.id, count.index)}"
}
