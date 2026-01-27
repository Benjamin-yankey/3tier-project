# Defense Questions - 3-Tier AWS Architecture Project

## **Architecture & Design Decisions**

1. **Why did you choose only ONE NAT Gateway instead of deploying one per AZ?** What's the impact on high availability and cost?

   **Answer:** Single NAT Gateway is a cost optimization decision. Impact:
   - **Cost:** One NAT Gateway costs ~$32/month vs $64/month for two
   - **HA Impact:** If the AZ with NAT Gateway fails, private instances in other AZ lose internet access
   - **Mitigation:** For production, deploy one NAT Gateway per AZ for true HA
   - **Trade-off:** Acceptable for dev/staging environments where cost matters more than 100% uptime

2. **Your RDS shows synchronous replication between Write and Read replicas. How does Multi-AZ failover actually work?** What's the RTO/RPO?

   **Answer:** Multi-AZ uses synchronous replication to a standby instance:
   - **Process:** Primary writes → Synchronous replication → Standby acknowledges → Transaction commits
   - **Failover:** AWS automatically updates DNS record to point to standby
   - **RTO:** 1-3 minutes (DNS propagation + connection re-establishment)
   - **RPO:** Near zero (synchronous replication ensures no data loss)
   - **Trigger:** Primary instance failure, AZ outage, or maintenance

3. **Why place the ALB in public subnets when it could be internal?** What are the security implications?

   **Answer:** ALB is internet-facing to serve external users:
   - **Public ALB:** Receives traffic from internet, routes to private app instances
   - **Security:** ALB security group restricts to HTTP/HTTPS only
   - **Internal ALB:** Would require VPN/Direct Connect for user access
   - **Best Practice:** Public ALB with private backend is standard web architecture
   - **Protection:** WAF can be added for additional security

4. **How do you handle database connection pooling** with auto-scaling EC2 instances that can scale from 1 to 4?

   **Answer:** Connection pooling strategies:
   - **Application-level:** Each instance maintains its own connection pool (10-20 connections)
   - **RDS Proxy:** AWS managed connection pooling service (recommended for production)
   - **Connection limits:** db.t3.micro supports ~80 connections, sufficient for 4 instances
   - **Monitoring:** CloudWatch tracks connection count and usage
   - **Scaling consideration:** RDS Proxy enables thousands of concurrent connections

---

## **Security Deep Dive**

5. **Your security group allows ICMP from ALB to App tier. Why is this necessary?** What attack vectors does this open?

   **Answer:** ICMP enables ALB health checks and network diagnostics:
   - **Health Checks:** ALB uses ICMP ping for basic connectivity testing
   - **Troubleshooting:** Enables ping for network diagnostics
   - **Attack Vectors:** ICMP tunneling, reconnaissance, DoS amplification
   - **Mitigation:** Restrict ICMP to specific types (echo request/reply only)
   - **Alternative:** Remove ICMP and rely solely on HTTP health checks

6. **You're storing DB passwords in terraform.tfvars. Walk me through the Secrets Manager integration** shown in your user data script.

   **Answer:** Secrets Manager integration process:
   ```bash
   # User data retrieves secret
   DB_PASSWORD=$(aws secretsmanager get-secret-value \
     --secret-id "3tier/db/password" \
     --query SecretString --output text)
   
   # Export as environment variable
   export DB_PASSWORD=$DB_PASSWORD
   ```
   - **IAM Role:** EC2 instances need `secretsmanager:GetSecretValue` permission
   - **Security:** Passwords never stored in plain text on instances
   - **Rotation:** Secrets Manager can auto-rotate passwords
   - **Best Practice:** Never store secrets in terraform.tfvars for production

7. **What happens if someone compromises an EC2 instance in the app tier?** Can they access other AWS services via the IAM role?

   **Answer:** Compromise impact depends on IAM role permissions:
   - **Current Role:** Limited to Secrets Manager and SSM Parameter Store
   - **Potential Access:** Only secrets and parameters, not other AWS services
   - **Lateral Movement:** Cannot access other EC2 instances directly
   - **Database:** Can connect to RDS using retrieved credentials
   - **Mitigation:** Use least-privilege IAM policies, enable CloudTrail logging, implement instance monitoring

