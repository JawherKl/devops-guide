## **1. Basics Section**

### **1.1 Pod Definition (`pod.yaml`)**
**File:** `basics/pod.yaml`  
**README.md:** `basics/README.md`

```markdown
# Kubernetes Pod Example

This example demonstrates how to create a simple Kubernetes Pod running an NGINX container.

## Steps to Apply

1. Apply the Pod configuration:
   ```bash
   kubectl apply -f pod.yaml
   ```

2. Check the status of the Pod:
   ```bash
   kubectl get pods
   ```

3. View the logs of the Pod:
   ```bash
   kubectl logs nginx-pod
   ```

## Key Concepts
- **Pod**: The smallest deployable unit in Kubernetes, which can contain one or more containers.
- **Container**: A lightweight, standalone executable package that includes everything needed to run an application.
- **Labels**: Key-value pairs used to organize and select resources.
```

---

### **1.2 Deployment Definition (`deployment.yaml`)**
**File:** `basics/deployment.yaml`  
**README.md:** `basics/README.md`

```markdown
# Kubernetes Deployment Example

This example demonstrates how to create a Kubernetes Deployment to manage multiple replicas of an NGINX application.

## Steps to Apply

1. Apply the Deployment configuration:
   ```bash
   kubectl apply -f deployment.yaml
   ```

2. Check the status of the Deployment:
   ```bash
   kubectl get deployments
   ```

3. Check the Pods created by the Deployment:
   ```bash
   kubectl get pods
   ```

## Key Concepts
- **Deployment**: Manages a set of identical Pods and ensures the desired number of replicas are running.
- **Replicas**: The number of Pods that should be running at any given time.
- **Rolling Updates**: Allows zero-downtime updates to the application.
```

---

### **1.3 Service Definition (`service.yaml`)**
**File:** `basics/service.yaml`  
**README.md:** `basics/README.md`

```markdown
# Kubernetes Service Example

This example demonstrates how to create a Kubernetes Service to expose an NGINX Deployment.

## Steps to Apply

1. Apply the Service configuration:
   ```bash
   kubectl apply -f service.yaml
   ```

2. Check the status of the Service:
   ```bash
   kubectl get services
   ```

3. Access the NGINX application:
   - If using a LoadBalancer, use the external IP provided by the Service.
   - If using Minikube or a local cluster, use `kubectl port-forward`:
     ```bash
     kubectl port-forward svc/nginx-service 8080:80
     ```
     Then open `http://localhost:8080` in your browser.

## Key Concepts
- **Service**: Provides a stable IP address and DNS name for accessing Pods.
- **LoadBalancer**: Exposes the Service externally using a cloud provider's load balancer.
- **Port Forwarding**: Allows local access to a Service running in the cluster.
```

---

## **2. Advanced Section**

### **2.1 Multi-Container Pod (`pod.yaml`)**
**File:** `advanced/multi-container-pod/pod.yaml`  
**README.md:** `advanced/multi-container-pod/README.md`

```markdown
# Multi-Container Pod Example

This example demonstrates how to create a Pod with multiple containers: one for the application and one for a logging sidecar.

## Steps to Apply

1. Apply the Pod configuration:
   ```bash
   kubectl apply -f pod.yaml
   ```

2. Check the status of the Pod:
   ```bash
   kubectl get pods
   ```

3. View the logs of the sidecar container:
   ```bash
   kubectl logs multi-container-pod -c log-sidecar
   ```

## Key Concepts
- **Multi-Container Pod**: A Pod that runs multiple containers sharing the same network and storage.
- **Sidecar Pattern**: A helper container that assists the main application container (e.g., logging, monitoring).
- **Volume**: Shared storage between containers in the same Pod.
```

---

### **2.2 Ingress Resource (`ingress.yaml`)**
**File:** `advanced/ingress/ingress.yaml`  
**README.md:** `advanced/ingress/README.md`

```markdown
# Kubernetes Ingress Example

This example demonstrates how to create an Ingress resource to route traffic to different services.

## Steps to Apply

1. Apply the Ingress configuration:
   ```bash
   kubectl apply -f ingress.yaml
   ```

2. Check the status of the Ingress:
   ```bash
   kubectl get ingress
   ```

