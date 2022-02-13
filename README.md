This repository has the terraform script for setting up a end to end pipeline and deploying.

```
Sets up a repository
Creates the role to attach to EC2 instance with access to S3
Creates a Security group with http and ssh.
Creates an EC2 instance with Amazon Linux AMI and install the aws cli and codedeploy
Creates the role for codedeploy
Create AWS code deploy app
Create AWS codedeploy deployment group
Create the role for code pipeline
Create AWS S3 bucket
Create AWS code pipeline with build and deploy stage to deploy to CDG.
```


#### Note
Although the repo is created with the terraform script it does not include the code , so the sample source code will have to be pushed to the repos under sample-app-code folder.