8. **Your bastion host has SSH access. Why not use AWS Systems Manager Session Manager instead?** What are the trade-offs?

   **Answer:** Session Manager vs SSH comparison:
   
   **Session Manager Advantages:**
   - No SSH keys to manage
   - No bastion host costs
   - Centralized access logging
   - No inbound security group rules
   
   **SSH/Bastion Advantages:**
   - File transfer capabilities (SCP/SFTP)
   - Port forwarding for applications
   - Works without internet connectivity
   - Familiar tooling for teams
   
   **Recommendation:** Use Session Manager for production, SSH for development

9. **How do you prevent the NAT Gateway from becoming a data exfiltration point** if an instance is compromised?

   **Answer:** NAT Gateway security controls:
   - **VPC Flow Logs:** Monitor all traffic through NAT Gateway
   - **Route Tables:** Restrict which subnets can use NAT Gateway
   - **NACLs:** Additional subnet-level filtering
   - **Egress-only IGW:** For IPv6 traffic (prevents inbound)
   - **Monitoring:** CloudWatch alarms for unusual traffic patterns
   - **Proxy Solution:** Consider using proxy servers with content filtering instead

---

## **Scalability & Performance**

10. **Your ASG scales at 70% CPU for 2 minutes. What if you have a sudden traffic spike?** How would you implement predictive scaling?

   **Answer:** Handling traffic spikes:
   
   **Current Limitation:** 2-minute delay + instance launch time (2-3 minutes total)
   
   **Improvements:**
   - **Target Tracking:** Scale based on ALB request count per target
   - **Predictive Scaling:** AWS Auto Scaling analyzes traffic patterns
   - **Scheduled Scaling:** Pre-scale for known traffic patterns
   - **Step Scaling:** Aggressive scaling for high CPU (>90%)
   
   **Implementation:**
   ```hcl
   predictive_scaling_policy {
     metric_specification {
       target_value = 50.0
       predefined_metric_specification {
         predefined_metric_type = "ASGAverageCPUUtilization"
       }
     }
   }
   ```

11. **The health check grace period is 300 seconds. What happens during this time?** Can unhealthy instances serve traffic?

   **Answer:** Health check grace period behavior:
   - **Purpose:** Allows time for application startup and initialization
   - **During Grace Period:** ASG ignores health check failures
   - **ALB Behavior:** ALB has separate health checks and will mark targets unhealthy
   - **Traffic Routing:** ALB stops sending traffic to unhealthy targets immediately
   - **Instance State:** Instance remains in ASG but receives no traffic
   - **Best Practice:** Grace period should match application startup time

12. **Your application waits for database connectivity in user data. What if RDS takes 10 minutes to be available?** Does the instance fail health checks?

   **Answer:** Database dependency handling:
   - **Current Risk:** Instance may timeout waiting for DB
   - **Health Check Impact:** ALB health checks will fail if app doesn't start
   - **Solutions:**
     - Implement retry logic with exponential backoff
     - Start application with circuit breaker pattern
     - Use dependency management (wait-for-it script)
     - Separate health check endpoint from DB-dependent endpoints
   
   **Improved User Data:**
   ```bash
   # Wait for DB with timeout
   timeout 600 bash -c 'until nc -z $DB_HOST 3306; do sleep 5; done'
   ```

13. **How do you handle database connection limits** when scaling from 2 to 4 instances rapidly?

   **Answer:** Connection limit management:
   - **db.t3.micro limit:** ~80 connections
   - **Per instance:** 10-15 connections in pool
   - **Scaling impact:** 4 instances = 40-60 connections (within limits)
   - **Monitoring:** CloudWatch DatabaseConnections metric
   - **Solutions for higher scale:**
     - RDS Proxy for connection pooling
     - Upgrade to larger RDS instance class
     - Implement application-level connection management
     - Use read replicas for read-heavy workloads

