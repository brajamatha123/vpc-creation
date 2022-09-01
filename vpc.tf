

data "aws_availability_zones" "available" {
  state = "available"
}









# to create vpc 

resource "aws_vpc" "vpc" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "stage-vpc"
  }
}




# to create public subnets


resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.public_cidr, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "stage-${count.index + 1}-public"
  }
}


# to create private subnets



resource "aws_subnet" "private" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(var.private_cidr, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)


  tags = {
    Name = "stage-${count.index + 1}-private"
  }
}


# to create data subnets


resource "aws_subnet" "data" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(var.data_cidr, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)


  tags = {
    Name = "stage-${count.index + 1}-data"
  }
}



# to create igw


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "stage-igw"
  }
}


# to create nat-gw



resource "aws_eip" "eip" {
  vpc = true
}


resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "stage-nat-gw"
  }
  depends_on = [
    aws_eip.eip
  ]
}


#  to create route table

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }



  tags = {
    Name = "public-route"
  }
}


resource "aws_route_table" "private-route" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name = "private-route"
  }
}
# to associate route table


resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public-route.id
}


resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private-route.id
}

resource "aws_route_table_association" "data" {
  count          = length(aws_subnet.public[*].id)
  subnet_id      = element(aws_subnet.data[*].id, count.index)
  route_table_id = aws_route_table.private-route.id
}
