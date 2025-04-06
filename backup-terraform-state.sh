#!/bin/bash
# File: /home/a/IT/GroupExam/ds_exam_group/backup-terraform-state.sh

set -e

# Get the bucket name from Terraform output
BUCKET_NAME=$(terraform -chdir=terraform output -raw code_storage_bucket_name)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PREFIX="terraform-state-backups"

echo "Starting Terraform state backup to S3 bucket: $BUCKET_NAME"

# Create a temporary directory for the state files
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Copy all terraform.tfstate files to the temp directory with path structure
find terraform -name "terraform.tfstate" -o -name "terraform.tfstate.backup" | while read -r STATE_FILE; do
    # Create the directory structure in the temp dir
    DEST_DIR="$TEMP_DIR/$(dirname "$STATE_FILE")"
    mkdir -p "$DEST_DIR"
    
    # Copy the state file
    cp "$STATE_FILE" "$DEST_DIR/"
    echo "Copied $STATE_FILE to $DEST_DIR/"
done

# Create a zip archive of all state files
ZIP_FILE="terraform-state-$TIMESTAMP.zip"
(cd "$TEMP_DIR" && zip -r "$ZIP_FILE" .)
mv "$TEMP_DIR/$ZIP_FILE" .

# Upload the zip file to S3
echo "Uploading $ZIP_FILE to s3://$BUCKET_NAME/$BACKUP_PREFIX/"
aws s3 cp "$ZIP_FILE" "s3://$BUCKET_NAME/$BACKUP_PREFIX/$ZIP_FILE"

# Clean up
rm "$ZIP_FILE"
rm -rf "$TEMP_DIR"

echo "Terraform state backup completed successfully!"
echo "Backup stored at: s3://$BUCKET_NAME/$BACKUP_PREFIX/$ZIP_FILE"

#To do------crontab if needed !!!!!
