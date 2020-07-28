This repository will simulate an adventure of life without VPC Service Controls and one with it. The repository has an imperative script to enable a VPC Service Control perimeter, create an outage for an existing integration sending PUB/SUB messages (hint use my Splunk repo), and disable/enable a process that "borrows" data. 

## Prerequisites 
### Required IAM roles: 
```
$ gcloud organizations add-iam-policy-binding <your_organization_id> --member="user:<Your_ID>@<your_domain>" --role="roles/accesscontextmanager.policyAdmin"
```
### List active account that will be used with the Demo:
 ```
$ gcloud auth list
```
### Confirm project id to create storage bucket:
```
$ gcloud config list project
```
### Create bucket to exfiltrate the empty file:
```
$ export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
$ export BUCKET=${PROJECT_ID}-borrow-data
$ gsutil mb gs://$BUCKET
```
### Confirm IAM permision by running the exfiltration script:
```
$ ./borrow_data_demo.sh $BUCKET
```
## Enable VPC Service controls:
```
$ ./vpc_sc_demo.sh --dns-domain <your_dns_domain> --service-account <GCP Service account publishing messages>

The next 14 prompts will show what happens when VPC Service Controls is enabled/disabled.

```

### Enable VPC Service Controls API and Policy:
1. Enables Access Context Manager API
2. Creates an Access Context Manager Policy for Organization

### Deploy a Service Perimeter:
1. Create a VPC Service Control Perimeter to protect BigQuery and Google Storage
2. Review project and services protected

	Wait for error messages in borrow data session after a couple minutes

3. Update a VPC Service Control Perimeter to protect Pub/Sub
4. Review project and services protected

	Wait for errors in Stackdriver logs showing VPC SC rejection 

### Add Access Levels to Service Perimeter:
1. Add Service Account to access level
2. Add an IP Subnet to access level
3. Add Service account or IP Subnet to access level
4. Confirm VPC Service Control errors clear from borrow data session and Stackdriver logs

### Remove VPC Servic Control:
1. Remove all access levels from VPC Service Control Perimeter
2. Delete a VPC Service Control Perimeter
3. Delete a VPC Service Control Policy
4. Disable Access Context Manager API


### Declarative Deployment
```
The repository is great to show life with and without VPC SC, but this repository is a better option for a structured deployment.

https://github.com/terraform-google-modules/terraform-google-vpc-service-controls

```