apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress-${environment}
  labels:
    app: wordpress
    environment: ${environment}
spec:
  replicas: ${replica_count}
  selector:
    matchLabels:
      app: wordpress
      environment: ${environment}
  template:
    metadata:
      labels:
        app: wordpress
        environment: ${environment}
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
          value: "${s3_bucket}"
        - name: S3_REGION
          value: "${s3_region}"
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
        resources:
          requests:
            memory: "${memory_request}"
            cpu: "${cpu_request}"
          limits:
            memory: "${memory_limit}"
            cpu: "${cpu_limit}"
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pv-claim