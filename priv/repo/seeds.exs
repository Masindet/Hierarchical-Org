# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TreeOrg.Repo.insert!(%TreeOrg.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TreeOrg.Repo
alias TreeOrg.TreeNode

# Clear existing data
Repo.delete_all(TreeNode)

# Create the organizational tree structure
ceo = Repo.insert!(%TreeNode{name: "CEO"})

cto = Repo.insert!(%TreeNode{name: "CTO", parent_id: ceo.id})
cfo = Repo.insert!(%TreeNode{name: "CFO", parent_id: ceo.id})
coo = Repo.insert!(%TreeNode{name: "COO", parent_id: ceo.id})

# CTO's team
dev_manager = Repo.insert!(%TreeNode{name: "Development Manager", parent_id: cto.id})
qa_manager = Repo.insert!(%TreeNode{name: "QA Manager", parent_id: cto.id})
devops_manager = Repo.insert!(%TreeNode{name: "DevOps Manager", parent_id: cto.id})

# Development team
frontend_lead = Repo.insert!(%TreeNode{name: "Frontend Lead", parent_id: dev_manager.id})
backend_lead = Repo.insert!(%TreeNode{name: "Backend Lead", parent_id: dev_manager.id})
mobile_lead = Repo.insert!(%TreeNode{name: "Mobile Lead", parent_id: dev_manager.id})

# Frontend team
fe_dev_1 = Repo.insert!(%TreeNode{name: "Frontend Developer 1", parent_id: frontend_lead.id})
fe_dev_2 = Repo.insert!(%TreeNode{name: "Frontend Developer 2", parent_id: frontend_lead.id})

# Backend team
be_dev_1 = Repo.insert!(%TreeNode{name: "Backend Developer 1", parent_id: backend_lead.id})
be_dev_2 = Repo.insert!(%TreeNode{name: "Backend Developer 2", parent_id: backend_lead.id})

# Mobile team
mobile_dev_1 = Repo.insert!(%TreeNode{name: "Mobile Developer 1", parent_id: mobile_lead.id})

# QA team
qa_engineer_1 = Repo.insert!(%TreeNode{name: "QA Engineer 1", parent_id: qa_manager.id})
qa_engineer_2 = Repo.insert!(%TreeNode{name: "QA Engineer 2", parent_id: qa_manager.id})

# DevOps team
devops_engineer_1 = Repo.insert!(%TreeNode{name: "DevOps Engineer 1", parent_id: devops_manager.id})

# CFO's team
finance_manager = Repo.insert!(%TreeNode{name: "Finance Manager", parent_id: cfo.id})
accounting_manager = Repo.insert!(%TreeNode{name: "Accounting Manager", parent_id: cfo.id})

# Finance team
financial_analyst_1 = Repo.insert!(%TreeNode{name: "Financial Analyst 1", parent_id: finance_manager.id})
financial_analyst_2 = Repo.insert!(%TreeNode{name: "Financial Analyst 2", parent_id: finance_manager.id})

# Accounting team
accountant_1 = Repo.insert!(%TreeNode{name: "Accountant 1", parent_id: accounting_manager.id})
accountant_2 = Repo.insert!(%TreeNode{name: "Accountant 2", parent_id: accounting_manager.id})

# COO's team
operations_manager = Repo.insert!(%TreeNode{name: "Operations Manager", parent_id: coo.id})
hr_manager = Repo.insert!(%TreeNode{name: "HR Manager", parent_id: coo.id})

# Operations team
operations_specialist_1 = Repo.insert!(%TreeNode{name: "Operations Specialist 1", parent_id: operations_manager.id})
operations_specialist_2 = Repo.insert!(%TreeNode{name: "Operations Specialist 2", parent_id: operations_manager.id})

# HR team
hr_generalist_1 = Repo.insert!(%TreeNode{name: "HR Generalist 1", parent_id: hr_manager.id})
hr_generalist_2 = Repo.insert!(%TreeNode{name: "HR Generalist 2", parent_id: hr_manager.id})


IO.puts("Tree structure seeded successfully!")