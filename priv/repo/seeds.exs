# Run with: mix run priv/repo/seeds.exs

alias TreeOrg.Repo
alias TreeOrg.TreeNode

# Clear previous data
Repo.delete_all(TreeNode)

# Executive Layer
ceo = Repo.insert!(%TreeNode{name: "CEO"})

# C-level executives
cto = Repo.insert!(%TreeNode{name: "CTO", parent_id: ceo.id})
cfo = Repo.insert!(%TreeNode{name: "CFO", parent_id: ceo.id})
coo = Repo.insert!(%TreeNode{name: "COO", parent_id: ceo.id})
cmo = Repo.insert!(%TreeNode{name: "CMO", parent_id: ceo.id})
cro = Repo.insert!(%TreeNode{name: "CRO", parent_id: ceo.id})
clo = Repo.insert!(%TreeNode{name: "CLO", parent_id: ceo.id})

# === CTO Branch ===
vp_engineering = Repo.insert!(%TreeNode{name: "VP of Engineering", parent_id: cto.id})
vp_product = Repo.insert!(%TreeNode{name: "VP of Product", parent_id: cto.id})

# Engineering divisions
frontend_mgr = Repo.insert!(%TreeNode{name: "Frontend Manager", parent_id: vp_engineering.id})
backend_mgr = Repo.insert!(%TreeNode{name: "Backend Manager", parent_id: vp_engineering.id})
infra_mgr = Repo.insert!(%TreeNode{name: "Infrastructure Manager", parent_id: vp_engineering.id})

# Frontend team
fe_lead = Repo.insert!(%TreeNode{name: "Frontend Tech Lead", parent_id: frontend_mgr.id})
Repo.insert!(%TreeNode{name: "React Dev", parent_id: fe_lead.id})
Repo.insert!(%TreeNode{name: "Vue Dev", parent_id: fe_lead.id})
Repo.insert!(%TreeNode{name: "UI/UX Designer", parent_id: fe_lead.id})

# Backend team
be_lead = Repo.insert!(%TreeNode{name: "Backend Tech Lead", parent_id: backend_mgr.id})
Repo.insert!(%TreeNode{name: "Elixir Dev", parent_id: be_lead.id})
Repo.insert!(%TreeNode{name: "NodeJS Dev", parent_id: be_lead.id})
Repo.insert!(%TreeNode{name: "Go Dev", parent_id: be_lead.id})

# Infra team
devops_lead = Repo.insert!(%TreeNode{name: "DevOps Lead", parent_id: infra_mgr.id})
Repo.insert!(%TreeNode{name: "Cloud Engineer", parent_id: devops_lead.id})
Repo.insert!(%TreeNode{name: "SRE", parent_id: devops_lead.id})
Repo.insert!(%TreeNode{name: "Security Engineer", parent_id: devops_lead.id})

# Product division
pm_lead = Repo.insert!(%TreeNode{name: "Lead Product Manager", parent_id: vp_product.id})
Repo.insert!(%TreeNode{name: "Product Manager 1", parent_id: pm_lead.id})
Repo.insert!(%TreeNode{name: "Product Manager 2", parent_id: pm_lead.id})

# === CFO Branch ===
finance_mgr = Repo.insert!(%TreeNode{name: "Finance Manager", parent_id: cfo.id})
acct_mgr = Repo.insert!(%TreeNode{name: "Accounting Manager", parent_id: cfo.id})
auditor = Repo.insert!(%TreeNode{name: "Internal Auditor", parent_id: cfo.id})

Repo.insert!(%TreeNode{name: "Financial Analyst", parent_id: finance_mgr.id})
Repo.insert!(%TreeNode{name: "Budget Officer", parent_id: finance_mgr.id})
Repo.insert!(%TreeNode{name: "Accountant", parent_id: acct_mgr.id})
Repo.insert!(%TreeNode{name: "Payroll Specialist", parent_id: acct_mgr.id})

# === COO Branch ===
ops_mgr = Repo.insert!(%TreeNode{name: "Operations Manager", parent_id: coo.id})
hr_mgr = Repo.insert!(%TreeNode{name: "HR Manager", parent_id: coo.id})
support_mgr = Repo.insert!(%TreeNode{name: "Customer Support Manager", parent_id: coo.id})

Repo.insert!(%TreeNode{name: "Logistics Coordinator", parent_id: ops_mgr.id})
Repo.insert!(%TreeNode{name: "Facilities Supervisor", parent_id: ops_mgr.id})

hr_bp = Repo.insert!(%TreeNode{name: "HR Business Partner", parent_id: hr_mgr.id})
Repo.insert!(%TreeNode{name: "Recruiter", parent_id: hr_bp.id})
Repo.insert!(%TreeNode{name: "HR Generalist", parent_id: hr_bp.id})

Repo.insert!(%TreeNode{name: "Support Rep 1", parent_id: support_mgr.id})
Repo.insert!(%TreeNode{name: "Support Rep 2", parent_id: support_mgr.id})
Repo.insert!(%TreeNode{name: "Support Rep 3", parent_id: support_mgr.id})

# === CMO Branch ===
marketing_mgr = Repo.insert!(%TreeNode{name: "Marketing Manager", parent_id: cmo.id})
Repo.insert!(%TreeNode{name: "SEO Specialist", parent_id: marketing_mgr.id})
Repo.insert!(%TreeNode{name: "Content Writer", parent_id: marketing_mgr.id})
Repo.insert!(%TreeNode{name: "Social Media Coordinator", parent_id: marketing_mgr.id})

# === CRO Branch ===
sales_mgr = Repo.insert!(%TreeNode{name: "Sales Manager", parent_id: cro.id})
Repo.insert!(%TreeNode{name: "Sales Rep 1", parent_id: sales_mgr.id})
Repo.insert!(%TreeNode{name: "Sales Rep 2", parent_id: sales_mgr.id})
Repo.insert!(%TreeNode{name: "Sales Rep 3", parent_id: sales_mgr.id})

# === CLO Branch ===
legal_mgr = Repo.insert!(%TreeNode{name: "Legal Manager", parent_id: clo.id})
Repo.insert!(%TreeNode{name: "Corporate Counsel", parent_id: legal_mgr.id})
Repo.insert!(%TreeNode{name: "Compliance Officer", parent_id: legal_mgr.id})

# === Special Teams ===
rnd_head = Repo.insert!(%TreeNode{name: "Head of R&D", parent_id: ceo.id})
Repo.insert!(%TreeNode{name: "Innovation Specialist", parent_id: rnd_head.id})
Repo.insert!(%TreeNode{name: "Prototype Engineer", parent_id: rnd_head.id})

IO.puts("🌳 Complex organizational tree seeded successfully!")