---

## **Cost Optimization**

14. **You're using gp3 storage for RDS. How did you determine this vs gp2 or io1?** Show me the cost-performance analysis.

   **Answer:** Storage type comparison:
   
   **gp3 (chosen):**
   - Cost: $0.08/GB/month
   - IOPS: 3,000 baseline (configurable)
   - Throughput: 125 MB/s baseline
   
   **gp2:**
   - Cost: $0.10/GB/month
   - IOPS: 3 IOPS/GB (burst to 3,000)
   - Throughput: 250 MB/s max
   
   **io1:**
   - Cost: $0.125/GB/month + $0.065/IOPS
   - IOPS: Up to 64,000 (configurable)
   - Use case: High IOPS requirements
   
   **Decision:** gp3 offers better cost-performance for typical web applications

15. **NAT Gateway costs ~$32/month. How would you reduce this** while maintaining functionality?

   **Answer:** NAT Gateway cost reduction strategies:
   
   **Alternatives:**
   - **NAT Instance:** t3.nano (~$4/month) but requires management
   - **VPC Endpoints:** For AWS services (S3, DynamoDB) - $7.20/month
   - **Egress-only IGW:** For IPv6 traffic (free)
   
   **Hybrid Approach:**
   - Use VPC endpoints for AWS services
   - NAT Gateway only for external internet access
   - Estimated savings: 60-70% reduction
   
   **Trade-offs:**
   - NAT Instance: Single point of failure, requires patching
   - VPC Endpoints: Only works for supported AWS services

16. **Why t3.micro instead of t4g.micro (ARM)?** What's the migration path?

   **Answer:** Instance type comparison:
   
   **t3.micro (x86):**
   - Cost: $0.0104/hour
   - Compatibility: All software works
   - Performance: Intel/AMD architecture
   
   **t4g.micro (ARM/Graviton2):**
   - Cost: $0.0084/hour (20% cheaper)
   - Performance: Better price-performance
   - Limitation: ARM-specific builds required
   
   **Migration Path:**
   1. Test application on ARM architecture
   2. Update AMI to ARM-compatible version
   3. Modify launch template
   4. Rolling deployment through ASG
   
   **Decision:** t3.micro chosen for compatibility; t4g.micro recommended for production

---

## **Disaster Recovery & Resilience**

17. **If eu-west-1a fails completely, what's your recovery process?** Walk me through the timeline.

   **Answer:** AZ failure recovery timeline:
   
   **Immediate (0-2 minutes):**
   - ALB stops routing to failed AZ instances
   - RDS Multi-AZ failover initiates (if primary in failed AZ)
   
   **Short-term (2-5 minutes):**
   - ASG launches replacement instances in healthy AZ
   - New instances register with ALB target group
   
   **Medium-term (5-10 minutes):**
   - Application starts on new instances
   - Health checks pass, traffic resumes
   
   **Issues:**
   - Single NAT Gateway in failed AZ = no internet for private instances
   - Capacity constraints in remaining AZ
   
   **Improvements:** Deploy NAT Gateway in both AZs for true HA

