data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "myvpc" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_subnet" "pubsub" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = cidrsubnet(var.cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name}-public-${count.index}" }
}

resource "aws_subnet" "privsub" {
  count             = var.az_count
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "${var.name}-private-${count.index}" }
}


### Chunk B NAT GATEWAY


resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.ig]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.pubsub[0].id
  tags          = { Name = "${var.name}-nat" }
  depends_on    = [aws_internet_gateway.ig]
}




### CHUNK C  ROUTE TABLES

resource "aws_route_table" "rtpubsub" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
}

resource "aws_route_table" "rtprivsub" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}


##### CHUNK D attach to resources

resource "aws_route_table_association" "rta1" {
  count          = var.az_count
  subnet_id      = aws_subnet.pubsub[count.index].id
  route_table_id = aws_route_table.rtpubsub.id
}

resource "aws_route_table_association" "rta2" {
  count          = var.az_count
  subnet_id      = aws_subnet.privsub[count.index].id
  route_table_id = aws_route_table.rtprivsub.id
}