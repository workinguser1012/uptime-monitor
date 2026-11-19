output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "dns_name" {
  value = aws_lb.alb.dns_name
}

output "zone_id" {
  value = aws_lb.alb.zone_id
}

output "target_group_arn" {
  value      = aws_lb_target_group.frontend.arn
  depends_on = [aws_lb_listener.https]
}