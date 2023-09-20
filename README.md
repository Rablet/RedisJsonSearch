# RedisJsonSearch

Docker image with Redis + RedisJSON + RediSearch.

The pre-built packages support amd64 and arm64 (but it should be trivial to add more platforms as needed): https://github.com/Rablet/RedisJsonSearch/pkgs/container/redisjsonsearch

build with: docker build -t <tag name here> .

Run in Kubernetes like this: 

(you can skip configmaps, pvc, secrets if you don't need any configs or persistent storage)
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
  volumeMode: Filesystem
  volumeName: redis-data-pv
--
apiVersion: v1
data:
  # Configs here, for example the below
  redis-config: save 30 1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: default
--
apiVersion: v1
data:
  password: <secret-here>
kind: Secret
metadata:
  name: redis-secret
  namespace: default
type: Opaque
--
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - command:
        - redis-server
        - /redis-master/redis.conf
        - --loadmodule /usr/lib/redis/modules/librejson.so
        - --loadmodule /usr/lib/redis/modules/redisearch.so
        - --requirepass $(REDIS_PASSWORD)
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: redis-secret
        image: ghcr.io/rablet/redisjsonsearch:7.2.1.4
        imagePullPolicy: IfNotPresent
        name: robinredisjsonsearch
        ports:
        - containerPort: 6379
          protocol: TCP
        resources: {}
        volumeMounts:
        - mountPath: /data
          name: data
        - mountPath: /redis-master
          name: config
      restartPolicy: Always
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: redis-data-pvc
      - configMap:
          defaultMode: 420
          items:
          - key: redis-config
            path: redis.conf
          name: redis-config
        name: config
```
