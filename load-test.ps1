$ALB = "k8s-productc-productc-77f0511153-1170906672.ap-south-1.elb.amazonaws.com"

for ($i=1; $i -le 20; $i++) {
    curl.exe http://$ALB/api/products
    curl.exe "http://$ALB/api/products?search=iphone"
    curl.exe "http://$ALB/api/products?category=Electronics"
    curl.exe http://$ALB/api/products/1
    Write-Host "Batch $i/20 done"
}

Write-Host "Load test complete! Refresh Grafana now."