18. **Your RDS backup retention is 7 days. What's your strategy for point-in-time recovery** from 3 days ago?

   **Answer:** Point-in-time recovery process:
   
   **RDS PITR Capabilities:**
   - Recovery to any second within retention period
   - Uses automated backups + transaction logs
   - Creates new RDS instance (doesn't overwrite existing)
   
   **Recovery Steps:**
   1. Identify exact recovery time (3 days ago)
   2. Create new RDS instance from PITR
   3. Update application connection strings
   4. Validate data integrity
   5. Switch traffic to recovered database
   
   **Timeline:** 15-30 minutes depending on database size
   
   **Considerations:**
   - New endpoint requires application updates
   - Test recovery process regularly
   - Consider read replicas for faster recovery

19. **How do you handle a scenario where the ALB is healthy but all targets are unhealthy?** What does the user see?

   **Answer:** ALB with unhealthy targets scenario:
   
   **User Experience:**
   - HTTP 503 Service Unavailable
   - ALB returns error page
   - No application content served
   
   **ALB Behavior:**
   - Continues health checks every 30 seconds
   - Routes traffic when targets become healthy
   - Logs errors to access logs
   
   **Monitoring & Alerts:**
   - CloudWatch: UnHealthyHostCount metric
   - ALB access logs show 503 responses
   - Auto Scaling launches new instances
   
   **Mitigation:**
   - Custom error pages
   - Multiple target groups
   - Cross-AZ load balancing
   - Faster health check intervals

20. **What happens if your Terraform state file is corrupted or deleted?** How do you recover?

   **Answer:** Terraform state recovery strategies:
   
   **Prevention:**
   - Remote state backend (S3 + DynamoDB)
   - State file versioning
   - Regular backups
   
   **Recovery Options:**
   1. **Restore from backup:** S3 versioning or local backups
   2. **Import existing resources:**
      ```bash
      terraform import aws_vpc.main vpc-12345
      terraform import aws_subnet.public subnet-67890
      ```
   3. **Recreate infrastructure:** Last resort, causes downtime
   
   **Best Practices:**
   - Use remote state with locking
   - Enable S3 versioning
   - Regular state backups
   - Team access controls

---

## **Terraform-Specific**

21. **Why use modules instead of a monolithic main.tf?** What are the downsides of your modular approach?

   **Answer:** Modular vs monolithic comparison:
   
   **Module Advantages:**
   - Reusability across environments
   - Separation of concerns
   - Easier testing and validation
   - Team collaboration (different modules)
   
   **Module Disadvantages:**
   - Increased complexity
   - More files to maintain
   - Variable passing overhead
   - Harder to see full picture
   
   **Current Structure Issues:**
   - Tight coupling between modules
   - Complex variable passing
   - Difficult to modify individual components
   
   **Improvements:**
   - Looser coupling
   - Better documentation
   - Module versioning

22. **How do you handle Terraform state locking** with multiple team members?

   **Answer:** State locking implementation:
   
   **Current Setup:** Local state (no locking)
   
   **Production Setup:**
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "terraform-state-bucket"
       key            = "3tier/terraform.tfstate"
       region         = "us-east-1"
       dynamodb_table = "terraform-locks"
       encrypt        = true
     }
   }
   ```
   
   **DynamoDB Table:**
   - Primary key: LockID
   - Prevents concurrent modifications
   - Automatic lock release after timeout
   
   **Benefits:**
   - Prevents state corruption
   - Team collaboration safety
   - State versioning and backup

23. **Your modules have outputs. How do you prevent sensitive data** (like DB passwords) from appearing in state files?

   **Answer:** Sensitive data protection:
   
   **Terraform Sensitive Outputs:**
   ```hcl
   output "db_password" {
     value     = aws_db_instance.main.password
     sensitive = true
   }
   ```
   
   **Best Practices:**
   - Use AWS Secrets Manager for passwords
   - Mark outputs as sensitive
   - Encrypt state files at rest
   - Restrict state file access
   
   **State File Security:**
   - S3 bucket encryption
   - IAM policies for access control
   - VPC endpoints for S3 access
   - Audit logging with CloudTrail
   
   **Alternative:** Generate passwords in AWS, reference by ARN

24. **What's your strategy for blue-green deployments** with this Terraform setup?

   **Answer:** Blue-green deployment strategies:
   
   **Approach 1: Dual ASGs**
   - Create second ASG with new AMI
   - Switch ALB target groups
   - Terminate old ASG
   
   **Approach 2: Terraform Workspaces**
   ```bash
   terraform workspace new green
   terraform apply -var="environment=green"
   # Switch DNS/ALB
   terraform workspace select blue
   terraform destroy
   ```
   
   **Approach 3: External Orchestration**
   - Use CodeDeploy for application deployment
   - Keep infrastructure stable
   - Rolling deployments within ASG
   
   **Challenges:**
   - Database schema changes
   - Shared resources (RDS, VPC)
   - Cost of running dual environments

---

## **Operational Challenges**

25. **How do you perform zero-downtime database schema migrations** in this architecture?

   **Answer:** Zero-downtime migration strategies:
   
   **Backward-Compatible Changes:**
   1. Add new columns (nullable)
   2. Deploy application code
   3. Migrate data
   4. Remove old columns
   
   **Breaking Changes:**
   1. Create read replica
   2. Apply schema changes to replica
   3. Switch application to replica
   4. Promote replica to primary
   
   **Tools:**
   - AWS DMS for data migration
   - Blue-green RDS deployments
   - Application-level migration scripts
   
   **Best Practices:**
   - Test migrations on copy of production data
   - Rollback plan for each step
   - Monitor application performance

26. **Your user data script clones from GitHub. What if GitHub is down** during an auto-scaling event?

   **Answer:** GitHub dependency mitigation:
   
   **Current Risk:** Instance launch fails if GitHub unavailable
   
   **Solutions:**
   1. **Pre-baked AMIs:** Include application code in AMI
   2. **S3 Backup:** Store application artifacts in S3
   3. **Container Images:** Use ECR with Docker
   4. **Multiple Sources:** Fallback to backup repositories
   
   **Improved User Data:**
   ```bash
   # Try GitHub first, fallback to S3
   git clone https://github.com/user/app.git || \
   aws s3 cp s3://backup-bucket/app.tar.gz . && tar -xzf app.tar.gz
   ```
   
   **Best Practice:** Eliminate external dependencies in user data

27. **How do you debug an application issue on an EC2 instance** that's in a private subnet without a bastion?

   **Answer:** Private instance debugging options:
   
   **AWS Systems Manager:**
   - Session Manager for shell access
   - Run Command for remote execution
   - Parameter Store for configuration
   
   **CloudWatch Integration:**
   - CloudWatch Logs for application logs
   - CloudWatch Agent for system metrics
   - Custom metrics from application
   
   **Application-Level:**
   - Health check endpoints
   - Debug endpoints (secured)
   - Structured logging
   
   **Network Access:**
   - VPC Flow Logs for network debugging
   - ALB access logs
   - X-Ray for distributed tracing

28. **What's your monitoring and alerting strategy?** How do you know if the application is slow vs infrastructure issues?

   **Answer:** Comprehensive monitoring strategy:
   
   **Infrastructure Metrics:**
   - EC2: CPU, Memory, Disk, Network
   - ALB: Response time, error rate, target health
   - RDS: CPU, connections, read/write latency
   
   **Application Metrics:**
   - Custom metrics via CloudWatch API
   - Response time by endpoint
   - Business metrics (user actions)
   
   **Alerting Thresholds:**
   - ALB 5xx errors > 5%
   - Response time > 2 seconds
   - CPU utilization > 80%
   - Database connections > 70
   
   **Differentiation:**
   - High CPU + slow response = infrastructure issue
   - Normal CPU + slow response = application issue
   - Database latency metrics isolate DB problems

---

## **Advanced Scenarios**

29. **If you need to add a caching layer (ElastiCache), where would you place it** and how would you modify the security groups?

   **Answer:** ElastiCache integration:
   
   **Placement:** Private app subnets (same as EC2 instances)
   
   **Security Group Changes:**
   ```hcl
   # New ElastiCache security group
   resource "aws_security_group" "elasticache" {
     ingress {
       from_port       = 6379  # Redis
       to_port         = 6379
       protocol        = "tcp"
       security_groups = [aws_security_group.app.id]
     }
   }
   
   # App security group - add egress to cache
   resource "aws_security_group_rule" "app_to_cache" {
     type                     = "egress"
     from_port               = 6379
     to_port                 = 6379
     protocol                = "tcp"
     source_security_group_id = aws_security_group.elasticache.id
     security_group_id       = aws_security_group.app.id
   }
   ```
   
   **Subnet Group:** Span multiple AZs for HA

30. **How would you implement this architecture as multi-region** for disaster recovery?

   **Answer:** Multi-region DR implementation:
   
   **Primary Region (Active):**
   - Full 3-tier architecture
   - RDS with automated backups
   - Route 53 health checks
   
   **DR Region (Standby):**
   - VPC and networking pre-deployed
   - RDS cross-region read replica
   - AMIs copied to DR region
   - ASG with 0 desired capacity
   
   **Failover Process:**
   1. Route 53 detects primary region failure
   2. DNS switches to DR region ALB
   3. Promote read replica to primary
   4. Scale up ASG in DR region
   
   **RTO:** 10-15 minutes
   **RPO:** 5 minutes (replication lag)
   
   **Cost:** ~30% of primary region (storage + data transfer)

31. **Your application uses Secrets Manager. What's the IAM policy** that allows EC2 to retrieve secrets? Show me the least-privilege approach.

   **Answer:** Least-privilege IAM policy:
   
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "secretsmanager:GetSecretValue"
         ],
         "Resource": [
           "arn:aws:secretsmanager:us-east-1:123456789012:secret:3tier/db/password-*"
         ],
         "Condition": {
           "StringEquals": {
             "secretsmanager:ResourceTag/Environment": "${aws:RequestedRegion}"
           }
         }
       }
     ]
   }
   ```
   
   **Security Features:**
   - Specific secret ARN (not wildcard)
   - Only GetSecretValue permission
   - Conditional access based on tags
   - No ListSecrets permission
   
   **Additional Security:**
   - VPC endpoint for Secrets Manager
   - CloudTrail logging of API calls

