output "server1_public_ip" {
  value = aws_instance.myAPIserver1.public_ip
}

output "server2_public_ip" {
  value = aws_instance.myAPIserver2.public_ip
}
