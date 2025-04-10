apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
  labels:
    app: wordpress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: art2025/ds_exam2025:wordpress-s3
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql
        - name: WORDPRESS_DB_NAME
          value: wordpress
        - name: WORDPRESS_DB_USER
          value: wordpress
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-pass
              key: password
        - name: S3_BUCKET
          value: "ds-exam-app-data-xotjx8lp"
        - name: S3_REGION
          value: "eu-west-3" 
        - name: S3_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: s3-credentials
              key: access-key
        - name: S3_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: s3-credentials
              key: secret-key
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
        - name: wordpress-config
          mountPath: /var/www/html/wp-config.php
          subPath: wp-config.php
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pv-claim
      - name: wordpress-config
        configMap:
          name: wordpress-config
