#!/bin/bash

BUCKET_NAME="ds-exam-code-storage-253ysdli"
PROJECT_DIR="/home/a/IT/GroupExam/ds_exam_group"
BACKUP_DATE=$(date +%Y-%m-%d)
BACKUP_FILE="project_code.zip"

cd $PROJECT_DIR

zip -r $BACKUP_FILE . -x "*.git*" "*.terraform*" "*terraform.tfstate*" "*.pem" "*.zip"

aws s3 cp $BACKUP_FILE s3://$BUCKET_NAME/backups/$BACKUP_DATE/$BACKUP_FILE

# Optional
rm $BACKUP_FILE

echo "Backup completed: s3://$BUCKET_NAME/backups/$BACKUP_DATE/$BACKUP_FILE"

# chmod +x backup-code.sh
# crontab -e  0 0 * * * /home/a/backup-code.sh >> /home/a/backup.log 2>&1
# Put it to CI/CD pipeline