32. **How do you handle Terraform drift** when someone makes manual changes in the AWS console?

   **Answer:** Terraform drift management:
   
   **Detection:**
   ```bash
   # Check for drift
   terraform plan -detailed-exitcode
   # Exit code 2 = changes detected
   ```
   
   **Automated Detection:**
   - CI/CD pipeline runs terraform plan
   - CloudWatch Events for AWS API calls
   - Config Rules for compliance
   
   **Resolution Options:**
   1. **Revert manual changes:** `terraform apply`
   2. **Import changes:** Update Terraform code
   3. **Ignore specific resources:** `lifecycle { ignore_changes }`
   
   **Prevention:**
   - IAM policies restricting console access
   - Service Control Policies (SCPs)
   - Regular drift detection
   - Team training and processes

---

## **Critical Thinking**

33. **You have 2 AZs but 3 subnet types (public, private app, private DB). Why not use 3 AZs** for better fault tolerance?

   **Answer:** AZ count considerations:
   
   **Current (2 AZs):**
   - Cost: Lower (fewer NAT Gateways, subnets)
   - Complexity: Simpler management
   - Availability: 99.95% (single AZ failure tolerance)
   
   **3 AZs Benefits:**
   - Higher availability: 99.99%
   - Better load distribution
   - Improved fault tolerance
   
   **3 AZs Costs:**
   - Additional NAT Gateway: +$32/month
   - More subnets to manage
   - Increased data transfer costs
   
   **Decision Factors:**
   - Application criticality
   - Budget constraints
   - Compliance requirements
   
   **Recommendation:** 3 AZs for production, 2 AZs for dev/staging

