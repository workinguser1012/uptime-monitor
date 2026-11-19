output "vpc_id" {
  value = aws_vpc.myvpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.pubsub[*].id
}

output "private_subnet_ids" {
  value      = aws_subnet.privsub[*].id
  depends_on = [aws_route_table_association.rta2, aws_nat_gateway.nat]
}