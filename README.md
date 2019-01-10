# EKS Provisioning

### Pre-Requisite
* Terraform
  - [Installing Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)
* AWSCLI
  - [Installing the AWS Command Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* Kubectl
  - [Installing kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
* Request for a AWS account including IAM Access Keys (Access Key ID and Secret Access Key)

### How to setup setup environment

* Export AWS_ACCESS_KEY and AWS_SECRET_KEY to environment variables as shown below
  ```
  export AWS_ACCESS_KEY=**********
  export AWS_SECRET_KEY=*******************
  ```
* Install and Configure kubectl for Amazon EKS
  - To install kubectl for Amazon EKS
    * Amazon EKS also vends kubectl binaries that you can use that are identical to the upstream kubectl binaries with the same version. To install the Amazon EKS-vended binary for your operating system, see Installing [kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html).
  - To install aws-iam-authenticator for Amazon EKS
    * To download and install the Amazon EKS-vended aws-iam-authenticator binary:
      1. Download the Amazon EKS-vended aws-iam-authenticator binary from Amazon S3:

        * Linux: https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator

        * MacOS: https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/darwin/amd64/aws-iam-authenticator

        * Windows: https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/windows/amd64/aws-iam-authenticator.exe

      2. Apply execute permissions to the binary.
      ```
      chmod +x ./aws-iam-authenticator
      ```
      3. Copy the binary to a folder in your $PATH. We recommend creating a $HOME/bin/aws-iam-authenticator and ensuring that $HOME/bin comes first in your $PATH.
      ```
      cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$HOME/bin:$PATH
      ```
      4. Add $HOME/bin to your PATH environment variable.
      ```
      For Bash shells on macOS:

      echo 'export PATH=$HOME/bin:$PATH' >> ~/.bash_profile

      For Bash shells on Linux:

      echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
      ```
      5. Test that the aws-iam-authenticator binary works.
      ```
      aws-iam-authenticator help
      ```


### To enable worker nodes to join your cluster
1. Create a file aws-auth-cm.yaml , copy the below config and replace ```<ARN of instance role (not instance profile)>```

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: <ARN of instance role (not instance profile)>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
```
2. Apply the configuration. This command may take a few minutes to finish.
```
kubectl apply -f aws-auth-cm.yaml
```
3. Watch the status of your nodes and wait for them to reach the Ready status.
```
kubectl get nodes --watch
```


### Terraform Strucuture
##### link global variables with global templates
```
ln -sf ../global_templates/global-variables.tf ../boot-strap/global-variables.tf

```
