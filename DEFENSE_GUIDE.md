# 3-Tier Architecture Defense Guide

## Quick Overview
This project deploys a production-ready web application on AWS using Terraform. It separates concerns into 3 layers for security, scalability, and maintainability.

---

## The 3 Tiers Explained

### **Tier 1: Presentation Layer (Public)**
- **What:** Application Load Balancer (ALB)
- **Where:** Public subnets across 2 availability zones
- **Purpose:** Receives internet traffic and distributes it to application servers
- **Access:** Open to internet (HTTP/HTTPS)

### **Tier 2: Application Layer (Private)**
- **What:** EC2 instances running Node.js app in Auto Scaling Group
- **Where:** Private app subnets (no direct internet access)
- **Purpose:** Runs your business logic and application code
- **Access:** Only from ALB, uses NAT Gateway for outbound internet

### **Tier 3: Data Layer (Private)**
- **What:** RDS MySQL database
- **Where:** Private DB subnets (most isolated)
- **Purpose:** Stores application data
- **Access:** Only from application tier

---

## How Traffic Flows

```
Internet User
    ↓
Internet Gateway (entry point)
    ↓
Application Load Balancer (public subnet)
    ↓
EC2 Instances (private app subnet)
    ↓
RDS Database (private DB subnet)
```

**Return path:** Same route in reverse

---

## The 5 Terraform Modules

### 1. **Networking Module**
**Creates:** VPC, subnets, Internet Gateway, NAT Gateway, route tables

**Why it matters:** Foundation for everything. Defines network boundaries and traffic routing.

**Key concept:** 
- Public subnets have route to Internet Gateway
- Private subnets route through NAT Gateway for outbound only

### 2. **Security Module**
**Creates:** Security groups (virtual firewalls)

**Why it matters:** Controls what can talk to what.

**Rules:**
- ALB accepts traffic from internet (port 80/443)
- App tier accepts traffic only from ALB (port 3000)
- Database accepts traffic only from app tier (port 3306)

### 3. **ALB Module**
**Creates:** Load balancer, target group, health checks

**Why it matters:** Entry point for users, distributes load, checks instance health.

**Key concept:** If an instance fails health check, ALB stops sending traffic to it.

### 4. **Compute Module**
**Creates:** Auto Scaling Group, Launch Template, EC2 instances

**Why it matters:** Runs your application code, scales based on demand.

**Key features:**
- Automatically installs Node.js and your app
- Retrieves DB credentials from Secrets Manager
- Scales up when CPU > 70%, scales down when CPU < 30%

### 5. **Database Module**
**Creates:** RDS instance, DB subnet group

**Why it matters:** Persistent data storage with automatic backups.

**Key features:**
- Multi-AZ for high availability (automatic failover)
- Encrypted at rest
- 7-day backup retention

---

## How Modules Interrelate

```
main.tf (orchestrator)
    ↓
1. Networking (creates VPC, subnets)
    ↓
2. Security (uses VPC ID, creates security groups)
    ↓
3. ALB (uses public subnets, ALB security group)
    ↓
4. Compute (uses private app subnets, app security group, ALB target group)
    ↓
5. Database (uses private DB subnets, DB security group)
```

**Dependencies:** Each module depends on outputs from previous modules.

---

## Key Defense Points

### **Why 3 tiers?**
- **Security:** Layers of defense, database not exposed to internet
- **Scalability:** Can scale each tier independently
- **Maintainability:** Changes to one tier don't affect others

### **Why multiple availability zones?**
- **High availability:** If one AZ fails, app continues in another
- **No single point of failure**

### **Why Auto Scaling?**
- **Cost efficiency:** Only pay for what you need
- **Performance:** Automatically handles traffic spikes
- **Reliability:** Replaces unhealthy instances automatically

### **Why private subnets?**
- **Security:** App and DB not directly accessible from internet
- **Attack surface reduction:** Must compromise ALB first

### **Why NAT Gateway?**
- Allows private instances to download updates/packages
- Outbound only - no inbound connections from internet

### **Why security groups at each tier?**
- **Defense in depth:** Multiple layers of security
- **Least privilege:** Each tier only allows necessary traffic

---

## Common Defense Questions

**Q: What happens if an EC2 instance fails?**
A: ALB health check detects failure → stops sending traffic → ASG launches replacement

**Q: What happens if database fails?**
A: Multi-AZ RDS automatically fails over to standby in another AZ (~60 seconds)

**Q: How does app connect to database?**
A: Uses RDS endpoint, credentials from Secrets Manager, security group allows port 3306

**Q: Can someone SSH directly to app servers?**
A: No, they're in private subnets. Need bastion host (jump box) for SSH access

**Q: How do you update the application?**
A: Update Launch Template → ASG gradually replaces instances with new version

**Q: What if traffic suddenly spikes?**
A: ASG detects high CPU → launches more instances → ALB distributes traffic

**Q: How is this Infrastructure as Code beneficial?**
A: Version controlled, reproducible, documented, can recreate entire environment in minutes

---

## Deployment Flow

1. **terraform init** - Downloads AWS provider
2. **terraform plan** - Shows what will be created
3. **terraform apply** - Creates resources in order:
   - VPC and networking
   - Security groups
   - ALB
   - EC2 instances (app installs automatically via user data)
   - RDS database
4. **Access via ALB DNS** - Get from `terraform output alb_dns_name`

---

## Cost Breakdown (~$84/month)

- NAT Gateway: $32/month (largest cost)
- ALB: $18/month
- 2x EC2 t3.micro: $19/month
- RDS db.t3.micro: $12/month
- Storage: $3/month

**Cost optimization:** Use t4g instances, single NAT Gateway, reserved instances

---

## Security Highlights

✅ **Network isolation** - 3 separate subnet tiers  
✅ **Encryption** - RDS encrypted at rest  
✅ **No hardcoded secrets** - Uses Secrets Manager  
✅ **Least privilege** - Security groups restrict access  
✅ **Automated backups** - 7-day retention  
✅ **Multi-AZ** - High availability  
✅ **IAM roles** - No credentials on instances  

---

## Quick Troubleshooting

**503 Error from ALB:**
- Check target health: `aws elbv2 describe-target-health`
- Verify security groups allow traffic
- Check app logs on EC2

**Can't connect to database:**
- Verify security group allows app tier
- Check RDS is "available" state
- Confirm endpoint is correct

**Auto Scaling not working:**
- Check CloudWatch alarms
- Verify IAM permissions
- Review ASG activity history

---

## Key Terraform Concepts

**Modules:** Reusable infrastructure components  
**Variables:** Inputs to customize deployment  
**Outputs:** Values exposed for use by other modules  
**State:** Terraform tracks what's deployed  
**Dependencies:** Terraform determines creation order  

---

## Success Metrics

✅ ALB returns HTTP 200  
✅ App connects to database  
✅ Auto Scaling responds to load  
✅ Multi-AZ failover works  
✅ No public access to private resources  

---

## Final Tips for Defense

1. **Know the flow:** Internet → IGW → ALB → App → DB
2. **Explain security:** Each tier isolated, least privilege access
3. **Highlight HA:** Multi-AZ, Auto Scaling, health checks
4. **Emphasize IaC:** Reproducible, version controlled, documented
5. **Understand trade-offs:** Cost vs. availability, security vs. convenience

**Most important:** Understand WHY each component exists, not just WHAT it does.
