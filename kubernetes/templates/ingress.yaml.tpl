apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: wordpress-${environment}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-${cert_issuer}"
spec:
  rules:
  - host: "${hostname}"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress-lb
            port:
              number: 80
  tls:
  - hosts:
    - "${hostname}"
    secretName: wordpress-tls-${environment}