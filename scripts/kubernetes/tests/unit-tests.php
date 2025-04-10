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
