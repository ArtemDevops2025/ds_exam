#!/bin/bash
# WordPress REST API Tests
echo "Testing WordPress REST API..."

# Test API availability
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$1:32412/wp-json/)
echo "API Status: $API_STATUS"

# Test posts endpoint
POSTS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$1:32412/wp-json/wp/v2/posts)
echo "Posts Endpoint Status: $POSTS_STATUS"

# Test if we can get site info
SITE_INFO=$(curl -s http://$1:32412/wp-json/ | grep -c "name")
if [ $SITE_INFO -gt 0 ]; then
  echo "✅ Site info available through API"
else
  echo "❌ Site info not available"
  exit 1
fi

echo "API Tests completed"