3. Access the application:
   - Ensure your DNS points to the Ingress controller's IP.
   - Visit `http://myapp.example.com/app1` and `http://myapp.example.com/app2`.

## Key Concepts
- **Ingress**: Manages external access to services in a cluster, typically HTTP/HTTPS.
- **Host-Based Routing**: Routes traffic based on the hostname.
- **Path-Based Routing**: Routes traffic based on the URL path.
```

---

### **2.3 ConfigMap and Secrets**
**File:** `advanced/configmap-secrets/configmap.yaml` and `advanced/configmap-secrets/secret.yaml`  
**README.md:** `advanced/configmap-secrets/README.md`

```markdown
# ConfigMap and Secrets Example

This example demonstrates how to use ConfigMaps and Secrets to manage configuration and sensitive data in Kubernetes.

## Steps to Apply

1. Apply the ConfigMap:
   ```bash
   kubectl apply -f configmap.yaml
   ```

2. Apply the Secret:
   ```bash
   kubectl apply -f secret.yaml
   ```

3. Verify the resources:
   ```bash
   kubectl get configmaps
   kubectl get secrets
   ```

## Key Concepts
- **ConfigMap**: Stores non-sensitive configuration data as key-value pairs.
- **Secret**: Stores sensitive data (e.g., passwords, tokens) in an encrypted format.
- **Environment Variables**: Inject ConfigMap and Secret data into Pods as environment variables.
```

---

### **2.4 StatefulSet (`statefulset.yaml`)**
**File:** `advanced/statefulsets/statefulset.yaml`  
**README.md:** `advanced/statefulsets/README.md`

```markdown
# StatefulSet Example

This example demonstrates how to create a StatefulSet for deploying stateful applications like MySQL.

## Steps to Apply

1. Apply the StatefulSet configuration:
   ```bash
   kubectl apply -f statefulset.yaml
   ```

2. Check the status of the StatefulSet:
   ```bash
   kubectl get statefulsets
   ```

3. Check the Pods and Persistent Volume Claims (PVCs):
   ```bash
   kubectl get pods
   kubectl get pvc
   ```

## Key Concepts
- **StatefulSet**: Manages stateful applications with stable network identities and persistent storage.
- **Persistent Volume (PV)**: Provides durable storage for Pods.
- **Persistent Volume Claim (PVC)**: Requests storage from a PV.
```

---

## **3. Real-World Examples**

### **3.1 Kubernetes Deployment with Environment Variables**
**File:** `advanced/deployment-env/deployment.yaml`  
**README.md:** `advanced/deployment-env/README.md`

```markdown
# Deployment with Environment Variables Example

This example demonstrates how to create a Deployment that uses environment variables from a ConfigMap and Secret.

## Steps to Apply

1. Apply the Deployment configuration:
   ```bash
   kubectl apply -f deployment.yaml
   ```

2. Check the status of the Deployment:
   ```bash
   kubectl get deployments
   ```

3. Verify the environment variables in the Pod:
   ```bash
   kubectl exec <pod-name> -- env | grep APP_
   ```

## Key Concepts
- **Environment Variables**: Pass configuration and sensitive data to containers.
- **ConfigMap**: Stores non-sensitive configuration data.
- **Secret**: Stores sensitive data securely.
```

---

### **3.2 Horizontal Pod Autoscaler (HPA)**
**File:** `advanced/hpa/hpa.yaml`  
**README.md:** `advanced/hpa/README.md`

```markdown
# Horizontal Pod Autoscaler (HPA) Example

This example demonstrates how to create an HPA to automatically scale a Deployment based on CPU usage.

## Steps to Apply

1. Apply the HPA configuration:
   ```bash
   kubectl apply -f hpa.yaml
   ```

2. Check the status of the HPA:
   ```bash
   kubectl get hpa
   ```

3. Generate load to trigger scaling:
   - Use a tool like `kubectl run` or a load testing tool to increase CPU usage.

## Key Concepts
- **Horizontal Pod Autoscaler (HPA)**: Automatically scales the number of Pods based on resource usage.
- **Metrics**: CPU, memory, or custom metrics used for scaling.
- **Scaling Policies**: Define how scaling should behave (e.g., min/max replicas).
```
