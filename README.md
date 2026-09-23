# Cloud Scalability & Resilience Lab 

An AWS-based cloud-native laboratory for designing, deploying, load testing, scaling, breaking, observing, and evaluating a microservices system under controlled workload and failure conditions. 

The project focuses on **scalability**, **resilience**, **observability**, **Infrastructure as Code(IaC)**, and **automated application delivery** using AWS, Terraform, Kubernetes, and k6.


## Project Overview 
This project is developed as part of the Cloud Scalability & Resilience Challenge. 
The engineering workflow follows: 
```
Design -> Deploy -> Load Test -> Scale -> Break -> Observe -> Evaluate
``` 

Rather than treating deployment as the final objective, the deployed system is treated as an **experimental environment**.
The goal is to establish a measurable baseline, apply increasing workload, observe scaling behavior, introduce controlled failures, measure system degradation and recovery, and evalaute whether the architecture provides the expected scalability and resilience characteristics. 

## Assessment Deliverables 
The project produces two primary deliverables. 

### Technical Report 
The technical report documents: 
- System architecture 
- AWS infrastructure design 
- Infrastructure as Code approach 
- Container and Kubernetes deployment 
- CI/CD and application delivery 
- Scaling strategy 
- Failure scenarios 
- Observability strategy 
- Experimental methodology 
- Experimental results 
- Resilience and scalability evaluation 
- Engineering conclusions 


### Engineering Demonstration 
A short engineering demonstration shows the system operating in AWS and demonstrates selected experiments. 

The demonstration follows a representative scenario: 

```
Normal Workload -> Increased Traffic -> Resource Pressure -> Horizontal Scaling        -> Failure Injection -> System Degradation -> Recovery -> Observability -> Evalution  
```

## Architecture 
The system consists of a small Spring Boot microservices application deployed to Amazon EKS. The application is intentionally kept simple so that the primary focus remains on cloud scalability, resilience, deployment automation, and observability. 


// todo 

### Infrastructure and Application Boundaries 
The project separates infrastructure provisioning from application deployment. 

**Terraform manages cloud infrastructure**: 
- VPC
- EKS 
- ECR
- RDS
- IAM 
- Networking 
- Security 
- Cloudwatch infrastructure

### Kubernetes and Helm manage application workloads: 
- Deployments
- Services
- Ingress / Load Balancer 
- ConfigMaps 
- Secrets 
- Horizontal Pod Autoscaling 
- Health Probes 


### AWS CodePipeline and CodeBuild manage application delivery: 

GitHub -> CodePipeline -> CodeBuild -> Docker Build -> Docker Hub -> ECR -> EKS 


This provides a clear separation between: 

> Infrastructure provisioning, application deployment, and application delivery.


## Technology Stack 
### Cloud 
- AWS 
- Amazon EKS 
- Amazon ECR 
- Amazon RDS 
- AWS Load Balancer
- AWS CloudWatch 



### Infra 
- Terraform 
- Infrastructure as Code 
- AWS networking 
- AWS IAM
- Security groups 

### CI/CD 
- GitHub 
- AWS CodePipeline 
- AWS CodeBuild 
- Amazon ECR
- Docker 

### Application 
- Java 
- Spring Boot
- REST APIs
- Docker 

### Container Platform 
- Kubernetes 
- Amazon EKS 
- Helm 
- Horizontal Pod Autoscaler 
- Kubernetes health probes 

### Testing
- k6
- Load testing 
- Stress testing 
- Traffic spike testing
- Failure injection 
- Recovery testing 


### Observability 
- Prometheus 
- Grafana 
- AWS CloudWatch
- Applicaiton metrics 
- Infrastructure metrics 
- Logs 
- Latenc 
- Throughput 
- Error rate 
- CPU utilization 
- Memory utilization 
- Pod count
- Restart count
- Scaling events


## Infrastructure as Code 
Terraform is used as the primary infrastructure provisioning mechanism. The Objective is tomake the AWS environment reproducible, version-controlled, and independently deployable.  

Terraform provisions the infrastructure required by the applicaiton. 

### VPC 
- VPC 
- Public subnets 
- Routing 
- Security groups 
- Networking components 


### EKS 
- EKS cluster 
- Managed node groups 
- IAM integration 
- Kubernetes networking 


### ECR
- Container repositories
- Image storage 


### RDS
- Application data store 
- Database networking 
- Database security 


### Observability Infrastructure 
- CloudWatch resources
- Logging configuration 
- Monitoring configuration where applicable
- Tracing for services interactions and flows 


## Application Deployment 
The Spring Boot application consists of two lightweight microservices: 

```
API Services --> HTTP --> Worker Service
```
The application is intentionally simple. The complexity of the project comes from the deployment environment and experimental conditions, rather than from complex business logic. 

The services provide controlled behavior that can be used to evaluate **scalability** and **resilience**. 

Example include: 
- Normal request processing 
- Configurable processing latency 
- Configurable CPU workload 
- Controlled failure injection 
- Health endpoints 
- Application metrics & service inner instrumentation 

This allows the same application to be used across multiple experiments. 


## CI/CD 
The application delivery pipeline integrates with GitHub with AWS CodePipeline. 

```
Developer --> GitHub --> CodePipeline --> CodeBuild {Compile && Unit Test && Docker Build && Push Image} --> ECR --> EKS --> Helm 
```

The pipeline is responsible for application delivery rather than infrastructure provisioning. Terraform remains responsible for creating and maintaining AWS infrastructure. 

Container images are versioned using the application build or Git commit identifier rather than relying exclusively on the `latest` tag. This allows experiments to be associated with a specific applicaiton version. 





