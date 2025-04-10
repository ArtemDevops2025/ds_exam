#!/bin/bash
#chmod +x qa-tests.sh

# Directory setup
TESTS_DIR="kubernetes/tests"
mkdir -p $TESTS_DIR

# Create API test script
cat > $TESTS_DIR/api-tests.sh << 'EOF'
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
EOF
chmod +x $TESTS_DIR/api-tests.sh

# Create unit test script
cat > $TESTS_DIR/unit-tests.php << 'EOF'
<?php
// Simple WordPress unit tests

// Test database connection
function test_db_connection() {
  try {
    $mysqli = new mysqli('wordpress-mysql', 'wordpress', getenv('WORDPRESS_DB_PASSWORD'), 'wordpress');
    if ($mysqli->connect_error) {
      echo "❌ Database connection failed: " . $mysqli->connect_error . "\n";
      return false;
    }
    echo "✅ Database connection successful\n";
    $mysqli->close();
    return true;
  } catch (Exception $e) {
    echo "❌ Exception: " . $e->getMessage() . "\n";
    return false;
  }
}

// Run tests
echo "Running WordPress unit tests...\n";
$db_test = test_db_connection();

if ($db_test) {
  echo "All tests passed!\n";
  exit(0);
} else {
  echo "Some tests failed!\n";
  exit(1);
}
EOF

echo "QA test scripts created successfully in $TESTS_DIR"