34. **The architecture shows KMS (Key Management Service). How is this integrated** with RDS encryption?

   **Answer:** KMS integration with RDS:
   
   **Encryption at Rest:**
   ```hcl
   resource "aws_db_instance" "main" {
     storage_encrypted = true
     kms_key_id       = aws_kms_key.rds.arn
   }
   
   resource "aws_kms_key" "rds" {
     description = "RDS encryption key"
     policy = jsonencode({
       Statement = [{
         Effect = "Allow"
         Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
         Action = "kms:*"
         Resource = "*"
       }]
     })
   }
   ```
   
   **Key Features:**
   - Automatic encryption/decryption
   - Key rotation (annual)
   - Cross-region snapshot encryption
   - Performance impact: minimal
   
   **Best Practices:**
   - Customer-managed keys for compliance
   - Separate keys per environment
   - Key access logging

35. **What's the blast radius if your AWS credentials are leaked?** How do you minimize this?

   **Answer:** Credential compromise impact:
   
   **Current Blast Radius:**
   - Full account access (if admin credentials)
   - All regions and services
   - Potential data exfiltration
   - Resource deletion/modification
   
   **Minimization Strategies:**
   
   **IAM Best Practices:**
   - Least privilege policies
   - Separate users per person/service
   - MFA enforcement
   - Regular credential rotation
   
   **Account Isolation:**
   - Separate AWS accounts per environment
   - Cross-account roles for access
   - Service Control Policies (SCPs)
   
   **Monitoring:**
   - CloudTrail for all API calls
   - GuardDuty for anomaly detection
   - Config for compliance monitoring
   
   **Response Plan:**
   - Immediate credential revocation
   - Resource inventory and validation
   - Incident response procedures

