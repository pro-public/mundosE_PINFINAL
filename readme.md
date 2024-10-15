# Proyectos complementarios al PIN final presentado

Desarrollados en diferentes tecnologiías (hithub actions, terraform, etc).

## Equipo - Grupo 12

| **Kevin Jesus Apari**  | **Elmer Ramos Loayza**   |
| ---------------------  | ------------------------ |
| **Marcos Ferradas**    | **Juan Pablo Perez**     |
| ---------------------  | ------------------------ |
| **Jesus Troconiz**     | **Aldana Lopez Camelo**  |
| ---------------------  | ------------------------ |
| **Pablo F. Cavadore**  | **Santiago Dijkstra**    |


## Creación de la instancia EC2

Configuramos una instancia t2.micro con Ubuntu Server 22.04 LTS, además de generar un nuevo par de claves de seguridad.

Para esto hacemos uso de el script en terraform, adjunto el las carpetas de practica 01, 02


## Despliegue de EKS con eksctl

Este documento describe los pasos para crear y configurar un clúster de Kubernetes utilizando EKS y eksctl. A continuación, se incluyen los comandos y procedimientos necesarios para la configuración y administración del clúster, así como la instalación de servicios adicionales como NGINX, EBS, Prometheus y Grafana.

## Configuración inicial de AWS
Primero, debes configurar tus credenciales de AWS:

```bash
aws configure
```

## Crear un clúster con eksctl

Para crear un clúster de EKS con eksctl, ejecuta el siguiente comando:

```bash
eksctl create cluster \
    --name eks-mundos-e \
    --region us-east-1 \
    --node-type t3.small \
    --nodes 3 \
    --with-oidc \
    --ssh-access \
    --ssh-public-key pin_key \
    --managed \
    --full-ecr-access \
    --zones us-east-1a,us-east-1b,us-east-1c
```

Verifica los nodos del clúster:

```bash
kubectl get nodes
```

## Crear una clave privada para conectar con EKS

Crea un archivo para la clave privada:

```bash
touch pin_key.pem
```

## Desplegar NGINX en el clúster

Aplica el manifiesto de despliegue de NGINX:

```bash
kubectl apply -f nginx-deployment.yaml
```

### Exponer NGINX a través de un balanceador de carga

Aplica el siguiente manifiesto para exponer NGINX a través de un balanceador de carga:

```bash
kubectl apply -f nginx-service.yaml
```

Obtén la ruta del balanceador de carga:

```bash
kubectl get svc
```

Espera unos minutos para que la página de NGINX se actualice y sea visible.

## Instalar el driver de EBS

Agrega el repositorio del driver EBS:

```bash
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
```

Instala el driver de EBS:

```bash
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set enableVolumeScheduling=true \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true \
  --set controller.serviceAccount.create=true \
  --set controller.serviceAccount.name=ebs-csi-controller-sa
```

Verifica que los pods del EBS estén ejecutándose:

```bash
kubectl get pods -n kube-system
```

## Instalar Prometheus

Agrega el repositorio de Prometheus:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Crea un nuevo espacio de nombres para Prometheus:

```bash
kubectl create namespace prometheus
```

Instala Prometheus:

```bash
helm install prometheus prometheus-community/prometheus \
--namespace prometheus \
--set alertmanager.persistentVolume.storageClass="gp2" \
--set server.persistentVolume.storageClass="gp2"
```

Verifica que los pods de Prometheus estén ejecutándose:

```bash
kubectl get pods -n prometheus
```

### Exponer Prometheus

Utiliza el siguiente comando para exponer Prometheus:

```bash
kubectl port-forward -n prometheus svc/prometheus-server 8080:9090 --address 0.0.0.0
```

## Instalar Grafana

Agrega el repositorio de Grafana:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

Crea un espacio de nombres para Grafana:

```bash
kubectl create namespace grafana
```

Configura el directorio de Grafana:

```bash
mkdir -p ${HOME}/environment/grafana/
nano ${HOME}/environment/grafana/grafana.yaml
```

Instala Grafana:

```bash
helm install grafana grafana/grafana \
--namespace grafana \
--set persistence.storageClassName="gp2" \
--set persistence.enabled=true \
--set adminPassword='EKS!sAWSome' \
--values ${HOME}/environment/grafana/grafana.yaml \
--set service.type=LoadBalancer
```

## Limpiar recursos

Para desinstalar Prometheus y Grafana, y eliminar el clúster de EKS, ejecuta los siguientes comandos:

### Desinstalar Prometheus:

```bash
helm uninstall prometheus --namespace prometheus
kubectl delete namespace prometheus
```

### Desinstalar Grafana:

```bash
helm uninstall grafana --namespace grafana
kubectl delete namespace grafana
```

### Eliminar el clúster de EKS:

```bash
eksctl delete cluster --name eks-mundos-e --region us-east-1
```