---

## **Bonus Killer Questions**

36. **Prove to me that your infrastructure is actually highly available.** What single points of failure exist?

   **Answer:** HA analysis and single points of failure:
   
   **Highly Available Components:**
   - ALB: Multi-AZ by design
   - RDS: Multi-AZ with automatic failover
   - ASG: Spans multiple AZs
   - Route 53: Global DNS service
   
   **Single Points of Failure:**
   1. **NAT Gateway:** Only in one AZ
   2. **Application Code:** Bugs affect all instances
   3. **Database Schema:** Schema issues affect all connections
   4. **Region:** Entire region failure
   
   **Availability Calculation:**
   - ALB: 99.99%
   - RDS Multi-AZ: 99.95%
   - EC2 (Multi-AZ): 99.99%
   - Combined: ~99.93%
   
   **Improvements:**
   - NAT Gateway per AZ
   - Multi-region deployment
   - Chaos engineering testing

37. **Calculate the actual monthly cost** for this infrastructure running 24/7 with moderate traffic.

   **Answer:** Detailed cost breakdown (us-east-1):
   
   **Compute:**
   - 2x t3.micro EC2: $0.0104 × 24 × 30 × 2 = $14.98
   - ALB: $16.20 + $0.008/LCU × hours = ~$22.00
   
   **Storage:**
   - RDS db.t3.micro: $0.017 × 24 × 30 = $12.24
   - RDS storage 20GB gp3: $0.08 × 20 = $1.60
   - EBS volumes 2×8GB: $0.08 × 16 = $1.28
   
   **Networking:**
   - NAT Gateway: $32.40 + data processing
   - Data transfer: ~$5.00
   
   **Total Monthly Cost: ~$89.50**
   
   **Cost Optimization:**
   - Reserved Instances: -40%
   - t4g instances: -20%
   - Single AZ NAT: Current setup
   
   **Optimized Cost: ~$54.00/month**

38. **If I told you to reduce costs by 40% without sacrificing availability, what would you change?**

   **Answer:** 40% cost reduction strategy:
   
   **Changes (maintaining HA):**
   
   1. **Reserved Instances (1-year):** -40% on EC2/RDS
      - EC2: $14.98 → $8.99
      - RDS: $12.24 → $7.34
   
   2. **ARM Instances (t4g):** -20% additional
      - t3.micro → t4g.micro
      - Savings: $1.80/month
   
   3. **VPC Endpoints:** Replace NAT for AWS services
      - S3/DynamoDB endpoints: $7.20/month
      - Reduce NAT data processing: -$10/month
   
   4. **Spot Instances:** For non-critical workloads
      - 50-70% savings on compute
      - Use with mixed instance types in ASG
   
   **Total Savings:**
   - Original: $89.50
   - Optimized: $52.73
   - Reduction: 41%
   
   **Availability Impact:** None - all changes maintain HA

---

## **Tips for Your Defense**

- **Be honest** - If you don't know something, explain how you'd find the answer
- **Show trade-offs** - Every decision has pros and cons
- **Reference the diagram** - Point to specific components when answering
- **Think production** - Consider real-world scenarios, not just "it works in dev"
- **Know your costs** - Understand the financial impact of your decisions
- **Security first** - Always consider security implications

Good luck! 🎯
